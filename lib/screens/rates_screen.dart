import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/forex_service.dart';
import '../services/settings_service.dart';
import '../data/mock_data.dart';
import '../widgets/mini_sparkline.dart';

class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  String _base = 'USD';
  String _q = '';

  AppSettings get s => SettingsProvider.of(context);

  @override
  Widget build(BuildContext context) {
    final svc = ForexServiceProvider.of(context);
    final lr  = svc.rates;
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _AppBar(svc: svc),
            _Header(
              base: _base,
              lr: lr,
              q: _q,
              onBaseChanged: (b) => setState(() => _base = b),
              onSearch: (v) => setState(() => _q = v),
            ),
            if (lr != null && lr.isOffline)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(20),
                    border: Border.all(color: Colors.amber.withAlpha(50)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline mód. Utolsó frissítés: ${lr.fetchedAt.hour.toString().padLeft(2, '0')}:${lr.fetchedAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: _buildList(lr)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(LiveRates? lr) {
    final allCodes = mockAllCodes.where((c) => c != _base).toList();
    final filtered = _q.isEmpty
        ? allCodes
        : allCodes
            .where((c) =>
                c.toLowerCase().contains(_q.toLowerCase()) ||
                mockCurrencyName(c).toLowerCase().contains(_q.toLowerCase()))
            .toList();

    if (lr == null) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _RateTile(
          code: filtered[i],
          base: _base,
          rate: mockRate(_base, filtered[i]),
          changePercent: mockChange(filtered[i]),
          sparkline: mockHistory(filtered[i], _base, 7),
          isPos: mockChange(filtered[i]) >= 0,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final code = filtered[i];
        final rate = lr.getRate(_base, code);
        final mockChg = mockChange(code);
        return _RateTile(
          code: code,
          base: _base,
          rate: rate,
          changePercent: mockChg,
          sparkline: mockHistory(code, _base, 7),
          isPos: mockChg >= 0,
        );
      },
    );
  }
}

class _AppBar extends StatelessWidget {
  final ForexService svc;
  const _AppBar({required this.svc});

  @override
  Widget build(BuildContext context) {
    final s = SettingsProvider.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [s.accentColor, const Color(0xFF00B4D8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'MB',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'MoneyBox',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const Spacer(),
          if (svc.loading)
            GestureDetector(
              onTap: svc.refresh,
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: s.accentColor),
              ),
            )
          else
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); svc.refresh(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: svc.rates?.isOffline == true ? Colors.amber.withAlpha(15) : s.accentColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: svc.rates?.isOffline == true ? Colors.amber.withAlpha(60) : s.accentColor.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(color: svc.rates?.isOffline == true ? Colors.amber : s.accentColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(svc.rates?.isOffline == true ? 'OFFLINE' : 'ÉLŐ', style: TextStyle(color: svc.rates?.isOffline == true ? Colors.amber : s.accentColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String base;
  final LiveRates? lr;
  final String q;
  final void Function(String) onBaseChanged;
  final void Function(String) onSearch;

  const _Header({
    required this.base,
    required this.lr,
    required this.q,
    required this.onBaseChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final s = SettingsProvider.of(context);
    final dt = lr?.fetchedAt ?? DateTime.now().toUtc();
    final isUtc = lr == null;
    final ts  = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}${isUtc ? " UTC" : ""}';
    final subtitle = lr != null 
        ? (lr!.isOffline ? 'Offline adatok · $ts' : 'Élő adatok · $ts') 
        : 'Szimulált adatok · $ts';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Árfolyamok',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                  Text(subtitle, style: const TextStyle(color: kDim2, fontSize: 12)),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showBasePicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _flagCircle(base),
                      const SizedBox(width: 6),
                      Text(base, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: kDim2, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: onSearch,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Deviza keresése...',
              hintStyle: const TextStyle(color: kDim2, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: kDim2, size: 20),
              filled: true,
              fillColor: kSurface,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: s.accentColor)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagCircle(String code) {
    return Container(
      width: 24, height: 24,
      decoration: const BoxDecoration(color: kBorder, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(mockCountryCode(code), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }

  void _showBasePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 44, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Alap deviza', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: mockAllCodes.length,
                itemBuilder: (ctx2, i) {
                  final code = mockAllCodes[i];
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: kSurface2, shape: BoxShape.circle, border: Border.all(color: kBorder)),
                      alignment: Alignment.center,
                      child: Text(mockCountryCode(code), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(mockCurrencyName(code), style: const TextStyle(color: kDim2, fontSize: 12)),
                    trailing: base == code ? Icon(Icons.check_circle_rounded, color: SettingsProvider.of(context).accentColor) : null,
                    onTap: () {
                      onBaseChanged(code);
                      Navigator.pop(ctx2);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  final String code;
  final String base;
  final double rate;
  final double changePercent;
  final List<double> sparkline;
  final bool isPos;

  const _RateTile({
    required this.code,
    required this.base,
    required this.rate,
    required this.changePercent,
    required this.sparkline,
    required this.isPos,
  });

  @override
  Widget build(BuildContext context) {
    final inv = 1.0 / rate;
    final cc  = mockCountryCode(code);
    final name = mockCurrencyName(code);
    final s = SettingsProvider.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kSurface.withAlpha(200),
            kSurface.withAlpha(100),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Flag / Country Badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  s.accentColor.withAlpha(50),
                  s.accentColor2.withAlpha(10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: s.accentColor.withAlpha(80), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(cc, style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          
          // Currency details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPos ? kPos.withAlpha(20) : kNeg.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isPos ? kPos.withAlpha(40) : kNeg.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPos ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 10,
                            color: isPos ? kPos : kNeg,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${isPos ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                            style: TextStyle(color: isPos ? kPos : kNeg, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(name, style: const TextStyle(color: kDim2, fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          // Mini Sparkline chart (responsive)
          if (s.showSparklines) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 50,
              height: 30,
              child: MiniSparkline(data: sparkline, color: isPos ? kPos : kNeg, strokeWidth: 2.0),
            ),
          ],
          
          const SizedBox(width: 10),
          
          // Rate display
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _fmt(rate, code),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _fmtInv(inv),
                  style: const TextStyle(color: kDim2, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v, String code) {
    if (code == 'JPY' || code == 'HUF' || v >= 100) return v.toStringAsFixed(1);
    if (v < 0.01) return v.toStringAsFixed(6);
    return v.toStringAsFixed(4);
  }

  String _fmtInv(double v) {
    if (v >= 100) return v.toStringAsFixed(1);
    return v.toStringAsFixed(4);
  }
}
