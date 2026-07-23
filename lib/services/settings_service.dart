import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Accent color presets ────────────────────────────────────────────────────

class AccentPreset {
  final String name;
  final Color color;
  final Color secondary;
  const AccentPreset({required this.name, required this.color, required this.secondary});
}

const kAccentPresets = [
  AccentPreset(name: 'Neonfény',    color: Color(0xFF00F5B0), secondary: Color(0xFF00B4D8)),
  AccentPreset(name: 'Villám',      color: Color(0xFF39FF14), secondary: Color(0xFF00FF88)),
  AccentPreset(name: 'Lila mágus',  color: Color(0xFFA855F7), secondary: Color(0xFF7C3AED)),
  AccentPreset(name: 'Napraforgó',  color: Color(0xFFFFB74D), secondary: Color(0xFFF59E0B)),
  AccentPreset(name: 'Rózsaszín',   color: Color(0xFFF43F5E), secondary: Color(0xFFEC4899)),
  AccentPreset(name: 'Égszínkék',   color: Color(0xFF38BDF8), secondary: Color(0xFF0EA5E9)),
];

// ── Settings model ──────────────────────────────────────────────────────────

class AppSettings extends ChangeNotifier {
  // Megjelenés
  int accentIndex        = 0;
  bool showAnimations    = true;
  bool compactNumbers    = false;
  bool showSparklines    = true;
  bool simpleConverterMode = false;
  bool enablePackingList   = false; // Okos Pakolási Csekklista beállítva

  // Adatok
  int refreshMinutes     = 30;   // 5, 15, 30, 60
  String baseRateCurrency = 'USD';

  // Konverter alapértelmezések
  String defaultFrom     = 'USD';
  String defaultTo       = 'HUF';

  // Figyelőlista (perzisztens)
  List<String> _watchlistRaw = ['EUR/HUF', 'USD/HUF', 'EUR/USD', 'GBP/USD'];

  AccentPreset get accent       => kAccentPresets[accentIndex.clamp(0, kAccentPresets.length - 1)];
  Color        get accentColor  => accent.color;
  Color        get accentColor2 => accent.secondary;

  List<(String, String)> get watchlist => _watchlistRaw.map((s) {
    final parts = s.split('/');
    return parts.length == 2 ? (parts[0], parts[1]) : ('EUR', 'USD');
  }).toList();

  // ── SharedPreferences ────────────────────────────────────────────────────

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    final p = _prefs;
    if (p == null) return;
    accentIndex         = p.getInt('accentIndex')        ?? 0;
    showAnimations      = p.getBool('showAnimations')    ?? true;
    compactNumbers      = p.getBool('compactNumbers')    ?? false;
    showSparklines      = p.getBool('showSparklines')    ?? true;
    simpleConverterMode = p.getBool('simpleConverterMode') ?? false;
    enablePackingList   = p.getBool('enablePackingList')   ?? false;
    refreshMinutes      = p.getInt('refreshMinutes')     ?? 30;
    baseRateCurrency    = p.getString('baseRateCurrency') ?? 'USD';
    defaultFrom         = p.getString('defaultFrom')     ?? 'USD';
    defaultTo           = p.getString('defaultTo')       ?? 'HUF';
    final wl            = p.getStringList('watchlist');
    if (wl != null && wl.isNotEmpty) _watchlistRaw = wl;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt('accentIndex',         accentIndex);
    await p.setBool('showAnimations',     showAnimations);
    await p.setBool('compactNumbers',     compactNumbers);
    await p.setBool('showSparklines',     showSparklines);
    await p.setBool('simpleConverterMode', simpleConverterMode);
    await p.setBool('enablePackingList',   enablePackingList);
    await p.setInt('refreshMinutes',      refreshMinutes);
    await p.setString('baseRateCurrency', baseRateCurrency);
    await p.setString('defaultFrom',      defaultFrom);
    await p.setString('defaultTo',        defaultTo);
    await p.setStringList('watchlist',    _watchlistRaw);
  }

  // ── Setters ──────────────────────────────────────────────────────────────

  void setAccent(int i) {
    accentIndex = i.clamp(0, kAccentPresets.length - 1);
    _save();
    notifyListeners();
  }

  void setAnimations(bool v) {
    showAnimations = v;
    _save();
    notifyListeners();
  }

  void setCompactNumbers(bool v) {
    compactNumbers = v;
    _save();
    notifyListeners();
  }

  void setShowSparklines(bool v) {
    showSparklines = v;
    _save();
    notifyListeners();
  }

  void setSimpleConverterMode(bool v) {
    simpleConverterMode = v;
    _save();
    notifyListeners();
  }

  void setEnablePackingList(bool v) {
    enablePackingList = v;
    _save();
    notifyListeners();
  }

  void setRefreshMinutes(int v) {
    refreshMinutes = v;
    _save();
    notifyListeners();
  }

  void setBaseRateCurrency(String v) {
    baseRateCurrency = v;
    _save();
    notifyListeners();
  }

  void setDefaultFrom(String v) {
    defaultFrom = v;
    _save();
    notifyListeners();
  }

  void setDefaultTo(String v) {
    defaultTo = v;
    _save();
    notifyListeners();
  }

  void setWatchlist(List<(String, String)> pairs) {
    _watchlistRaw = pairs.map((p) => '${p.$1}/${p.$2}').toList();
    _save();
    notifyListeners();
  }

  void addWatchPair(String from, String to) {
    final key = '$from/$to';
    if (!_watchlistRaw.contains(key)) {
      _watchlistRaw.add(key);
      _save();
      notifyListeners();
    }
  }

  void removeWatchPair(int index) {
    if (index >= 0 && index < _watchlistRaw.length) {
      _watchlistRaw.removeAt(index);
      _save();
      notifyListeners();
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

class SettingsProvider extends InheritedNotifier<AppSettings> {
  const SettingsProvider({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
    assert(p != null, 'No SettingsProvider found in widget tree');
    return p!.notifier!;
  }

  /// Read without subscribing (won't rebuild)
  static AppSettings read(BuildContext context) {
    final p = context.getInheritedWidgetOfExactType<SettingsProvider>();
    assert(p != null, 'No SettingsProvider found in widget tree');
    return p!.notifier!;
  }
}

class SettingsRoot extends StatefulWidget {
  final Widget child;
  const SettingsRoot({super.key, required this.child});

  @override
  State<SettingsRoot> createState() => _SettingsRootState();
}

class _SettingsRootState extends State<SettingsRoot> {
  final _settings = AppSettings();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _settings.init().then((_) => setState(() => _ready = true));
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Splash while loading
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF060B14),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF00F5B0))),
        ),
      );
    }
    return SettingsProvider(settings: _settings, child: widget.child);
  }
}
