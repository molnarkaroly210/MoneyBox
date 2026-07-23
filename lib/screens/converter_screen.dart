import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/forex_service.dart';
import '../services/settings_service.dart';
import '../widgets/mini_sparkline.dart';
import '../data/mock_data.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen>
    with SingleTickerProviderStateMixin {
  String? _from;
  String? _to;
  double _amount = 1.0;
  final _ctrl = TextEditingController(text: '1');
  late AnimationController _swapCtrl;

  static const _favs = [
    ('USD', 'HUF'),
    ('EUR', 'HUF'),
    ('EUR', 'USD'),
    ('GBP', 'HUF'),
    ('USD', 'EUR'),
  ];

  @override
  void initState() {
    super.initState();
    _swapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _swapCtrl.dispose();
    super.dispose();
  }

  AppSettings get s => SettingsProvider.of(context);

  double _rate(LiveRates? lr) {
    if (lr == null) return mockRate(_from!, _to!);
    return lr.getRate(_from!, _to!);
  }

  double _result(LiveRates? lr) => _amount * _rate(lr);

  void _swap(LiveRates? lr) {
    HapticFeedback.mediumImpact();
    _swapCtrl.forward(from: 0);
    final newAmt = _result(lr);
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
      _amount = newAmt;
      _ctrl.text = _fmtAmt(newAmt);
    });
  }

  void _selectFav(int i) {
    setState(() {
      _from = _favs[i].$1;
      _to   = _favs[i].$2;
    });
  }

  String _fmtAmt(double v) {
    if (s.compactNumbers) {
      if (v >= 1000) return v.toStringAsFixed(0);
      if (v >= 1)    return v.toStringAsFixed(1);
      return v.toStringAsFixed(3);
    }
    if (v >= 1000) return v.toStringAsFixed(0);
    if (v >= 1)    return v.toStringAsFixed(2);
    return v.toStringAsFixed(4);
  }

  String _fmtRate(double v) {
    if (s.compactNumbers) {
      if (v >= 100) return v.toStringAsFixed(1);
      if (v >= 1)   return v.toStringAsFixed(3);
      if (v < 0.01) return v.toStringAsFixed(7);
      return v.toStringAsFixed(4);
    }
    if (v >= 100) return v.toStringAsFixed(2);
    if (v >= 1)   return v.toStringAsFixed(5);
    if (v < 0.01) return v.toStringAsFixed(8);
    return v.toStringAsFixed(6);
  }

  String _fmtResult(double v) {
    if (s.compactNumbers) {
      if (v >= 10000) return v.toStringAsFixed(0);
      if (v >= 100)   return v.toStringAsFixed(1);
      if (v >= 1)     return v.toStringAsFixed(2);
      if (v < 0.01) return v.toStringAsFixed(6);
      return v.toStringAsFixed(4);
    }
    if (v >= 10000) return v.toStringAsFixed(0);
    if (v >= 100)   return v.toStringAsFixed(2);
    if (v >= 1)     return v.toStringAsFixed(4);
    if (v < 0.01) return v.toStringAsFixed(8);
    return v.toStringAsFixed(6);
  }

  @override
  Widget build(BuildContext context) {
    // InheritedNotifier — context.dependOnInheritedWidgetOfExactType triggers
    // rebuild automatically when ForexService calls notifyListeners()
    final svc  = ForexServiceProvider.of(context);
    final lr   = svc.rates;
    
    // Init from settings if null
    _from ??= s.defaultFrom;
    _to   ??= s.defaultTo;
    final rate   = _rate(lr);
    final result = _result(lr);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(svc),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!s.simpleConverterMode) ...[
                      const SizedBox(height: 8),
                      _buildFavPairs(lr),
                      const SizedBox(height: 16),
                      _buildRateCard(lr, rate),
                      const SizedBox(height: 16),
                    ] else ...[
                      const SizedBox(height: 16),
                    ],
                    _buildConverterCard(lr, rate, result),
                    if (!s.simpleConverterMode) ...[
                      const SizedBox(height: 16),
                      _buildQuickAmounts(),
                    ],
                    const SizedBox(height: 16),
                    _buildKeypad(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(ForexService svc) {
    final lr = svc.rates;
    final timeStr = lr != null
        ? '${lr.fetchedAt.toLocal().hour.toString().padLeft(2,'0')}:${lr.fetchedAt.toLocal().minute.toString().padLeft(2,'0')}'
        : '--:--';
    final isOffline = lr?.isOffline == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          _logo(),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MoneyBox',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              Text(
                lr != null ? (isOffline ? 'Offline: $timeStr' : 'Frissítve: $timeStr') : 'Betöltés...',
                style: const TextStyle(color: kDim2, fontSize: 10),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); svc.refresh(); },
            child: _liveBadge(svc.loading, isOffline),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [s.accentColor, Color(0xFF00B4D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Text('MB', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _liveBadge(bool loading, bool isOffline) {
    final color = isOffline ? Colors.amber : s.accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          loading
              ? SizedBox(width: 7, height: 7, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
              : (isOffline 
                  ? Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)) 
                  : _PulsingDot()),
          const SizedBox(width: 5),
          Text(isOffline ? 'OFFLINE' : 'ÉLŐ', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        ],
      ),
    );
  }

  Widget _buildFavPairs(LiveRates? lr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bolt_rounded, size: 13, color: kGold),
            SizedBox(width: 5),
            Text('KEDVENC PÁROK', style: TextStyle(color: kDim2, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _favs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final (f, t) = _favs[i];
              final sel = _from == f && _to == t;
              // Show live rate in the chip
              final chipRate = lr?.getRate(f, t);
              final rateStr  = chipRate != null ? ' ${_fmtChipRate(chipRate)}' : '';
              return GestureDetector(
                onTap: () => _selectFav(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? LinearGradient(colors: [s.accentColor, s.accentColor2], begin: Alignment.topLeft, end: Alignment.bottomRight)
                        : null,
                    color: sel ? null : kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Colors.transparent : kBorder),
                  ),
                  child: Text(
                    '$f→$t$rateStr',
                    style: TextStyle(color: sel ? Colors.black : Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _fmtChipRate(double v) {
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 1)   return v.toStringAsFixed(2);
    return v.toStringAsFixed(4);
  }

  Widget _buildRateCard(LiveRates? lr, double rate) {
    final sparkData = mockHistory(_from!, _to!, 30);
    final avg  = sparkData.reduce((a, b) => a + b) / sparkData.length;
    final chg  = ((rate - avg) / avg) * 100;
    final isPos = chg >= 0;
    final isLive = lr != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kSurface, kSurface2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isLive ? s.accentColor.withAlpha(40) : kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Jelenlegi árfolyam',
                style: TextStyle(color: isLive ? s.accentColor.withAlpha(200) : kDim2, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (isLive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: s.accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('ÉLŐADAT', style: TextStyle(color: s.accentColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPos ? kPos.withAlpha(25) : kNeg.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isPos ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 11, color: isPos ? kPos : kNeg),
                    const SizedBox(width: 3),
                    Text('${isPos ? '+' : ''}${chg.toStringAsFixed(2)}%',
                        style: TextStyle(color: isPos ? kPos : kNeg, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontWeight: FontWeight.w800),
              children: [
                TextSpan(text: '1 ${_from!} ', style: const TextStyle(color: Colors.white70, fontSize: 20)),
                const TextSpan(text: '= ', style: TextStyle(color: kDim2, fontSize: 18)),
                TextSpan(text: _fmtRate(rate), style: TextStyle(color: s.accentColor, fontSize: 30, fontWeight: FontWeight.w900)),
                TextSpan(text: ' ${_to!}', style: const TextStyle(color: Colors.white70, fontSize: 20)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('Fordítva: 1 ${_to!} = ${_fmtRate(1.0 / rate)} ${_from!}',
              style: const TextStyle(color: kDim2, fontSize: 12)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: s.accentColor.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.accentColor.withAlpha(40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isPos ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: s.accentColor, size: 13),
                const SizedBox(width: 5),
                Text('30N átlag: ${_fmtRate(avg)} (${isPos ? '+' : ''}${chg.toStringAsFixed(2)}%)',
                    style: TextStyle(color: s.accentColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: MiniSparkline(data: sparkData, color: isPos ? kPos : kNeg, fillGradient: true, strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildConverterCard(LiveRates? lr, double rate, double result) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kSurface, kSurface2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ÖSSZEG', style: TextStyle(color: kDim2, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _ctrl.text.isEmpty ? '0' : _ctrl.text,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                      ),
                    ),
                    _currencyChip(_from, true),
                  ],
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 1, color: kBorder),
              GestureDetector(
                onTap: () => _swap(lr),
                child: AnimatedBuilder(
                  animation: _swapCtrl,
                  builder: (_, child) => Transform.rotate(angle: _swapCtrl.value * 3.14159, child: child),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [s.accentColor, s.accentColor2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      border: Border.all(color: kBg, width: 3),
                      boxShadow: [BoxShadow(color: s.accentColor.withAlpha(80), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.swap_vert, color: Colors.black, size: 20),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('EREDMÉNY', style: TextStyle(color: kDim2, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: result.toStringAsFixed(4)));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✓ Vágólapra másolva'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: kDim.withAlpha(60), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 12, color: kDim2),
                            SizedBox(width: 4),
                            Text('Másolás', style: TextStyle(color: kDim2, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fmtResult(result),
                        style: TextStyle(color: s.accentColor, fontSize: 32, fontWeight: FontWeight.w800),
                      ),
                    ),
                    _currencyChip(_to, false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyChip(String? code, bool isFrom) {
    return GestureDetector(
      onTap: () => _showPicker(isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _flag(code!),
            const SizedBox(width: 8),
            Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: kDim2, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _flag(String code) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: kBorder, shape: BoxShape.circle, border: Border.all(color: kSurface2, width: 1)),
      alignment: Alignment.center,
      child: Text(mockCountryCode(code), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildQuickAmounts() {
    const values = [1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0];
    const labels = ['1', '10', '100', '1K', '10K', '100K'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flash_on_rounded, size: 13, color: kGold),
            SizedBox(width: 5),
            Text('GYORS ÖSSZEGEK', style: TextStyle(color: kDim2, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(values.length, (i) {
            final sel = _amount == values[i];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < values.length - 1 ? 6 : 0),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _amount = values[i];
                      _ctrl.text = values[i] >= 1000 ? values[i].toInt().toString() : values[i].toStringAsFixed(0);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? LinearGradient(colors: [s.accentColor, s.accentColor2], begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : null,
                      color: sel ? null : kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? Colors.transparent : kBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text(labels[i], style: TextStyle(color: sel ? Colors.black : Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('BEVITEL: ', style: TextStyle(color: kDim2, fontSize: 11, letterSpacing: 0.6)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: s.accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s.accentColor.withAlpha(60)),
                ),
                child: Text('ÖSSZEG', style: TextStyle(color: s.accentColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _keyRow(['7', '8', '9', '<']),
          const SizedBox(height: 8),
          _keyRow(['4', '5', '6', 'C']),
          const SizedBox(height: 8),
          _keyRow(['1', '2', '3', '.']),
          const SizedBox(height: 8),
          _keyRow(['0', '00', '000', '']),
        ],
      ),
    );
  }

  Widget _keyRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        if (key.isEmpty) return const Expanded(child: SizedBox());
        final isAction = key == '<' || key == 'C';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); _onKey(key); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  color: isAction ? kNeg.withAlpha(22) : kSurface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isAction ? kNeg.withAlpha(50) : kBorder),
                ),
                alignment: Alignment.center,
                child: key == '<'
                    ? const Icon(Icons.backspace_rounded, color: kNeg, size: 20)
                    : key == 'C'
                        ? const Text('C', style: TextStyle(color: kNeg, fontSize: 20, fontWeight: FontWeight.w800))
                        : Text(key, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onKey(String v) {
    setState(() {
      if (v == 'C') {
        _ctrl.text = '';
        _amount = 0;
      } else if (v == '<') {
        if (_ctrl.text.isNotEmpty) {
          _ctrl.text = _ctrl.text.substring(0, _ctrl.text.length - 1);
          _amount = double.tryParse(_ctrl.text) ?? 0;
        }
      } else if (v == '.') {
        if (!_ctrl.text.contains('.')) { _ctrl.text += v; }
      } else {
        if (_ctrl.text == '0') {
          _ctrl.text = v;
        } else {
          _ctrl.text += v;
        }
        _amount = double.tryParse(_ctrl.text) ?? 0;
      }
    });
  }

  void _showPicker(bool isFrom) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CurrencySheet(
        onSelect: (code) => setState(() {
          if (isFrom) { _from = code; } else { _to = code; }
        }),
      ),
    );
  }
}

// ── Currency picker ────────────────────────────────────────────────────────

class _CurrencySheet extends StatefulWidget {
  final void Function(String) onSelect;
  const _CurrencySheet({required this.onSelect});

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final svc = ForexServiceProvider.of(context);
    final s   = SettingsProvider.of(context);
    final lr  = svc.rates;
    final all = mockAllCodes.where((c) {
      if (_q.isEmpty) return true;
      return c.toLowerCase().contains(_q.toLowerCase()) ||
          mockCurrencyName(c).toLowerCase().contains(_q.toLowerCase());
    }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Válasszon devizát', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Keresés...',
                hintStyle: const TextStyle(color: kDim2),
                prefixIcon: const Icon(Icons.search, color: kDim2, size: 20),
                filled: true,
                fillColor: kSurface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: s.accentColor)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: all.length,
              itemBuilder: (_, i) {
                final code = all[i];
                final rate = lr?.getRate('USD', code);
                final rateStr = rate != null
                    ? (code == 'JPY' || code == 'HUF' || (rate) >= 10
                        ? rate.toStringAsFixed(2)
                        : (rate < 0.01 ? rate.toStringAsFixed(7) : rate.toStringAsFixed(4)))
                    : '—';
                return ListTile(
                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: kSurface2, shape: BoxShape.circle, border: Border.all(color: kBorder)),
                    alignment: Alignment.center,
                    child: Text(mockCountryCode(code), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(mockCurrencyName(code), style: const TextStyle(color: kDim2, fontSize: 12)),
                  trailing: Text(rateStr, style: TextStyle(color: s.accentColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () {
                    widget.onSelect(code);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Pulsing dot ────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _a = Tween(begin: 0.4, end: 1.0).animate(_c);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = SettingsProvider.of(context);
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(color: s.accentColor.withValues(alpha: _a.value), shape: BoxShape.circle),
      ),
    );
  }
}
