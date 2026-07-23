import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PackingItem {
  String id;
  String name;
  String category;
  int quantity;
  bool isOutboundPacked; // Indulási ellenőrzés
  bool isHomeboundPacked; // Haza ellenőrzés

  PackingItem({
    required this.id,
    required this.name,
    this.category = 'Általános',
    this.quantity = 1,
    this.isOutboundPacked = false,
    this.isHomeboundPacked = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'quantity': quantity,
        'isOutboundPacked': isOutboundPacked,
        'isHomeboundPacked': isHomeboundPacked,
      };

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] ?? '',
        category: json['category'] ?? 'Általános',
        quantity: json['quantity'] ?? 1,
        isOutboundPacked: json['isOutboundPacked'] ?? false,
        isHomeboundPacked: json['isHomeboundPacked'] ?? false,
      );
}

class PackingListService extends ChangeNotifier {
  List<PackingItem> _items = [];
  SharedPreferences? _prefs;

  List<PackingItem> get items => _items;

  // Preset categories
  static const List<String> categories = [
    'Okmányok & Pénz',
    'Elektronika',
    'Ruházat',
    'Tisztálkodás',
    'Gyógyszerek',
    'Egyéb',
  ];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadItems();
  }

  void _loadItems() {
    final raw = _prefs?.getString('packing_items_json');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(raw);
        _items = decoded.map((e) => PackingItem.fromJson(e)).toList();
      } catch (_) {
        _loadDefaults();
      }
    } else {
      _loadDefaults();
    }
    notifyListeners();
  }

  void _loadDefaults() {
    _items = [
      PackingItem(id: '1', name: 'Útlevél / Személyi igazolvány', category: 'Okmányok & Pénz', quantity: 1),
      PackingItem(id: '2', name: 'Bankkártya & Készpénz', category: 'Okmányok & Pénz', quantity: 1),
      PackingItem(id: '3', name: 'Telefon & Töltő', category: 'Elektronika', quantity: 1),
      PackingItem(id: '4', name: 'Powerbank', category: 'Elektronika', quantity: 1),
      PackingItem(id: '5', name: 'Pólók / Felsőruházat', category: 'Ruházat', quantity: 5),
      PackingItem(id: '6', name: 'Alsónemű & Zokni', category: 'Ruházat', quantity: 6),
      PackingItem(id: '7', name: 'Fogkefe & Fogkrém', category: 'Tisztálkodás', quantity: 1),
      PackingItem(id: '8', name: 'Tusfürdő & Sampon', category: 'Tisztálkodás', quantity: 1),
      PackingItem(id: '9', name: 'Alapvető gyógyszerek / Sebtapasz', category: 'Gyógyszerek', quantity: 1),
    ];
    _saveItems();
  }

  Future<void> _saveItems() async {
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await _prefs?.setString('packing_items_json', raw);
  }

  void addItem(String name, String category, int quantity) {
    if (name.trim().isEmpty) return;
    _items.add(PackingItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      category: category,
      quantity: quantity > 0 ? quantity : 1,
    ));
    _saveItems();
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _saveItems();
    notifyListeners();
  }

  void toggleOutbound(String id) {
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx != -1) {
      _items[idx].isOutboundPacked = !_items[idx].isOutboundPacked;
      _saveItems();
      notifyListeners();
    }
  }

  void toggleHomebound(String id) {
    final idx = _items.indexWhere((item) => item.id == id);
    if (idx != -1) {
      _items[idx].isHomeboundPacked = !_items[idx].isHomeboundPacked;
      _saveItems();
      notifyListeners();
    }
  }

  void resetOutbound() {
    for (var item in _items) {
      item.isOutboundPacked = false;
    }
    _saveItems();
    notifyListeners();
  }

  void resetHomebound() {
    for (var item in _items) {
      item.isHomeboundPacked = false;
    }
    _saveItems();
    notifyListeners();
  }

  void resetAll() {
    for (var item in _items) {
      item.isOutboundPacked = false;
      item.isHomeboundPacked = false;
    }
    _saveItems();
    notifyListeners();
  }
}
