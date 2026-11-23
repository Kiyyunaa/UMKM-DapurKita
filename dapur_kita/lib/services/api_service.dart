import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Layanan API terpusat untuk komunikasi Flutter dengan Express.js backend DapurKita.
class ApiService {
  static const String _keyBaseUrl = 'custom_base_url';
  static const String _keyToken = 'auth_token';

  // Token disimpan di Keychain (iOS) / Keystore (Android), bukan SharedPreferences.
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Dipanggil saat server mengembalikan 401 (token tidak valid / kedaluwarsa).
  /// Diset di main.dart agar proses logout + pindah ke halaman login dilakukan di satu tempat.
  static void Function()? onUnauthorized;
  static bool _unauthorizedHandled = false;

  /// Reset penanda 401 setelah login/register berhasil.
  static void resetUnauthorized() => _unauthorizedHandled = false;

  /// Daftar halaman yang ingin di-refresh saat ada event realtime.
  static final List<void Function(String)> _realtimeListeners = [];

  static void addRealtimeListener(void Function(String) listener) {
    if (!_realtimeListeners.contains(listener)) _realtimeListeners.add(listener);
  }

  static void removeRealtimeListener(void Function(String) listener) {
    _realtimeListeners.remove(listener);
  }

  static void notifyRealtime(String event) {
    // Salin dulu supaya listener boleh menghapus diri sendiri saat dipanggil.
    for (final listener in List<void Function(String)>.from(_realtimeListeners)) {
      listener(event);
    }
  }

  // IP bawaan PC di jaringan Wi-Fi untuk pengujian via HP fisik
  static const String defaultPhoneIp = 'http://192.168.100.43:6000';
  static const String defaultEmulatorIp = 'http://10.0.2.2:6000';
  static const String defaultLocalIp = 'http://127.0.0.1:6000';

