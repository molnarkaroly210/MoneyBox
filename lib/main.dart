import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/converter_screen.dart';
import 'screens/rates_screen.dart';
import 'screens/map_screen.dart';
import 'screens/news_screen.dart';
import 'screens/settings_screen.dart';
import 'services/forex_service.dart';
import 'services/settings_service.dart';

// ── Static design tokens (never change) ───────────────────────────────────
const kBg       = Color(0xFF060B14);
const kSurface  = Color(0xFF0F1723);
const kSurface2 = Color(0xFF162030);
const kAccent   = Color(0xFF00F5B0); // default fallback accent
const kAccent2  = Color(0xFF7C3AED);
const kPos      = Color(0xFF00E676);
const kNeg      = Color(0xFFFF3D6B);
const kDim      = Color(0xFF4A5568);
const kDim2     = Color(0xFF718096);
const kBorder   = Color(0xFF1E2D45);
const kGold     = Color(0xFFFFB74D);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF060B14),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MoneyBoxApp());
}

class MoneyBoxApp extends StatelessWidget {
  const MoneyBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    // SettingsRoot loads prefs before showing the app
    return SettingsRoot(
      child: ForexServiceRoot(
        child: Builder(builder: (ctx) {
          final s = SettingsProvider.of(ctx);
          return MaterialApp(
            title: 'MoneyBox',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: kBg,
              colorScheme: ColorScheme.dark(
                primary: s.accentColor,
                surface: kSurface,
              ),
              textTheme: const TextTheme(
                bodyMedium: TextStyle(fontFamily: 'Inter', color: Colors.white),
              ),
              snackBarTheme: SnackBarThemeData(
                backgroundColor: kSurface2,
                contentTextStyle: const TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                behavior: SnackBarBehavior.floating,
              ),
            ),
            home: const MainShell(),
          );
        }),
      ),
    );
  }
}

// ── Main shell ────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _idx = 0;

  static const _items = [
    _NavItem(Icons.swap_vertical_circle_rounded, Icons.swap_vertical_circle_outlined, 'Átváltó'),
    _NavItem(Icons.show_chart_rounded,            Icons.show_chart_rounded,             'Árfolyam'),
    _NavItem(Icons.article_rounded,               Icons.article_outlined,               'Hírek'),
    _NavItem(Icons.public_rounded,                Icons.public_outlined,                'Térkép'),
    _NavItem(Icons.settings_rounded,              Icons.settings_outlined,              'Beállítások'),
  ];

  void _onTap(int i) {
    if (i == _idx) return;
    HapticFeedback.lightImpact();
    setState(() => _idx = i);
  }

  @override
  Widget build(BuildContext context) {
    final s      = SettingsProvider.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: kBg,
      extendBody: true,
      body: IndexedStack(
        index: _idx,
        children: const [
          ConverterScreen(),
          RatesScreen(),
          NewsScreen(),
          MapScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _BubbleNav(
        selectedIndex: _idx,
        items: _items,
        onTap: _onTap,
        bottomPadding: bottom,
        accentColor: s.accentColor,
      ),
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}

// ── Bubble nav bar (dynamic accent) ──────────────────────────────────────

class _BubbleNav extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final void Function(int) onTap;
  final double bottomPadding;
  final Color accentColor;

  const _BubbleNav({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
    required this.bottomPadding,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 12),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: kBorder, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(120), blurRadius: 30, offset: const Offset(0, 10)),
            BoxShadow(color: accentColor.withAlpha(20),   blurRadius: 40, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final sel = i == selectedIndex;
            // Settings tab gets a distinct dim accent
            final tabColor = (i == items.length - 1 && !sel) ? kDim2 : (sel ? accentColor : kDim2);
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: sel ? accentColor.withAlpha(22) : Colors.transparent,
                    borderRadius: BorderRadius.circular(34),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          sel ? items[i].activeIcon : items[i].icon,
                          key: ValueKey(sel),
                          color: tabColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: tabColor,
                          fontSize: 9,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                        child: Text(items[i].label),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
