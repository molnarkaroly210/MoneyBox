import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../services/forex_service.dart';
import '../data/mock_data.dart';
import 'licenses_screen.dart';
import 'packing_list_screen.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsProvider.of(context);
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(s: s),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                children: [
                  const SizedBox(height: 8),
                  _AccentSection(s: s),
                  const SizedBox(height: 16),
                  _UxSection(s: s),
                  const SizedBox(height: 16),
                  _DataSection(s: s),
                  const SizedBox(height: 16),
                  _ConverterSection(s: s),
                  const SizedBox(height: 16),
                  _WatchlistSection(s: s),
                  const SizedBox(height: 16),
                  _AboutSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AppSettings s;
  const _Header({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [s.accentColor, s.accentColor2],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('MB', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13))),
          ),
          const SizedBox(width: 10),
          const Text('Beállítások', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kSurface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder),
            ),
            child: FutureBuilder<String>(
              future: UpdateService.getCurrentVersion(),
              builder: (context, snapshot) {
                final ver = snapshot.data ?? '1.0.0';
                return Text('v$ver', style: const TextStyle(color: kDim2, fontSize: 11, fontWeight: FontWeight.w600));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card wrapper ──────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final s = SettingsProvider.of(context);
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: (iconColor ?? s.accentColor).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor ?? s.accentColor, size: 16),
                ),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(height: 1, color: kBorder),
          ...children,
        ],
      ),
    );
  }
}

Widget _settingRow({
  required String label,
  String? subtitle,
  required Widget trailing,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: kDim2, fontSize: 12)),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    ),
  );
}

// ── Accent colors ─────────────────────────────────────────────────────────