  /// Mendapatkan Base URL saat ini
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyBaseUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }

    // Pemilihan default cerdas:
    if (kIsWeb) {
      return defaultLocalIp;
    }
    if (Platform.isAndroid) {
      // Bawaan IP Wi-Fi agar langsung terhubung saat dicoba di HP fisik
      return defaultPhoneIp;
    }
    return defaultLocalIp;
  }

  /// Mengubah Base URL (berguna saat user mengganti IP Wi-Fi di HP tanpa ubah kode)
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    var cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    await prefs.setString(_keyBaseUrl, cleanUrl);
  }

  /// Simpan Token JWT
  static Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await _secureStorage.delete(key: _keyToken);
      // Hapus juga salinan lama bila ada.
      await prefs.remove(_keyToken);
      return;
    }

    await _secureStorage.write(key: _keyToken, value: token);
    // Token lama tidak dipakai lagi, jadi dibersihkan setelah migrasi.
    await prefs.remove(_keyToken);
  }

  /// Ambil Token JWT
  static Future<String?> getToken() async {
    final token = await _secureStorage.read(key: _keyToken);
    if (token != null && token.isNotEmpty) return token;

    // Migrasi sekali untuk pengguna yang sudah login sebelum update ini.
    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString(_keyToken);
    if (oldToken != null && oldToken.isNotEmpty) {
      await setToken(oldToken);
      return oldToken;
    }
    return null;
  }

  /// Header standar dengan JWT Token jika tersedia
  static Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Format URL endpoint lengkap
  static Future<Uri> _buildUri(String endpoint) async {
    final base = await getBaseUrl();
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$base$path');
  }

  /// Handler respons HTTP seragam
  static dynamic _handleResponse(http.Response response, {String? endpoint}) {
    // Token kedaluwarsa: logout otomatis cukup sekali.
    // Endpoint login dikecualikan karena 401 di sini berarti password salah, bukan sesi habis.
    // Logout juga memakai token. Kalau token sudah kedaluwarsa, jangan panggil
    // callback 401 (nanti logout dipanggil berulang). Logout tetap membersihkan
    // token di perangkat lewat AuthService.logout().
    if (response.statusCode == 401 &&
        endpoint != null &&
        !endpoint.contains('/api/auth/login') &&
        !endpoint.contains('/api/auth/logout') &&
        !_unauthorizedHandled) {
      _unauthorizedHandled = true;
      onUnauthorized?.call();
    }

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = {'message': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String errorMsg = 'Terjadi kesalahan (${response.statusCode})';
    if (response.statusCode == 429) {
      errorMsg = 'Terlalu banyak percobaan. Silakan tunggu beberapa saat.';
    }
    if (body is Map && body['message'] != null) {
      errorMsg = body['message'].toString();
      if (body['errors'] != null && body['errors'] is List) {
        final errList = (body['errors'] as List)
            .map((e) => e is Map ? (e['message'] ?? e.toString()) : e.toString())
            .join(', ');
        if (errList.isNotEmpty) {
          errorMsg += ': $errList';
        }
      }
    }
    throw Exception(errorMsg);
  }

  // --- HTTP Methods ---

  static Future<dynamic> get(String endpoint) async {
    try {
      final uri = await _buildUri(endpoint);
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      return _handleResponse(response, endpoint: endpoint);
    } catch (e) {
      _handleNetworkError(e);
      rethrow;
    }
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = await _buildUri(endpoint);
      final headers = await _getHeaders();
      final response = await http
          .post(uri, headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response, endpoint: endpoint);
    } catch (e) {
      _handleNetworkError(e);
      rethrow;
    }
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = await _buildUri(endpoint);
      final headers = await _getHeaders();
      final response = await http
          .put(uri, headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response, endpoint: endpoint);
    } catch (e) {
      _handleNetworkError(e);
      rethrow;
    }
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = await _buildUri(endpoint);
      final headers = await _getHeaders();
      final response = await http
          .patch(uri, headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response, endpoint: endpoint);
    } catch (e) {
      _handleNetworkError(e);
      rethrow;
    }
  }

  static Future<dynamic> delete(String endpoint) async {
    try {
      final uri = await _buildUri(endpoint);
      final headers = await _getHeaders();
      final response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
      return _handleResponse(response, endpoint: endpoint);
    } catch (e) {
      _handleNetworkError(e);
      rethrow;
    }
  }

  /// Kirim data multipart form-data (Upload Foto Kamera/Galeri ke Backend -> Cloudinary)
  static Future<dynamic> uploadMultipart(
    String endpoint, {
    Map<String, String>? fields,
    String? fileFieldName,
    String? filePath,
    Uint8List? fileBytes,
    String? filename,
    String method = 'POST',
  }) async {
    try {
      final uri = await _buildUri(endpoint);
      final request = http.MultipartRequest(method, uri);

      // Tambahkan headers auth
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Tambahkan field biasa
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Tambahkan file berkas gambar jika ada
      if (fileFieldName != null) {
        if (filePath != null && filePath.isNotEmpty) {
          request.files.add(await http.MultipartFile.fromPath(fileFieldName, filePath));
        } else if (fileBytes != null && filename != null) {
          request.files.add(http.MultipartFile.fromBytes(
            fileFieldName,
            fileBytes,
            filename: filename,
          ));
        }
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response, endpoint: endpoint);
    } catch (e) {
      _handleNetworkError(e);
      rethrow;
    }
  }

  static void _handleNetworkError(dynamic error) {
    if (error is SocketException || error.toString().contains('Failed host lookup') || error.toString().contains('Connection refused')) {
      throw Exception(
        'Gagal terhubung ke backend DapurKita. Pastikan backend aktif dan HP terhubung ke Wi-Fi yang sama dengan PC.',
      );
    }
    // Timeout/ClientException tidak boleh tampil sebagai pesan teknis di layar.
    if (error is TimeoutException) {
      throw Exception('Koneksi ke backend terlalu lama. Silakan coba lagi.');
    }
    if (error.toString().contains('ClientException')) {
      throw Exception('Gagal terhubung ke backend DapurKita. Periksa alamat server dan koneksi Anda.');
    }
  }
}
