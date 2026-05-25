import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _loading = false;
  String? _error;

  UserModel? get user    => _user;
  bool       get loading => _loading;
  String?    get error   => _error;
  bool       get isLoggedIn => _user != null;
  bool       get isAdmin    => _user?.isAdmin ?? false;

  Future<void> loadFromStorage() async {
    final j = AppStorage.getUser();
    if (j != null) {
      _user = UserModel.fromJson(jsonDecode(j));
      notifyListeners();
    }
  }

  Future<bool> register({required String fullName,
      required String email, required String password}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final data = await ApiClient.register(
          fullName: fullName, email: email, password: password);
      await _save(data);
      return true;
    } on ApiException catch (e) {
      _error = e.message; return false;
    } finally { _loading = false; notifyListeners(); }
  }

  Future<bool> login({required String email, required String password}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      final data = await ApiClient.login(email: email, password: password);
      await _save(data);
      return true;
    } on ApiException catch (e) {
      _error = e.message; return false;
    } finally { _loading = false; notifyListeners(); }
  }

  Future<void> logout() async {
    await AppStorage.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> _save(Map<String, dynamic> data) async {
    await AppStorage.saveToken(data['access_token']);
    await AppStorage.saveUser(jsonEncode(data['user']));
    _user = UserModel.fromJson(data['user']);
  }
}
