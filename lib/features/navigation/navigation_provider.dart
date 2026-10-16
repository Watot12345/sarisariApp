import 'package:flutter/material.dart';

/// Manages bottom navigation active tab index.
/// Tab layout: [0: Home, 1: Products, 2: Sell (Center Emphasized), 3: Utang, 4: Reports]
class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setTab(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void openHome() => setTab(0);
  void openProducts() => setTab(1);
  void openSell() => setTab(2);
  void openUtang() => setTab(3);
  void openReports() => setTab(4);

  bool _pendingScan = false;
  bool get pendingScan => _pendingScan;

  /// Handles deep links triggered from the Android Home Screen Widget.
  /// Supported schemes:
  /// - `tindahan://sell` -> Opens POS Sell Screen
  /// - `tindahan://scan` -> Opens POS Sell Screen with Barcode Scanner active
  /// - `tindahan://home` -> Opens Home Dashboard
  void handleUri(Uri? uri) {
    if (uri == null) return;
    if (uri.scheme == 'tindahan') {
      final target = (uri.host.isNotEmpty ? uri.host : uri.path).replaceAll('/', '');
      if (target == 'sell') {
        openSell();
      } else if (target == 'scan') {
        openSell();
        _pendingScan = true;
        notifyListeners();
      } else if (target == 'home') {
        openHome();
      }
    }
  }

  bool consumePendingScan() {
    if (_pendingScan) {
      _pendingScan = false;
      return true;
    }
    return false;
  }
}
