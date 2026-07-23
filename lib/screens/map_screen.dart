import 'package:flutter/material.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import '../main.dart';
import '../services/forex_service.dart';
import '../services/settings_service.dart';
import '../data/mock_data.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _selectedBase = 'USD';
  final TransformationController _transformationController = TransformationController();

  Color _getColorForChange(double change, bool isDark) {
    if (change == 0) return isDark ? Colors.white12 : Colors.black12;
    double val = change.clamp(-2.0, 2.0);
    if (val > 0) {
      return Color.lerp(
        isDark ? Colors.white12 : Colors.black12, 
        kPos, 
        val / 2.0
      )!;
    } else {
      return Color.lerp(
        isDark ? Colors.white12 : Colors.black12, 
        kNeg, 
        (-val) / 2.0
      )!;
    }
  }

  // Extended ISO country codes mapping for comprehensive world coverage
  final Map<String, List<String>> _mapping = const {
    'USD': ['us', 'pr', 'ec', 'sv', 'zw'],
    'EUR': ['at', 'be', 'cy', 'ee', 'fi', 'fr', 'de', 'gr', 'ie', 'it', 'lv', 'lt', 'lu', 'mt', 'nl', 'pt', 'sk', 'si', 'es', 'hr'],
    'GBP': ['gb'],
    'JPY': ['jp'],
    'CHF': ['ch', 'li'],
    'CAD': ['ca'],
    'AUD': ['au', 'nr', 'tv'],
    'CNY': ['cn'],
    'HUF': ['hu'],
    'NOK': ['no', 'sj'],
    'SEK': ['se'],
    'PLN': ['pl'],
    'DKK': ['dk', 'gl', 'fo'],
    'CZK': ['cz'],
    'RON': ['ro'],
    'BGN': ['bg'],
    'TRY': ['tr'],
    'RUB': ['ru'],
    'BRL': ['br'],
    'MXN': ['mx'],
    'INR': ['in'],
    'KRW': ['kr'],
    'SGD': ['sg'],
    'NZD': ['nz'],
    'ZAR': ['za'],
    'EGP': ['eg'],
    'THB': ['th'],
    'IDR': ['id'],
    'MYR': ['my'],
    'PHP': ['ph'],
    'AED': ['ae'],
    'SAR': ['sa'],
    'ILS': ['il'],
    'ARS': ['ar'],
    'CLP': ['cl'],
    'COP': ['co'],
    'PEN': ['pe'],
    'VND': ['vn'],
  };

  Map<String, Color> _buildColorMap(LiveRates lr, bool isDark) {
    final res = <String, Color>{};

    for (final code in _mapping.keys) {
      final change = lr.changes[code] ?? mockChange(code);
      final color = _getColorForChange(change, isDark);
      for (final iso in _mapping[code]!) {
        res[iso] = color;
      }
    }

    return res;
  }

  void _showCountryInfo(BuildContext context, String isoCode, LiveRates lr, AppSettings s) {
    String? foundCode;
    for (final entry in _mapping.entries) {
      if (entry.value.contains(isoCode.toLowerCase())) {
        foundCode = entry.key;
        break;
      }
    }

    if (foundCode == null) return;

    final rate = lr.getRate(_selectedBase, foundCode);
    final change = lr.changes[foundCode] ?? mockChange(foundCode);
    final isPos = change >= 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: kSurface2, shape: BoxShape.circle, border: Border.all(color: kBorder)),
                  alignment: Alignment.center,
                  child: Text(mockCountryCode(foundCode!), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(foundCode, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(mockCurrencyName(foundCode), style: const TextStyle(color: kDim2, fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPos ? kPos.withAlpha(25) : kNeg.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(isPos ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: isPos ? kPos : kNeg),
                      const SizedBox(width: 4),
                      Text('${isPos ? '+' : ''}${change.toStringAsFixed(2)}%',
                          style: TextStyle(color: isPos ? kPos : kNeg, fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
              child: Row(
                children: [
                  Text('1 $_selectedBase = ', style: const TextStyle(color: kDim2, fontSize: 18)),
                  Text(
                    rate.toStringAsFixed(4),
                    style: TextStyle(color: s.accentColor, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  Text(' $foundCode', style: const TextStyle(color: kDim2, fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _zoom(double factor) {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(factor, factor);
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final svc = ForexServiceProvider.of(context);
    final s = SettingsProvider.of(context);
    final lr = svc.rates;

    if (lr == null) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    const isDark = true;
    final colorMap = _buildColorMap(lr, isDark);

    final popularBases = ['USD', 'HUF', 'EUR', 'GBP', 'JPY', 'CHF'];

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  const Icon(Icons.public_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Világtérkép Hőtérkép', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  ),
                  // Base currency picker dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBase,
                        dropdownColor: kSurface,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kDim2, size: 18),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBase = val);
                        },
                        items: popularBases.map((code) => DropdownMenuItem(
                          value: code,
                          child: Text('vs $code'),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Viszonyítás: $_selectedBase. Koppints egy országra a részletekért!', 
                  style: const TextStyle(color: kDim2, fontSize: 12, height: 1.4)),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 8.0,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SimpleMap(
                          instructions: SMapWorld.instructions,
                          defaultColor: isDark ? Colors.white10 : Colors.black12,
                          colors: colorMap,
                          callback: (id, name, tapDetails) {
                            _showCountryInfo(context, id, lr, s);
                          },
                        ),
                      ),
                    ),
                  ),
                  // Floating Zoom Controls for better mobile interaction
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'zoom_in',
                          backgroundColor: kSurface,
                          foregroundColor: Colors.white,
                          onPressed: () => _zoom(1.3),
                          child: const Icon(Icons.add_rounded),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'zoom_out',
                          backgroundColor: kSurface,
                          foregroundColor: Colors.white,
                          onPressed: () => _zoom(0.7),
                          child: const Icon(Icons.remove_rounded),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'zoom_reset',
                          backgroundColor: kSurface,
                          foregroundColor: Colors.white,
                          onPressed: _resetZoom,
                          child: const Icon(Icons.center_focus_strong_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendItem(kNeg, 'Gyengült'),
                  const SizedBox(width: 16),
                  _legendItem(Colors.white12, 'Nincs adat'),
                  const SizedBox(width: 16),
                  _legendItem(kPos, 'Erősödött'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: kDim2, fontSize: 11)),
      ],
    );
  }
}
