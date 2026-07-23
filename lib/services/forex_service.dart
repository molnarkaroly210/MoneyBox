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

  factory LiveRates.fromJson(Map<String, dynamic> json, {bool isOffline = false}) {
    return LiveRates(
      base: json['base'] as String,
      rates: (json['rates'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())),
      changes: (json['changes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      isOffline: isOffline,
    );
  }

  double getRate(String from, String to) {
    if (from == to) return 1.0;
    final rateFrom = rates[from];
    final rateTo   = rates[to];
    if (rateFrom == null || rateTo == null) {
      return mockRate(from, to);
    }
    return rateTo / rateFrom;
  }
}

/// ForexService — multi-fallback ultra-reliable exchange rate fetcher
class ForexService extends ChangeNotifier {
  static const _frankfurterUrl = 'https://api.frankfurter.app/latest?from=USD';
  static const _openErApiUrl = 'https://open.er-api.com/v6/latest/USD';
  static const _awesomeApiUrl = 'https://economia.awesomeapi.com.br/json/last';

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
    _timer = Timer.periodic(const Duration(minutes: 3), (_) => _fetch());
  }

  Future<void> refresh() => _fetch();

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_live_rates');
      if (cached != null) {
        final data = json.decode(cached);
        _rates = LiveRates.fromJson(data, isOffline: false);
      }
    } catch (_) {}
  }

  Future<void> _fetch() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Try Frankfurter API (ECB official API - fastest in EU)
      // 2. Try Open ER-API
      // 3. Try AwesomeAPI
      final result = await _fetchFromFrankfurter() ?? 
                     await _fetchFromOpenErApi() ?? 
                     await _fetchFromAwesomeApi();

      if (result != null) {
        _rates = result;
        _error = null;
        try {
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('cached_live_rates', json.encode(_rates!.toJson()));
        } catch (_) {}
      } else {
        await _loadFromCache();
        if (_rates == null) {
          _error = 'Hálózati hiba: Nem sikerült csatlakozni az árfolyam kiszolgálóhoz.';
        }
      }
    } catch (e) {
      await _loadFromCache();
      _error = 'Kapcsolódási hiba: $e';
    }

    _loading = false;
    notifyListeners();
  }

  /// 1. Primary EU API: Frankfurter (ECB rates)
  Future<LiveRates?> _fetchFromFrankfurter() async {
    try {
      final resp = await http.get(Uri.parse(_frankfurterUrl)).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if (data['rates'] != null) {
          final rawRates = data['rates'] as Map<String, dynamic>;
          final r = <String, double>{};
          final c = <String, double>{};

          r['USD'] = 1.0;
          c['USD'] = 0.0;

          for (final entry in rawRates.entries) {
            r[entry.key] = (entry.value as num).toDouble();
            c[entry.key] = mockChange(entry.key);
          }

          // Fill mock/fallback values for cryptos or missing items
          for (final code in mockAllCodes) {
            if (!r.containsKey(code)) {
              r[code] = mockRate('USD', code);
              c[code] = mockChange(code);
            }
          }

          debugPrint('[ForexService] Frankfurter API fetch SUCCESS! USD-HUF=${r['HUF']}');
          return LiveRates(base: 'USD', rates: r, changes: c, fetchedAt: DateTime.now(), isOffline: false);
        }
      }
    } catch (e) {
      debugPrint('[ForexService] Frankfurter API failed: $e');
    }
    return null;
  }

  /// 2. Secondary API: Open ER-API
  Future<LiveRates?> _fetchFromOpenErApi() async {
    try {
      final resp = await http.get(Uri.parse(_openErApiUrl)).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        if (data['result'] == 'success' && data['rates'] != null) {
          final rawRates = data['rates'] as Map<String, dynamic>;
          final r = <String, double>{};
          final c = <String, double>{};

          for (final entry in rawRates.entries) {
            r[entry.key] = (entry.value as num).toDouble();
            c[entry.key] = mockChange(entry.key);
          }

          for (final code in mockAllCodes) {
            if (!r.containsKey(code)) {
              r[code] = mockRate('USD', code);
              c[code] = mockChange(code);
            }
          }

          debugPrint('[ForexService] Open ER-API fetch SUCCESS! USD-HUF=${r['HUF']}');
          return LiveRates(base: 'USD', rates: r, changes: c, fetchedAt: DateTime.now(), isOffline: false);
        }
      }
    } catch (e) {
      debugPrint('[ForexService] Open ER-API failed: $e');
    }
    return null;
  }

  /// 3. Tertiary API: AwesomeAPI
  Future<LiveRates?> _fetchFromAwesomeApi() async {
    try {
      final targetCodes = mockAllCodes.where((c) => c != 'USD').toList();
      final cryptoCodes = const ['BTC', 'ETH', 'DOGE', 'XRP'];
      final fiatCodes = targetCodes.where((c) => !cryptoCodes.contains(c)).toList();

      final fiatPairs = fiatCodes.map((c) => 'USD-$c').join(',');
      final url = '$_awesomeApiUrl/$fiatPairs';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final r = <String, double>{};
        final c = <String, double>{};
        r['USD'] = 1.0;
        c['USD'] = 0.0;

        for (final code in fiatCodes) {
          final pairKey = 'USD$code';
          final pairData = data[pairKey] as Map<String, dynamic>?;
          if (pairData != null && pairData['bid'] != null) {
            r[code] = double.tryParse(pairData['bid'].toString()) ?? mockRate('USD', code);
            final pct = double.tryParse(pairData['pctChange']?.toString() ?? '0') ?? 0.0;
            c[code] = -pct;
          } else {
            r[code] = mockRate('USD', code);
            c[code] = mockChange(code);
          }
        }
        return LiveRates(base: 'USD', rates: r, changes: c, fetchedAt: DateTime.now(), isOffline: false);
      }
    } catch (e) {
      debugPrint('[ForexService] AwesomeAPI fallback failed: $e');
    }
    return null;
  }

  Future<List<double>> getHistory(String from, String to, int days) async {
    if (from == to) return List.filled(days, 1.0);
    return mockHistory(from, to, days);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

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
