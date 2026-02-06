import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  String? _userAddress;
  bool _isConnected = false;
  bool _isDarkMode = false;

  bool get isConnected => _isConnected;
  bool get isDarkMode => _isDarkMode;
  String? get userAddress => _userAddress;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('isDarkMode') ?? false;
    _userAddress = _prefs.getString('userAddress');
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    _isDarkMode = isDark;
    _prefs.setBool('isDarkMode', isDark);
    notifyListeners();
  }

  void setUserAddress(String address) {
    _userAddress = address;
    _prefs.setString('userAddress', address);
    notifyListeners();
  }

  void setConnected(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  void logout() {
    _userAddress = null;
    _isConnected = false;
    _prefs.remove('userAddress');
    notifyListeners();
  }
}
