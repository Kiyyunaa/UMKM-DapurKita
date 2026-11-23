import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'cart_service.dart';

/// Layanan Autentikasi untuk Login, Register, Profile, dan Role Guard.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isLoading => _isLoading;

  static const String _keyUserData = 'user_data_cache';

  /// Inisialisasi membaca sesi login yang tersimpan
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_keyUserData);
      final token = await ApiService.getToken();

      if (token != null && userJson != null) {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        notifyListeners();
        // Segarkan profil di latar belakang
        fetchProfile().catchError((_) => null);
      }
    } catch (_) {}
  }

  /// 1. Masuk Akun (Login)
  Future<UserModel> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.post('/api/auth/login', {
        'email': email.trim(),
        'password': password,
      });

      final token = res['token']?.toString();
      final userData = res['data'];

      if (token == null || userData == null) {
        throw Exception('Respons login tidak valid dari server.');
      }

      await ApiService.setToken(token);
      ApiService.resetUnauthorized();
      _currentUser = UserModel.fromJson(userData);

      // Simpan cache profil user
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserData, jsonEncode(_currentUser!.toJson()));

      return _currentUser!;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 2. Daftar Akun Pelanggan (Register)
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? address,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Field opsional tidak boleh dikirim sebagai null (Zod backend menolak null).
      final res = await ApiService.post('/api/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      });

      final token = res['token']?.toString();
      final userData = res['data'];

      if (token != null && userData != null) {
        await ApiService.setToken(token);
        ApiService.resetUnauthorized();
        _currentUser = UserModel.fromJson(userData);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUserData, jsonEncode(_currentUser!.toJson()));
        return _currentUser!;
      }

      throw Exception('Gagal mendapatkan data akun setelah pendaftaran.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 3. Ambil data profil terbaru dari server
  Future<UserModel?> fetchProfile() async {
    try {
      final res = await ApiService.get('/api/auth/profile');
      if (res['data'] != null) {
        _currentUser = UserModel.fromJson(res['data']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUserData, jsonEncode(_currentUser!.toJson()));
        notifyListeners();
        return _currentUser;
      }
    } catch (_) {}
    return null;
  }

  /// 4. Perbarui data profil
  Future<UserModel> updateProfile({
    String? name,
    String? phone,
    String? address,
  }) async {
    // Field kosong sengaja tidak dikirim. Backend memvalidasi nama minimal 2
    // karakter dan telepon minimal 8 karakter, jadi mengirim string kosong
    // akan membuat update profil gagal (400).
    final res = await ApiService.put('/api/auth/profile', {
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
    });

    if (res['data'] != null) {
      _currentUser = UserModel.fromJson(res['data']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserData, jsonEncode(_currentUser!.toJson()));
      notifyListeners();
      return _currentUser!;
    }
    throw Exception('Gagal memperbarui profil pengguna.');
  }

  /// 5. Keluar Akun (Logout)
  Future<void> logout() async {
    // Pastikan penanda 401 bersih. Kalau tidak, setelah 401 sekali saja
    // sesi berikutnya tidak pernah diarahkan ke halaman login lagi.
    ApiService.resetUnauthorized();

    try {
      // Beritahi backend supaya token lama langsung tidak berlaku
      await ApiService.post('/api/auth/logout', {});
    } catch (_) {
      // Walau server gagal, tetap logout di perangkat
    } finally {
      _currentUser = null;
      await ApiService.setToken(null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserData);
      // Keranjang ikut dikosongkan supaya akun berikutnya tidak mewarisi
      // pesanan/total milik akun yang baru logout.
      CartService().clear();
      notifyListeners();
    }
  }
}
