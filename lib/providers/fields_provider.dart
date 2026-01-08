import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FieldItem {
  final String id;
  final String name;
  final String location;
  final String crop;
  final double? sizeHa;
  final DateTime createdAt;

  const FieldItem({
    required this.id,
    required this.name,
    required this.location,
    required this.crop,
    this.sizeHa,
    required this.createdAt,
  });

  FieldItem copyWith({
    String? name,
    String? location,
    String? crop,
    double? sizeHa,
  }) {
    return FieldItem(
      id: id,
      name: name ?? this.name,
      location: location ?? this.location,
      crop: crop ?? this.crop,
      sizeHa: sizeHa ?? this.sizeHa,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'crop': crop,
        'sizeHa': sizeHa,
        'createdAt': createdAt.toIso8601String(),
      };

  static FieldItem fromJson(Map<String, dynamic> json) {
    final rawSize = json['sizeHa'];
    final size = rawSize is num ? rawSize.toDouble() : double.tryParse('$rawSize');
    return FieldItem(
      id: json['id'] as String,
      name: json['name'] as String,
      location: (json['location'] as String?) ?? '',
      crop: (json['crop'] as String?) ?? 'Maize',
      sizeHa: size,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class FieldsProvider extends ChangeNotifier {
  static const String _storageKey = 'agri_chain_fields_v1';

  final List<FieldItem> _fields = [];
  bool _loaded = false;

  List<FieldItem> get fields {
    final list = List<FieldItem>.from(_fields);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _fields.clear();

    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            _fields.add(FieldItem.fromJson(item.cast<String, dynamic>()));
          }
        }
      }
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_fields.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> addField(FieldItem field) async {
    await ensureLoaded();
    _fields.add(field);
    await _save();
    notifyListeners();
  }

  Future<void> updateField(FieldItem updated) async {
    await ensureLoaded();
    final idx = _fields.indexWhere((f) => f.id == updated.id);
    if (idx >= 0) {
      _fields[idx] = updated;
      await _save();
      notifyListeners();
    }
  }

  Future<void> removeField(String id) async {
    await ensureLoaded();
    _fields.removeWhere((f) => f.id == id);
    await _save();
    notifyListeners();
  }
}
