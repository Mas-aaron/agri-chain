import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static AlertItem fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      category: (json['category'] as String?) ?? 'Health',
      severity: (json['severity'] as String?) ?? 'Medium',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
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
    await _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _alerts.clear();

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

    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_alerts.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  Future<void> addAlert(AlertItem alert) async {
    await ensureLoaded();
    _alerts.add(alert);
    await _save();
    notifyListeners();
  }

  Future<void> removeAlert(String id) async {
    await ensureLoaded();
    _alerts.removeWhere((a) => a.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> markRead(String id, {required bool isRead}) async {
    await ensureLoaded();
    final idx = _alerts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _alerts[idx] = _alerts[idx].copyWith(isRead: isRead);
    await _save();
    notifyListeners();
  }

  Future<void> markResolved(String id, {required bool isResolved}) async {
    await ensureLoaded();
    final idx = _alerts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _alerts[idx] = _alerts[idx].copyWith(isResolved: isResolved);
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    _alerts.clear();
    await _save();
    notifyListeners();
  }
}
