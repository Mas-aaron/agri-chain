import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanProvider extends ChangeNotifier {
  static const _storageKey = 'agri_chain_scan_selected_field_v1';

  bool _loaded = false;
  String? _selectedFieldId;

  String? get selectedFieldId => _selectedFieldId;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _selectedFieldId = prefs.getString(_storageKey);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setSelectedFieldId(String? fieldId) async {
    await ensureLoaded();
    _selectedFieldId = fieldId;
    final prefs = await SharedPreferences.getInstance();
    if (fieldId == null || fieldId.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, fieldId);
    }
    notifyListeners();
  }
}
