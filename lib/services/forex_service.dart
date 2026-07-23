import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_data.dart';

/// Live exchange rate data
class LiveRates {
  final String base;
  final Map<String, double> rates; // "1 base = X currency"
  final Map<String, double> changes; // 24h percent change
  final DateTime fetchedAt;
  final bool isOffline;

  const LiveRates({
    required this.base,
    required this.rates,
    required this.changes,
    required this.fetchedAt,
    this.isOffline = false,
  });

  Map<String, dynamic> toJson() => {
    'base': base,
    'rates': rates,
    'changes': changes,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory LiveRates.fromJson(Map<String, dynamic> json, {bool isOffline = true}) {
    return LiveRates(
      base: json['base'] as String,
      rates: (json['rates'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())),
      changes: (json['changes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      isOffline: isOffline,
    );
  }

  /// Convert: how many [to] for 1 [from]
  double getRate(String from, String to) {
    if (from == to) return 1.0;

    // rates map: 1 USD = X currency
    // So: from->to = rates[to] / rates[from]
    final rateFrom = rates[from];
    final rateTo   = rates[to];

    if (rateFrom == null || rateTo == null) {
      // Fallback to mock if currency not in API
      return mockRate(from, to);
    }

    return rateTo / rateFrom;
  }
}

/// ForexService — fetches real-time rates from AwesomeAPI
class ForexService extends ChangeNotifier {
  // Real-time API
  static const _liveBaseUrl = 'https://economia.awesomeapi.com.br/json/last';
  static const _histBaseUrl = 'https://economia.awesomeapi.com.br/json/daily';

  LiveRates? _rates;
  bool       _loading = true;
  String?    _error;
  Timer?     _timer;

  LiveRates? get rates   => _rates;
  bool       get loading => _loading;
  String?    get error   => _error;

  ForexService() {
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    await _loadFromCache();
    if (_rates != null) {
      _loading = false;
      notifyListeners();
    }
    await _fetch();
    // Refresh every 5 minutes for real-time feel
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetch());
  }

  Future<void> refresh() => _fetch();

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_live_rates');
      if (cached != null) {
        final data = json.decode(cached);
        _rates = LiveRates.fromJson(data, isOffline: true);
        _error = 'Offline mód. Utolsó frissítés: ${_rates!.fetchedAt.hour.toString().padLeft(2, '0')}:${_rates!.fetchedAt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
  }

  Future<void> _fetch() async {
    _loading = true;
    notifyListeners();

    try {
      final result = await _fetchLiveRates();
      if (result != null) {
        _rates = result;
        _error = null;
        // Save to cache
        try {
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('cached_live_rates', json.encode(_rates!.toJson()));
        } catch (_) {}
      } else {
        await _loadFromCache();
        _error ??= 'Nem sikerült betölteni a valós idejű árfolyamokat';
      }
    } catch (e) {
      await _loadFromCache();
      _error ??= e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<LiveRates?> _fetchLiveRates() async {
    try {
      // Build the query: USD-EUR,USD-GBP,...
      final targetCodes = mockAllCodes.where((c) => c != 'USD').toList();
      final cryptoCodes = const ['BTC', 'ETH', 'DOGE', 'XRP'];
      final fiatCodes = targetCodes.where((c) => !cryptoCodes.contains(c)).toList();

      final fiatPairs = fiatCodes.map((c) => 'USD-$c').join(',');
      final cryptoPairs = cryptoCodes.where((c) => targetCodes.contains(c)).map((c) => '$c-USD').join(',');
      
      final url = '$_liveBaseUrl/$fiatPairs,$cryptoPairs';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        
        final r = <String, double>{};
        final c = <String, double>{};
        r['USD'] = 1.0; // Base is USD
        c['USD'] = 0.0;

        for (final code in fiatCodes) {
          final pairKey = 'USD$code'; // AwesomeAPI returns keys like USDEUR
          final pairData = data[pairKey] as Map<String, dynamic>?;
          if (pairData != null && pairData['bid'] != null) {
            r[code] = double.tryParse(pairData['bid'].toString()) ?? mockRate('USD', code);
            // fiat: USD-EUR up means EUR weaker. We invert sign so + means EUR stronger
            final pct = double.tryParse(pairData['pctChange']?.toString() ?? '0') ?? 0.0;
            c[code] = -pct;
          } else {
            r[code] = mockRate('USD', code);
            c[code] = mockChange(code);
          }
        }

        for (final code in cryptoCodes) {
          if (!targetCodes.contains(code)) continue;
          final pairKey = '${code}USD'; // AwesomeAPI returns keys like BTCUSD
          final pairData = data[pairKey] as Map<String, dynamic>?;
          if (pairData != null && pairData['bid'] != null) {
            final bid = double.tryParse(pairData['bid'].toString());
            if (bid != null && bid > 0) {
              r[code] = 1.0 / bid; // Invert to get 1 USD = X Crypto
            } else {
              r[code] = mockRate('USD', code);
            }
            // crypto: BTC-USD up means BTC stronger. No invert.
            final pct = double.tryParse(pairData['pctChange']?.toString() ?? '0') ?? 0.0;
            c[code] = pct;
          } else {
            r[code] = mockRate('USD', code);
            c[code] = mockChange(code);
          }
        }

        debugPrint('[ForexService] Real-time fetch OK — HUF=${r['HUF']}, BTC=${r['BTC']}');
        return LiveRates(base: 'USD', rates: r, changes: c, fetchedAt: DateTime.now());
      } else {
        debugPrint('[ForexService] API returned status ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('[ForexService] Live rates fetch failed: $e');
    }
    return null;
  }

  /// Historical series — returns daily closing rates [from→to] for the last [days]
  Future<List<double>> getHistory(String from, String to, int days) async {
    // If it's the same currency, return a flat line
    if (from == to) return List.filled(days, 1.0);

    const cryptoCodes = ['BTC', 'ETH', 'DOGE', 'XRP'];
    final isToCrypto = cryptoCodes.contains(to);
    
    // AwesomeAPI expects BTC-USD, not USD-BTC. If `to` is crypto, flip the query and invert the results.
    final queryFrom = isToCrypto ? to : from;
    final queryTo = isToCrypto ? from : to;

    try {
      // AwesomeAPI uses from-to format (e.g. EUR-HUF) and returns daily data
      final url = '$_histBaseUrl/$queryFrom-$queryTo/$days';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as List<dynamic>;
        
        final result = data.map((item) {
          final map = item as Map<String, dynamic>;
          final val = double.tryParse(map['bid'].toString());
          if (val == null) return null;
          return isToCrypto ? (val > 0 ? 1.0 / val : null) : val;
        }).whereType<double>().toList();

        // AwesomeAPI returns newest to oldest, so we reverse it for the chart
        final reversed = result.reversed.toList();
        if (reversed.isNotEmpty) {
          return reversed;
        }
      } else {
        debugPrint('[ForexService] History API returned status ${resp.statusCode} for $queryFrom-$queryTo');
      }
    } catch (e) {
      debugPrint('[ForexService] History failed for $queryFrom-$queryTo: $e');
    }

    // Fallback to mock data if API fails or pair is unsupported by historical API
    debugPrint('[ForexService] Falling back to mock history for $from-$to');
    return mockHistory(from, to, days);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ── Inherited provider (no external package) ───────────────────────────────

class ForexServiceProvider extends InheritedNotifier<ForexService> {
  const ForexServiceProvider({
    super.key,
    required ForexService service,
    required super.child,
  }) : super(notifier: service);

  static ForexService of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<ForexServiceProvider>();
    assert(p != null, 'No ForexServiceProvider found in widget tree');
    return p!.notifier!;
  }
}

class ForexServiceRoot extends StatefulWidget {
  final Widget child;
  const ForexServiceRoot({super.key, required this.child});

  @override
  State<ForexServiceRoot> createState() => _ForexServiceRootState();
}

class _ForexServiceRootState extends State<ForexServiceRoot> {
  final _service = ForexService();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ForexServiceProvider(
      service: _service,
      child: widget.child,
    );
  }
}