class _AccentSection extends StatelessWidget {
  final AppSettings s;
  const _AccentSection({required this.s});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Témaszín',
      icon: Icons.palette_rounded,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Válassz egy akcentszínt', style: TextStyle(color: kDim2, fontSize: 12)),
              const SizedBox(height: 14),
              Row(
                children: List.generate(kAccentPresets.length, (i) {
                  final preset = kAccentPresets[i];
                  final sel    = i == s.accentIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        s.setAccent(i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: i < kAccentPresets.length - 1 ? 8 : 0),
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [preset.color, preset.secondary],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel ? Colors.white : Colors.transparent,
                            width: sel ? 2.5 : 0,
                          ),
                          boxShadow: sel
                              ? [BoxShadow(color: preset.color.withAlpha(100), blurRadius: 16, offset: const Offset(0, 4))]
                              : [],
                        ),
                        child: sel
                            ? const Center(child: Icon(Icons.check_rounded, color: Colors.black, size: 22))
                            : null,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  kAccentPresets[s.accentIndex].name,
                  style: TextStyle(color: s.accentColor, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── UX finomítások ────────────────────────────────────────────────────────

class _UxSection extends StatelessWidget {
  final AppSettings s;
  const _UxSection({required this.s});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Megjelenés & Animációk',
      icon: Icons.auto_awesome_rounded,
      children: [
        _settingRow(
          label: 'Animációk',
          subtitle: 'Átmenetek és mikroanimációk',
          trailing: _Switch(
            value: s.showAnimations,
            accentColor: s.accentColor,
            onChanged: (v) { HapticFeedback.lightImpact(); s.setAnimations(v); },
          ),
        ),
        Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
        _settingRow(
          label: 'Sparkline grafikonok',
          subtitle: 'Mini diagramok az árfolyam listán',
          trailing: _Switch(
            value: s.showSparklines,
            accentColor: s.accentColor,
            onChanged: (v) { HapticFeedback.lightImpact(); s.setShowSparklines(v); },
          ),
        ),
        Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
        _settingRow(
          label: 'Kompakt számformátum',
          subtitle: 'pl. 354.47 → 354,5',
          trailing: _Switch(
            value: s.compactNumbers,
            accentColor: s.accentColor,
            onChanged: (v) { HapticFeedback.lightImpact(); s.setCompactNumbers(v); },
          ),
        ),
        Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
        _settingRow(
          label: 'Kompakt konverter mód',
          subtitle: 'Csak a számológép megjelenítése',
          trailing: _Switch(
            value: s.simpleConverterMode,
            accentColor: s.accentColor,
            onChanged: (v) { HapticFeedback.lightImpact(); s.setSimpleConverterMode(v); },
          ),
        ),
        Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
        _settingRow(
          label: 'Okos Pakolási Csekklista',
          subtitle: 'Egyéni utazási csomagolási lista',
          trailing: _Switch(
            value: s.enablePackingList,
            accentColor: s.accentColor,
            onChanged: (v) { HapticFeedback.lightImpact(); s.setEnablePackingList(v); },
          ),
        ),
        if (s.enablePackingList) ...[
          Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PackingListScreen()),
              );
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.backpack_rounded, color: s.accentColor, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Csekklista megnyitása', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('Indulási & Hazaérkezési ellenőrzés', style: TextStyle(color: kDim2, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: kDim2, size: 20),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Adatok ────────────────────────────────────────────────────────────────

class _DataSection extends StatelessWidget {
  final AppSettings s;
  const _DataSection({required this.s});

  static const _options = [5, 15, 30, 60];
  static const _labels  = ['5 perc', '15 perc', '30 perc', '1 óra'];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Adatok & Frissítés',
      icon: Icons.sync_rounded,
      iconColor: kPos,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Automatikus frissítési időköz', style: TextStyle(color: kDim2, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: List.generate(_options.length, (i) {
                  final sel = _options[i] == s.refreshMinutes;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        s.setRefreshMinutes(_options[i]);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: i < _options.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: sel
                              ? LinearGradient(
                                  colors: [s.accentColor, s.accentColor2],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                )
                              : null,
                          color: sel ? null : kSurface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sel ? Colors.transparent : kBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _labels[i],
                          style: TextStyle(
                            color: sel ? Colors.black : kDim2,
                            fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: kBorder),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adatforrás', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                        SizedBox(height: 3),
                        Text('Automatikus váltás, ha az elsődleges hibás', style: TextStyle(color: kDim2, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _badge('open.er-api.com', kPos),
                      const SizedBox(height: 4),
                      _badge('frankfurter.dev', kDim2),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withAlpha(60)),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Konverter alapértelmezések ────────────────────────────────────────────

class _ConverterSection extends StatelessWidget {
  final AppSettings s;
  const _ConverterSection({required this.s});

  @override
  Widget build(BuildContext context) {
    final svc = ForexServiceProvider.of(context);
    final lr  = svc.rates;

    return _SectionCard(
      title: 'Konverter alapértelmezések',
      icon: Icons.swap_horiz_rounded,
      children: [
        _settingRow(
          label: 'Alapdeviza',
          subtitle: mockCurrencyName(s.defaultFrom),
          trailing: _CurrencyChip(code: s.defaultFrom, accentColor: s.accentColor),
          onTap: () => _pickCurrency(context, true, lr),
        ),
        Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
        _settingRow(
          label: 'Céldeviza',
          subtitle: mockCurrencyName(s.defaultTo),
          trailing: _CurrencyChip(code: s.defaultTo, accentColor: s.accentColor),
          onTap: () => _pickCurrency(context, false, lr),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: s.accentColor.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: s.accentColor.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: s.accentColor.withAlpha(180), size: 14),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ez az alapértelmezett pár az Átváltó képernyőn az alkalmazás indításakor.',
                    style: TextStyle(color: kDim2, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _pickCurrency(BuildContext context, bool isFrom, LiveRates? lr) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CurrencyPickerSheet(
        title: isFrom ? 'Alapdeviza' : 'Céldeviza',
        lr: lr,
        accentColor: s.accentColor,
        onSelect: (code) {
          if (isFrom) {
            s.setDefaultFrom(code);
          } else {
            s.setDefaultTo(code);
          }
        },
      ),
    );
  }
}

// ── Figyelőlista ──────────────────────────────────────────────────────────

class _WatchlistSection extends StatefulWidget {
  final AppSettings s;
  const _WatchlistSection({required this.s});

  @override
  State<_WatchlistSection> createState() => _WatchlistSectionState();
}

class _WatchlistSectionState extends State<_WatchlistSection> {
  bool _editMode = false;

  @override
  Widget build(BuildContext context) {
    final pairs = widget.s.watchlist;
    final s     = widget.s;

    return _SectionCard(
      title: 'Figyelőlista',
      icon: Icons.remove_red_eye_rounded,
      iconColor: kGold,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('${pairs.length} devizapár', style: const TextStyle(color: kDim2, fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _editMode = !_editMode);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _editMode ? kNeg.withAlpha(20) : kSurface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _editMode ? kNeg.withAlpha(60) : kBorder),
                  ),
                  child: Text(
                    _editMode ? 'Kész' : 'Szerkesztés',
                    style: TextStyle(
                      color: _editMode ? kNeg : kDim2,
                      fontSize: 11, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Pairs list
        ...List.generate(pairs.length, (i) {
          final (from, to) = pairs[i];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _pairBadge(from),
                      const Icon(Icons.arrow_forward_rounded, color: kDim2, size: 14),
                      const SizedBox(width: 6),
                      _pairBadge(to),
                      const SizedBox(width: 8),
                      Text(mockCurrencyName(to), style: const TextStyle(color: kDim2, fontSize: 12)),
                      const Spacer(),
                      if (_editMode)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            s.removeWatchPair(i);
                          },
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: kNeg.withAlpha(20), shape: BoxShape.circle, border: Border.all(color: kNeg.withAlpha(60))),
                            child: const Icon(Icons.close_rounded, color: kNeg, size: 16),
                          ),
                        )
                      else
                        const Icon(Icons.drag_handle_rounded, color: kDim, size: 18),
                    ],
                  ),
                ),
                if (i < pairs.length - 1)
                  Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
              ],
            ),
          );
        }),
        // Add button
        GestureDetector(
          onTap: () => _showAddSheet(context, s),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: s.accentColor.withAlpha(10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: s.accentColor.withAlpha(50), style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded, color: s.accentColor, size: 18),
                const SizedBox(width: 8),
                Text('Devizapár hozzáadása', style: TextStyle(color: s.accentColor, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pairBadge(String code) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  void _showAddSheet(BuildContext context, AppSettings s) {
    String? selectedFrom;
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SizedBox(
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
                      selectedFrom == null ? 'Alap deviza' : 'Cél deviza ($selectedFrom →)',
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
                    final code   = mockAllCodes[i];
                    if (selectedFrom != null && code == selectedFrom) return const SizedBox();
                    final exists = selectedFrom != null && s.watchlist.any((p) => p.$1 == selectedFrom && p.$2 == code);
                    return ListTile(
                      leading: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: kSurface2, shape: BoxShape.circle, border: Border.all(color: kBorder)),
                        alignment: Alignment.center,
                        child: Text(mockCountryCode(code), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(code, style: TextStyle(color: exists ? kDim2 : Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text(mockCurrencyName(code), style: const TextStyle(color: kDim2, fontSize: 12)),
                      trailing: exists ? const Text('Már hozzáadva', style: TextStyle(color: kDim2, fontSize: 11)) : null,
                      onTap: exists ? null : () {
                        if (selectedFrom == null) {
                          setSheetState(() => selectedFrom = code);
                        } else {
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
        ),
      ),
    );
  }
}

// ── About ─────────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = SettingsProvider.of(context);
    return _SectionCard(
      title: 'Az alkalmazásról',
      icon: Icons.info_outline_rounded,
      iconColor: kDim2,
      children: [
        FutureBuilder<String>(
          future: UpdateService.getCurrentVersion(),
          builder: (context, snapshot) => _infoRow('Verzió', 'MoneyBox ${snapshot.data ?? '1.0.0'}'),
        ),
        Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
        _infoRow('Adatforrás', 'open.er-api.com · frankfurter.dev'),
        Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
        _infoRow('Frissítési mód', 'Automatikus · ${s.refreshMinutes} percenként'),
        Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
        GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Frissítések keresése a GitHubon...'),
                duration: Duration(seconds: 2),
              ),
            );
            final currentVer = await UpdateService.getCurrentVersion();
            final info = await UpdateService.checkForUpdates();
            if (context.mounted) {
              if (info != null) {
                UpdateDialog.show(context, info);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: kSurface2,
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: s.accentColor, size: 20),
                        const SizedBox(width: 10),
                        Text('A legfrissebb verziót használod! (v$currentVer)', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                );
              }
            }
          },
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                const Text('Frissítések keresése', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                FutureBuilder<String>(
                  future: UpdateService.getCurrentVersion(),
                  builder: (context, snapshot) {
                    final ver = snapshot.data ?? '1.0.0';
                    return Text('v$ver', style: TextStyle(color: s.accentColor, fontSize: 12, fontWeight: FontWeight.w700));
                  },
                ),
                const SizedBox(width: 6),
                const Icon(Icons.refresh_rounded, color: kDim2, size: 18),
              ],
            ),
          ),
        ),
        Container(height: 1, margin: const EdgeInsets.only(left: 16), color: kBorder),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LicensesScreen()),
            );
          },
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: const Row(
              children: [
                Text('Licencek & Szerzői jogok', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                Spacer(),
                Icon(Icons.chevron_right_rounded, color: kDim2, size: 20),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Clear all prefs
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: kSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Visszaállítás', style: TextStyle(color: Colors.white)),
                        content: const Text('Biztosan visszaállítod az alapértelmezett beállításokat?', style: TextStyle(color: kDim2)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mégse', style: TextStyle(color: kDim2))),
                          TextButton(
                            onPressed: () {
                              s.setAccent(0);
                              s.setRefreshMinutes(30);
                              s.setAnimations(true);
                              s.setShowSparklines(true);
                              s.setCompactNumbers(false);
                              s.setDefaultFrom('USD');
                              s.setDefaultTo('HUF');
                              Navigator.pop(context);
                            },
                            child: Text('Visszaállítás', style: TextStyle(color: kNeg)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: kNeg.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kNeg.withAlpha(50)),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restore_rounded, color: kNeg, size: 16),
                        SizedBox(width: 8),
                        Text('Alapértelmezések visszaállítása', style: TextStyle(color: kNeg, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: kDim2, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────

class _Switch extends StatelessWidget {
  final bool value;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _Switch({required this.value, required this.accentColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 48, height: 28,
        decoration: BoxDecoration(
          gradient: value
              ? LinearGradient(colors: [accentColor, accentColor.withAlpha(180)])
              : null,
          color: value ? null : kSurface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? Colors.transparent : kBorder),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22, height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: value ? Colors.black : kDim,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String code;
  final Color accentColor;
  const _CurrencyChip({required this.code, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(code, style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_right_rounded, color: accentColor.withAlpha(150), size: 14),
        ],
      ),
    );
  }
}

class _CurrencyPickerSheet extends StatefulWidget {
  final String title;
  final LiveRates? lr;
  final Color accentColor;
  final void Function(String) onSelect;
  const _CurrencyPickerSheet({required this.title, required this.lr, required this.accentColor, required this.onSelect});

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final codes = mockAllCodes.where((c) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Keresés...',
                hintStyle: const TextStyle(color: kDim2),
                prefixIcon: const Icon(Icons.search, color: kDim2, size: 20),
                filled: true, fillColor: kSurface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: widget.accentColor)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: codes.length,
              itemBuilder: (_, i) {
                final code  = codes[i];
                final rate  = widget.lr?.getRate('USD', code);
                final rStr  = rate != null ? (rate >= 10 ? rate.toStringAsFixed(2) : rate.toStringAsFixed(4)) : '—';
                return ListTile(
                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: kSurface2, shape: BoxShape.circle, border: Border.all(color: kBorder)),
                    alignment: Alignment.center,
                    child: Text(mockCountryCode(code), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(mockCurrencyName(code), style: const TextStyle(color: kDim2, fontSize: 12)),
                  trailing: Text(rStr, style: TextStyle(color: widget.accentColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  onTap: () { widget.onSelect(code); Navigator.pop(context); },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
