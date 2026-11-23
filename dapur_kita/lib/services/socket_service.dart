import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';
import 'auth_service.dart';

/// Koneksi Socket.io untuk notifikasi realtime dari backend.
/// Sengaja dibuat kecil: hubungkan, gabung room, lalu teruskan event ke
/// halaman yang sedang aktif lewat ApiService.notifyRealtime().
class SocketService {
  static io.Socket? _socket;

  static Future<void> connect() async {
    if (!AuthService().isLoggedIn) return;

    final token = await ApiService.getToken();
    final user = AuthService().currentUser;
    if (token == null || token.isEmpty || user == null) return;

    disconnect();

    final baseUrl = await ApiService.getBaseUrl();
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    final socket = _socket!;

    socket.onConnect((_) {
      // Backend hanya memasukkan user ke room bila token valid.
      socket.emit('join_room', {
        'role': user.role,
        'userId': user.id,
      });
    });

    socket.on('new_order', (_) => ApiService.notifyRealtime('new_order'));
    socket.on('order_status_updated', (_) => ApiService.notifyRealtime('order_status_updated'));
    socket.on('new_product', (_) => ApiService.notifyRealtime('new_product'));

    socket.connect();
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
