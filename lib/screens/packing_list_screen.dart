import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../services/packing_service.dart';

class PackingListScreen extends StatefulWidget {
  const PackingListScreen({super.key});

  @override
  State<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends State<PackingListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PackingListService _packingService = PackingListService();
  bool _ready = false;
  String _selectedCategory = 'Mind';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _packingService.init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _packingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsProvider.of(context);

    if (!_ready) {
      return Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: s.accentColor)),
      );
    }

    return ListenableBuilder(
      listenable: _packingService,
      builder: (context, _) {
        final items = _packingService.items;

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kSurface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Okos Pakolási Csekklista', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: s.accentColor,
              labelColor: s.accentColor,
              unselectedLabelColor: kDim2,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.flight_takeoff_rounded, size: 20), text: '1. Indulási Ellenőrzés'),
                Tab(icon: Icon(Icons.flight_land_rounded, size: 20), text: '2. Haza Ellenőrzés'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Category Filter & Add Bar
              _buildControlHeader(context, s),
              
              // Progress Bar
              _buildProgressBar(s),

              // Tab Views (Outbound & Homebound lists)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChecklist(context, items, isOutbound: true, s: s),
                    _buildChecklist(context, items, isOutbound: false, s: s),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'add_packing_item',
            backgroundColor: s.accentColor,
            foregroundColor: Colors.black,
            onPressed: () => _showAddItemDialog(context, s),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Új elem', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        );
      },
    );
  }

  Widget _buildControlHeader(BuildContext context, AppSettings s) {
    final categories = ['Mind', ...PackingListService.categories];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: kSurface,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final sel = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: sel,
                    selectedColor: s.accentColor.withAlpha(40),
                    side: BorderSide(color: sel ? s.accentColor.withAlpha(80) : kBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    labelStyle: TextStyle(
                      color: sel ? s.accentColor : kDim2,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Koppints a pipáláshoz • Húzd el a törléshez',
                style: TextStyle(color: kDim2.withAlpha(180), fontSize: 11),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: kDim2, size: 20),
                color: kSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kBorder)),
                onSelected: (val) {
                  if (val == 'reset_outbound') _packingService.resetOutbound();
                  if (val == 'reset_homebound') _packingService.resetHomebound();
                  if (val == 'reset_all') _packingService.resetAll();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'reset_outbound', child: Text('Indulási pipák törlése', style: TextStyle(color: Colors.white, fontSize: 13))),
                  const PopupMenuItem(value: 'reset_homebound', child: Text('Hazaérkezési pipák törlése', style: TextStyle(color: Colors.white, fontSize: 13))),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'reset_all', child: Text('Összes pipa törlése', style: TextStyle(color: kNeg, fontSize: 13, fontWeight: FontWeight.w700))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AppSettings s) {
    final items = _packingService.items;
    if (items.isEmpty) return const SizedBox();

    final isOutboundTab = _tabController.index == 0;
    final packedCount = items.where((i) => isOutboundTab ? i.isOutboundPacked : i.isHomeboundPacked).length;
    final progress = items.isEmpty ? 0.0 : packedCount / items.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOutboundTab ? 'Indulás előtti felpakolva:' : 'Hazaút előtt hiánytalanul megvan:',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                '$packedCount / ${items.length} (${(progress * 100).toInt()}%)',
                style: TextStyle(color: s.accentColor, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: kSurface2,
              valueColor: AlwaysStoppedAnimation<Color>(s.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist(BuildContext context, List<PackingItem> items, {required bool isOutbound, required AppSettings s}) {
    final filtered = _selectedCategory == 'Mind'
        ? items
        : items.where((i) => i.category == _selectedCategory).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline_rounded, size: 48, color: kDim2.withAlpha(100)),
            const SizedBox(height: 12),
            const Text('Nincs csomagolási elem ebben a kategóriában.', style: TextStyle(color: kDim2, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final item = filtered[i];
        final isChecked = isOutbound ? item.isOutboundPacked : item.isHomeboundPacked;

        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: kNeg.withAlpha(40), borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.centerRight,
            child: const Icon(Icons.delete_outline_rounded, color: kNeg),
          ),
          onDismissed: (_) {
            _packingService.removeItem(item.id);
            HapticFeedback.mediumImpact();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isChecked ? kSurface.withAlpha(120) : kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isChecked ? s.accentColor.withAlpha(30) : kBorder),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Checkbox(
                value: isChecked,
                activeColor: s.accentColor,
                checkColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (_) {
                  HapticFeedback.lightImpact();
                  if (isOutbound) {
                    _packingService.toggleOutbound(item.id);
                  } else {
                    _packingService.toggleHomebound(item.id);
                  }
                },
              ),
              title: Text(
                item.name,
                style: TextStyle(
                  color: isChecked ? kDim2 : Colors.white,
                  fontWeight: isChecked ? FontWeight.w500 : FontWeight.w700,
                  fontSize: 14,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: kDim2,
                ),
              ),
              subtitle: Text(item.category, style: const TextStyle(color: kDim2, fontSize: 11)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                child: Text('${item.quantity} db', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddItemDialog(BuildContext context, AppSettings s) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String category = PackingListService.categories.first;

    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Új elem hozzáadása', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Elem neve (pl. Napszemüveg)',
                  hintStyle: const TextStyle(color: kDim2),
                  filled: true,
                  fillColor: kBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      dropdownColor: kSurface,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Kategória',
                        labelStyle: const TextStyle(color: kDim2),
                        filled: true, fillColor: kBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                      items: PackingListService.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Darab',
                        labelStyle: const TextStyle(color: kDim2),
                        filled: true, fillColor: kBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: s.accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final qty = int.tryParse(qtyCtrl.text) ?? 1;
                    if (name.isNotEmpty) {
                      _packingService.addItem(name, category, qty);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Hozzáadás', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
