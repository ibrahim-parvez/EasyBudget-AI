import 'package:flutter/material.dart';

class HouseholdProvider extends ChangeNotifier {
  String? _currentHouseholdId;

  String? get currentHouseholdId => _currentHouseholdId;

  void setHousehold(String? id) {
    _currentHouseholdId = id;
    notifyListeners();
  }

  void clearHousehold() {
    _currentHouseholdId = null;
    notifyListeners();
  }
}
