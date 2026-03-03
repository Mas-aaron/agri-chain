import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlertItem {
  final String id;
  final String title;
  final String message;
  final String category;
  final String severity;
  final DateTime createdAt;
  final String? fieldId;
  final bool isRead;
  final bool isResolved;
  final String? imagePath;
  final Map<String, dynamic>? extra;

  const AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.severity,
    required this.createdAt,
    this.fieldId,
    this.isRead = false,
    this.isResolved = false,
    this.imagePath,
    this.extra,
  });

  AlertItem copyWith({
    String? title,
    String? message,
    String? category,
    String? severity,
    DateTime? createdAt,
    String? fieldId,
    bool? isRead,
    bool? isResolved,
    String? imagePath,
    Map<String, dynamic>? extra,
  }) {
    return AlertItem(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      createdAt: createdAt ?? this.createdAt,
      fieldId: fieldId ?? this.fieldId,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved ?? this.isResolved,
      imagePath: imagePath ?? this.imagePath,
      extra: extra ?? this.extra,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'category': category,
        'severity': severity,
        'createdAt': createdAt.toIso8601String(),
        'fieldId': fieldId,
        'isRead': isRead,
        'isResolved': isResolved,
        'imagePath': imagePath,
        'extra': extra,
      };

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'message': message,
        'category': category,
        'severity': severity,
        'createdAt': Timestamp.fromDate(createdAt),
        'fieldId': fieldId,
        'isRead': isRead,
        'isResolved': isResolved,
        'imagePath': imagePath,
        'extra': extra,
      };

  static AlertItem fromJson(Map<String, dynamic> json, {String? docId}) {
    DateTime parsedDate = DateTime.now();
    if (json['createdAt'] is Timestamp) {
      parsedDate = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      parsedDate = DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now();
    }

    return AlertItem(
      id: docId ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Alert',
      message: json['message'] as String? ?? '',
      category: (json['category'] as String?) ?? 'Health',
      severity: (json['severity'] as String?) ?? 'Medium',
      createdAt: parsedDate,
      fieldId: json['fieldId'] as String?,
      isRead: (json['isRead'] as bool?) ?? false,
      isResolved: (json['isResolved'] as bool?) ?? false,
      imagePath: json['imagePath'] as String?,
      extra: (json['extra'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

class AlertsProvider extends ChangeNotifier {
  static const String _storageKey = 'agri_chain_alerts_v1';

  final List<AlertItem> _alerts = [];
  bool _loaded = false;

  List<AlertItem> get alerts {
    final list = List<AlertItem>.from(_alerts);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<AlertItem> alertsForField(String fieldId) {
    return alerts.where((a) => a.fieldId == fieldId).toList();
  }

  int get unreadCount => alerts.where((a) => !a.isRead).length;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    _alerts.clear();
    final user = FirebaseAuth.instance.currentUser;

    // Always load local alerts first (instant, works offline)
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            _alerts.add(AlertItem.fromJson(item.cast<String, dynamic>()));
          }
        }
      }
    }

    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('alerts')
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 3), onTimeout: () {
          throw Exception('Firestore timeout — using local alerts');
        });
        // Merge Firestore alerts with local ones
        final localIds = _alerts.map((a) => a.id).toSet();
        for (final doc in snapshot.docs) {
          if (!localIds.contains(doc.id)) {
            _alerts.add(AlertItem.fromJson(doc.data(), docId: doc.id));
          }
        }
      } catch (e) {
        debugPrint('⚠️ Firestore load failed (offline?): $e — using local alerts');
      }
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_alerts.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> addAlert(AlertItem alert) async {
    await ensureLoaded();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alerts')
          .doc();
      // Add locally first (instant, works offline)
      _alerts.add(AlertItem(
        id: docRef.id,
        title: alert.title,
        message: alert.message,
        category: alert.category,
        severity: alert.severity,
        createdAt: alert.createdAt,
        fieldId: alert.fieldId,
        isRead: alert.isRead,
        isResolved: alert.isResolved,
        imagePath: alert.imagePath,
        extra: alert.extra,
      ));
      await _saveLocal();
      // Fire-and-forget Firestore write — syncs when online, never blocks offline
      docRef.set(alert.toFirestore()).catchError((e) {
        debugPrint('⚠️ Firestore alert write failed (offline?): $e');
      });
    } else {
      _alerts.add(alert);
      await _saveLocal();
    }
    notifyListeners();
  }

  Future<void> removeAlert(String id) async {
    await ensureLoaded();
    _alerts.removeWhere((a) => a.id == id);
    await _saveLocal();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alerts')
          .doc(id)
          .delete()
          .catchError((e) => debugPrint('⚠️ Firestore delete failed: $e'));
    }
    notifyListeners();
  }

  Future<void> markRead(String id, {required bool isRead}) async {
    await ensureLoaded();
    final idx = _alerts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _alerts[idx] = _alerts[idx].copyWith(isRead: isRead);
    await _saveLocal();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alerts')
          .doc(id)
          .update({'isRead': isRead})
          .catchError((e) => debugPrint('⚠️ Firestore markRead failed: $e'));
    }
    notifyListeners();
  }

  Future<void> markResolved(String id, {required bool isResolved}) async {
    await ensureLoaded();
    final idx = _alerts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _alerts[idx] = _alerts[idx].copyWith(isResolved: isResolved);
    await _saveLocal();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alerts')
          .doc(id)
          .update({'isResolved': isResolved})
          .catchError((e) => debugPrint('⚠️ Firestore markResolved failed: $e'));
    }
    notifyListeners();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    _alerts.clear();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alerts')
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } else {
      await _saveLocal();
    }
    notifyListeners();
  }
}
