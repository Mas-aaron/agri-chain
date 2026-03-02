import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'location': location,
        'crop': crop,
        'sizeHa': sizeHa,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static FieldItem fromJson(Map<String, dynamic> json, {String? docId}) {
    final rawSize = json['sizeHa'];
    final size = rawSize is num ? rawSize.toDouble() : double.tryParse('$rawSize');
    
    DateTime parsedDate = DateTime.now();
    if (json['createdAt'] is Timestamp) {
      parsedDate = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      parsedDate = DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now();
    }

    return FieldItem(
      id: docId ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Field',
      location: (json['location'] as String?) ?? '',
      crop: (json['crop'] as String?) ?? 'Maize',
      sizeHa: size,
      createdAt: parsedDate,
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
    await load();
  }

  Future<void> load() async {
    _fields.clear();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Load from Firestore
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fields')
            .get();
        for (final doc in snapshot.docs) {
          _fields.add(FieldItem.fromJson(doc.data(), docId: doc.id));
        }
      } catch (e) {
        debugPrint('Error loading fields from Firestore: $e');
      }
    } else {
      // Load off-chain / local guest data
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
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
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_fields.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> addField(FieldItem field) async {
    await ensureLoaded();
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fields')
          .doc();
      final newField = field.copyWith();
      await docRef.set(newField.toFirestore());
      _fields.add(FieldItem(
        id: docRef.id,
        name: newField.name,
        location: newField.location,
        crop: newField.crop,
        sizeHa: newField.sizeHa,
        createdAt: newField.createdAt,
      ));
    } else {
      _fields.add(field);
      await _saveLocal();
    }
    notifyListeners();
  }

  Future<void> updateField(FieldItem updated) async {
    await ensureLoaded();
    final idx = _fields.indexWhere((f) => f.id == updated.id);
    if (idx >= 0) {
      _fields[idx] = updated;
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fields')
            .doc(updated.id)
            .update(updated.toFirestore());
      } else {
        await _saveLocal();
      }
      notifyListeners();
    }
  }

  Future<void> removeField(String id) async {
    await ensureLoaded();
    _fields.removeWhere((f) => f.id == id);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fields')
          .doc(id)
          .delete();
    } else {
      await _saveLocal();
    }
    notifyListeners();
  }
}
