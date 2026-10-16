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
}
