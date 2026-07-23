import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/forex_service.dart';
import '../services/settings_service.dart';
import '../data/mock_data.dart';
import '../widgets/mini_sparkline.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  String _from = 'EUR';
  String _to   = 'HUF';
  int _tfIdx   = 0;

  static const _tfLabels = ['7N', '1H', '3H', '6H', '1É'];
  static const _tfDays   = [7,    30,   90,  180,  365];

  // ── Historical data ───────────────────────────────────────────────────────
  // Watchlist is now managed by SettingsProvider — no local state needed
  bool _watchlistEditMode = false;

  // ── Historical data ───────────────────────────────────────────────────────
  List<double>? _history;
  bool _histLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_histLoading) return;
    if (!mounted) return;
    // Clear stale data immediately so the chart never shows old timeframe's data
    setState(() {
      _history = null;
      _histLoading = true;
    });
    try {
      final svc  = ForexServiceProvider.of(context);
      final hist = await svc.getHistory(_from, _to, _tfDays[_tfIdx]);
      if (mounted) setState(() => _history = hist.length >= 2 ? hist : null);
    } catch (_) {
      if (mounted) setState(() => _history = null);
    } finally {
      if (mounted) setState(() => _histLoading = false);
    }
  }

  /// Returns chart data guaranteed to be internally consistent:
  /// - Stats (min/max/vol) are computed from this exact data
  /// - Last point always equals the live rate
  /// - Longer windows always include shorter windows (via shared base series)
  List<double> _chartData(double liveRate) {
    if (_history != null && _history!.length >= 2) {
      // Use API data as-is; just ensure the very last value reflects today's live rate.
      // This avoids showing "current 354.47" but stats saying "min 356" (impossible).
      final hist = List<double>.from(_history!);
      hist[hist.length - 1] = liveRate;
      return hist;
    }
    // Fallback mock — consistent slice of a shared 365-day series
    return mockHistoryFromRate(_from, _to, _tfDays[_tfIdx], liveRate);
  }

  double _pctChange(List<double> d) {
    if (d.length < 2) return 0;
    return ((d.last - d.first) / d.first) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final svc      = ForexServiceProvider.of(context);
    final s        = SettingsProvider.of(context);
    final lr       = svc.rates;
    final liveRate = lr?.getRate(_from, _to) ?? mockRate(_from, _to);
    final data     = _chartData(liveRate);
    final chg      = _pctChange(data);
    final isPos    = chg >= 0;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildAppBar(svc, s)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _buildChartCard(data, liveRate, chg, isPos, s),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                child: _buildWatchlist(lr, liveRate, s),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(ForexService svc, AppSettings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [s.accentColor, s.accentColor2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('MB', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13))),
          ),
          const SizedBox(width: 10),
          const Text('MoneyBox', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const Spacer(),
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); svc.refresh(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: s.accentColor.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: s.accentColor.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (svc.loading)
                    SizedBox(width: 7, height: 7, child: CircularProgressIndicator(strokeWidth: 1.5, color: s.accentColor))
                  else
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: s.accentColor, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('ÉLŐ', style: TextStyle(color: s.accentColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chart card ────────────────────────────────────────────────────────────

  Widget _buildChartCard(List<double> data, double liveRate, double chg, bool isPos, AppSettings s) {
    // Stats derived from chart data (last point = liveRate → always consistent)
    final lo  = data.reduce((a, b) => a < b ? a : b);
    final hi  = data.reduce((a, b) => a > b ? a : b);
    final vol = lo > 0 ? ((hi - lo) / lo) * 100 : 0.0;
    final chartColor = isPos ? kPos : kNeg;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kSurface, kSurface2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + pair selector
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Grafikonok', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  Text('$_from / $_to', style: const TextStyle(color: kDim2, fontSize: 12)),
                ],
              ),
              const Spacer(),
              _pairChip(true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('/', style: TextStyle(color: kDim2.withAlpha(180), fontSize: 20, fontWeight: FontWeight.w300)),
              ),
              _pairChip(false),
            ],
          ),
          const SizedBox(height: 16),
          // Rate + change badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtRate(liveRate, s),
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPos ? kPos.withAlpha(25) : kNeg.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isPos ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: isPos ? kPos : kNeg, size: 14),
                      const SizedBox(width: 4),
                      Text('${isPos ? '+' : ''}${chg.toStringAsFixed(2)}%',
                          style: TextStyle(color: isPos ? kPos : kNeg, fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Timeframe pills
          Row(
            children: List.generate(_tfLabels.length, (i) {
              final sel = i == _tfIdx;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i == _tfIdx) return; // already selected
                    HapticFeedback.selectionClick();
                    // Clear stale history immediately before load
                    setState(() {
                      _tfIdx   = i;
                      _history = null;
                    });
                    _loadHistory();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: i < _tfLabels.length - 1 ? 4 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? const LinearGradient(colors: [kAccent, Color(0xFF00B4D8)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : null,
                      color: sel ? null : kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: sel ? null : Border.all(color: kBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _tfLabels[i],
                      style: TextStyle(
                        color: sel ? Colors.black : kDim2,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Chart area
          if (_histLoading)
            const SizedBox(
              height: 190,
              child: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
            )
          else
            SizedBox(
              height: 190,
              child: CustomPaint(
                painter: _ChartPainter(
                  data: data,
                  lineColor: chartColor,
                  gridColor: kBorder,
                  labelColor: kDim2,
                  xLabels: _xLabels(),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          const SizedBox(height: 16),
          // Stats row — always derived from the same data[] that drives the chart
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                Expanded(child: _statItem('Legmagasabb', _fmtRate(hi, s), kPos)),
                Container(width: 1, height: 36, color: kBorder),
                Expanded(child: _statItem('Legalacsonyabb', _fmtRate(lo, s), kNeg)),
                Container(width: 1, height: 36, color: kBorder),
                Expanded(child: _statItem('Volatilitás', '${vol.toStringAsFixed(2)}%', Colors.white70)),
              ],
            ),
          ),
          // Sanity check banner (only shown if something looks off — helpful for debugging)
          if (liveRate > hi || liveRate < lo)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kGold.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGold.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: kGold, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Az élő árfolyam (${_fmtRate(liveRate, s)}) kívül esik a grafikon tartományán. Frissítés szükséges.',
                      style: const TextStyle(color: kGold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color c) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: kDim2, fontSize: 11), textAlign: TextAlign.center),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _pairChip(bool isFrom) {
    final code = isFrom ? _from : _to;
    return GestureDetector(
      onTap: () => _showPicker(isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: kBorder, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(mockCountryCode(code), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            const Icon(Icons.keyboard_arrow_down_rounded, color: kDim2, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Customizable watchlist ────────────────────────────────────────────────

  Widget _buildWatchlist(LiveRates? lr, double mainRate, AppSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.remove_red_eye_rounded, size: 13, color: kDim2),
            const SizedBox(width: 6),
            const Text('FIGYELŐLISTA',
                style: TextStyle(color: kDim2, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            // Edit toggle
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); setState(() => _watchlistEditMode = !_watchlistEditMode); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _watchlistEditMode ? kAccent.withAlpha(30) : kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _watchlistEditMode ? kAccent.withAlpha(100) : kBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _watchlistEditMode ? Icons.check_rounded : Icons.edit_rounded,
                      size: 13,
                      color: _watchlistEditMode ? kAccent : kDim2,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _watchlistEditMode ? 'Kész' : 'Szerkesztés',
                      style: TextStyle(color: _watchlistEditMode ? kAccent : kDim2, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Grid of watchlist cards
        if (s.watchlist.isEmpty)
          _emptyWatchlist(s)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
            ),
            itemCount: s.watchlist.length + (_watchlistEditMode ? 1 : 0),
            itemBuilder: (_, i) {
              // "Add" button at the end in edit mode
              if (_watchlistEditMode && i == s.watchlist.length) {
                return _addCard(s);
              }
              final (from, to) = s.watchlist[i];
              final rate        = lr?.getRate(from, to) ?? mockRate(from, to);
              // Generate sparkline anchored to the live rate for consistency
              final sparkData   = mockHistoryFromRate(from, to, 20, rate);
              final chg         = _pctChange(sparkData);
              final isPos       = chg >= 0;
              final isActive    = _from == from && _to == to;

              return _WatchCard(
                from: from,
                to: to,
                rate: rate,
                sparkData: sparkData,
                chg: chg,
                isPos: isPos,
                isActive: isActive,
                editMode: _watchlistEditMode,
                onTap: () {
                  if (!_watchlistEditMode) {
                    setState(() { _from = from; _to = to; });
                    _loadHistory();
                  }
                },
                onRemove: () {
                  HapticFeedback.mediumImpact();
                  s.removeWatchPair(i);
                },
                fmtRate: (v) => _fmtRate(v, s),
                accentColor: s.accentColor,
                showSparklines: s.showSparklines,
              );
            },
          ),
      ],
    );
  }

  Widget _emptyWatchlist(AppSettings s) {
    return GestureDetector(
      onTap: () => _showAddPairSheet(s),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorder, style: BorderStyle.solid),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: kDim2, size: 28),
              SizedBox(height: 8),
              Text('Adj hozzá devizapárt', style: TextStyle(color: kDim2, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addCard(AppSettings s) {
    return GestureDetector(
      onTap: () => _showAddPairSheet(s),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: s.accentColor.withAlpha(80), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: s.accentColor.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: s.accentColor.withAlpha(80)),
              ),
              child: Icon(Icons.add_rounded, color: s.accentColor, size: 22),
            ),
            const SizedBox(height: 8),
            const Text('Devizapár\nhozzáadása',
                style: TextStyle(color: kDim2, fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showAddPairSheet(AppSettings s) {
    String? selectedFrom;
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 44, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      if (selectedFrom != null)
                        GestureDetector(
                          onTap: () => setSheetState(() => selectedFrom = null),
                          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                      if (selectedFrom != null) const SizedBox(width: 12),
                      Text(
                        selectedFrom == null ? 'Válasszon alap devizát' : 'Cél deviza ($selectedFrom →)',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: mockAllCodes.length,
                    itemBuilder: (_, i) {
                      final code = mockAllCodes[i];
                      // In "from" step: skip nothing. In "to" step: skip selected from.
                      if (selectedFrom != null && code == selectedFrom) return const SizedBox();
                      // Skip pairs already in watchlist
                      final alreadyAdded = selectedFrom != null && s.watchlist.any((w) => w.$1 == selectedFrom && w.$2 == code);
                      return ListTile(
                        leading: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(color: kSurface2, shape: BoxShape.circle, border: Border.all(color: kBorder)),
                          alignment: Alignment.center,
                          child: Text(mockCountryCode(code), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(code, style: TextStyle(color: alreadyAdded ? kDim2 : Colors.white, fontWeight: FontWeight.w700)),
                        subtitle: Text(mockCurrencyName(code), style: const TextStyle(color: kDim2, fontSize: 12)),
                        trailing: alreadyAdded
                            ? const Text('Már hozzáadva', style: TextStyle(color: kDim2, fontSize: 11))
                            : null,
                        onTap: alreadyAdded ? null : () {
                          if (selectedFrom == null) {
                            setSheetState(() => selectedFrom = code);
                          } else {
                            // Add pair
                            s.addWatchPair(selectedFrom!, code);
                            Navigator.pop(ctx);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Currency pair picker ──────────────────────────────────────────────────

  void _showPicker(bool isFrom) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 44, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${isFrom ? 'Alap' : 'Cél'} deviza',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: mockAllCodes.length,
                itemBuilder: (ctx, i) {
                  final code = mockAllCodes[i];
                  return ListTile(
                    leading: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: kSurface2, shape: BoxShape.circle, border: Border.all(color: kBorder)),
                      alignment: Alignment.center,
                      child: Text(mockCountryCode(code), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(mockCurrencyName(code), style: const TextStyle(color: kDim2, fontSize: 12)),
                    onTap: () {
                      setState(() {
                        if (isFrom) { _from = code; } else { _to = code; }
                        _history = null; // clear stale data for previous pair
                      });
                      _loadHistory();
                      Navigator.pop(ctx);
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtRate(double v, AppSettings s) {
    if (s.compactNumbers) {
      if (v >= 100) return v.toStringAsFixed(1);
      if (v >= 1)   return v.toStringAsFixed(2);
      return v.toStringAsFixed(4);
    }
    if (v >= 100) return v.toStringAsFixed(2);
    if (v >= 1)   return v.toStringAsFixed(4);
    return v.toStringAsFixed(6);
  }

  List<String> _xLabels() {
    const hu = ['jan.','feb.','már.','ápr.','máj.','jún.','júl.','aug.','szept.','okt.','nov.','dec.'];
    final now  = DateTime.now();
    final days = _tfDays[_tfIdx];
    return List.generate(5, (i) {
      final d = now.subtract(Duration(days: days - (i * days ~/ 4)));
      return '${hu[d.month-1]} ${d.day}.';
    });
  }
}

// ── Watchlist card widget ─────────────────────────────────────────────────

class _WatchCard extends StatelessWidget {
  final String from, to;
  final double rate, chg;
  final List<double> sparkData;
  final bool isPos, isActive, editMode;
  final VoidCallback onTap, onRemove;
  final String Function(double) fmtRate;
  final Color accentColor;
  final bool showSparklines;

  const _WatchCard({
    required this.from, required this.to,
    required this.rate, required this.chg,
    required this.sparkData,
    required this.isPos, required this.isActive,
    required this.editMode,
    required this.onTap, required this.onRemove,
    required this.fmtRate,
    required this.accentColor,
    required this.showSparklines,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isActive && !editMode
                  ? LinearGradient(
                      colors: [accentColor.withAlpha(20), kBorder],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isActive && !editMode ? null : kSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: editMode ? kNeg.withAlpha(60) : (isActive ? accentColor : kBorder),
                width: isActive && !editMode ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$from/$to',
                        style: TextStyle(
                          color: isActive && !editMode ? accentColor : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPos ? kPos.withAlpha(20) : kNeg.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isPos ? '+' : ''}${chg.toStringAsFixed(2)}%',
                        style: TextStyle(color: isPos ? kPos : kNeg, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(fmtRate(rate), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                if (showSparklines) ...[
                  const Spacer(),
                  SizedBox(
                    height: 30,
                    child: MiniSparkline(data: sparkData, color: isPos ? kPos : kNeg, strokeWidth: 1.5),
                  ),
                ] else const Spacer(),
              ],
            ),
          ),
          // Remove button in edit mode
          if (editMode)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: kNeg,
                    shape: BoxShape.circle,
                    border: Border.all(color: kBg, width: 2),
                    boxShadow: [BoxShadow(color: kNeg.withAlpha(60), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Chart painter ──────────────────────────────────────────────────────────

class _ChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor, gridColor, labelColor;
  final List<String> xLabels;

  const _ChartPainter({
    required this.data,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.xLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    const labelH = 20.0;
    const leftPad = 46.0;
    final chartH = size.height - labelH;
    final chartW = size.width - leftPad;

    final minV = data.reduce((a, b) => a < b ? a : b);
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV) == 0 ? 1.0 : maxV - minV;
    final pad  = span * 0.15;
    final lo   = minV - pad;
    final hi   = maxV + pad;
    final range = hi - lo;

    double xOf(int i) => leftPad + (i / (data.length - 1)) * chartW;
    double yOf(double v) => chartH * (1.0 - (v - lo) / range);

    // Grid
    const gridCount = 4;
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    final labelStyle = TextStyle(color: labelColor, fontSize: 10);

    for (int g = 0; g <= gridCount; g++) {
      final y = (g / gridCount) * chartH;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final v  = hi - (g / gridCount) * range;
      final tp = TextPainter(text: TextSpan(text: _fmt(v), style: labelStyle), textDirection: TextDirection.ltr)
        ..layout(maxWidth: leftPad - 4);
      tp.paint(canvas, Offset(0, y - 6));
    }

    // Build smooth path
    final linePath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = xOf(i);
      final y = yOf(data[i]);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        final px = xOf(i - 1);
        final py = yOf(data[i - 1]);
        final cx = (px + x) / 2;
        linePath.cubicTo(cx, py, cx, y, x, y);
      }
    }

    // Fill gradient
    final fillPath = Path()..addPath(linePath, Offset.zero);
    fillPath.lineTo(size.width, chartH);
    fillPath.lineTo(leftPad, chartH);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withAlpha(70), lineColor.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartH))
        ..style = PaintingStyle.fill,
    );

    // Glow
    canvas.drawPath(linePath,
      Paint()..color = lineColor.withAlpha(40)..strokeWidth = 6..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Line
    canvas.drawPath(linePath,
      Paint()..color = lineColor..strokeWidth = 2..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    // Last point dot
    final lastX = xOf(data.length - 1);
    final lastY = yOf(data.last);
    canvas.drawCircle(Offset(lastX, lastY), 7, Paint()..color = lineColor.withAlpha(50));
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = lineColor);

    // X labels
    if (xLabels.isNotEmpty) {
      final xStyle = TextStyle(color: labelColor, fontSize: 10);
      for (int li = 0; li < xLabels.length; li++) {
        final frac = li / (xLabels.length - 1);
        final x    = leftPad + frac * chartW;
        final tp   = TextPainter(text: TextSpan(text: xLabels[li], style: xStyle), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chartH + 4));
      }
    }
  }

  String _fmt(double v) {
    if (v >= 100) return v.toStringAsFixed(1);
    if (v >= 1)   return v.toStringAsFixed(3);
    return v.toStringAsFixed(4);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.data.length != data.length || old.lineColor != lineColor;
}
