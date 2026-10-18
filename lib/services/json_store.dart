import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small list persisted as JSON in SharedPreferences (on this phone).
class JsonStore<T> extends ChangeNotifier {
  JsonStore({
    required this.prefsKey,
    required this.fromJson,
    required this.toJson,
    this.maxItems = 1000,
  });

  final String prefsKey;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  final int maxItems;

  List<T> _items = [];
  bool loaded = false;

  List<T> get items => List.unmodifiable(_items);

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(prefsKey);
      if (raw != null) {
        _items = (jsonDecode(raw) as List)
            .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      _items = [];
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(prefsKey, jsonEncode(_items.map(toJson).toList()));
    } catch (_) {/* best effort */}
  }

  Future<void> add(T item, {bool atStart = false}) async {
    if (atStart) {
      _items.insert(0, item);
      if (_items.length > maxItems) _items = _items.sublist(0, maxItems);
    } else {
      _items.add(item);
      if (_items.length > maxItems) _items = _items.sublist(_items.length - maxItems);
    }
    notifyListeners();
    await _save();
  }

  Future<void> replaceWhere(bool Function(T) test, T replacement) async {
    _items = [for (final i in _items) test(i) ? replacement : i];
    notifyListeners();
    await _save();
  }

  Future<void> removeWhere(bool Function(T) test) async {
    _items.removeWhere(test);
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _items = [];
    notifyListeners();
    await _save();
  }
}
