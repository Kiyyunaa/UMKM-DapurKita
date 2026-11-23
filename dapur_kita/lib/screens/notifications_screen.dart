import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import 'admin/dashboard_screen.dart';
import 'user/home_screen.dart';

/// Halaman Notifikasi untuk User & Admin
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isMarkingRead = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    ApiService.addRealtimeListener(_onRealtime);
  }

  @override
  void dispose() {
    ApiService.removeRealtimeListener(_onRealtime);
    super.dispose();
  }

  void _onRealtime(String event) {
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ApiService.get('/api/notifications');
      final list = (res['data'] as List? ?? [])
          .map((item) => NotificationModel.fromJson(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _markRead(NotificationModel notif) async {
    if (notif.isRead || _isMarkingRead) return;

    setState(() => _isMarkingRead = true);
    try {
      await ApiService.patch('/api/notifications/${notif.id}/read', {});
      await _fetchNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menandai notifikasi: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMarkingRead = false);
    }
  }

  Future<void> _handleTap(NotificationModel notif) async {
    await _markRead(notif);
    if (notif.orderId == null || !mounted) return;

    // Notifikasi bertaut pesanan langsung membuka halaman pesanan yang sesuai peran.
    final Widget tujuan = AuthService().isAdmin
        ? const AdminDashboardScreen()
        : const UserHomeScreen(initialIndex: 2);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => tujuan),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forestGreen))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.forestGreen),
                          onPressed: _fetchNotifications,
                          child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _notifications.isEmpty
              ? const Center(
                  child: Text('Belum ada notifikasi baru.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    return InkWell(
                      onTap: () async {
                        await _handleTap(n);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n.isRead ? AppColors.white : AppColors.sageGreen.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: n.isRead ? AppColors.border : AppColors.forestGreen.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              n.isRead ? Icons.notifications_none : Icons.notifications_active,
                              color: AppColors.forestGreen,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.charcoal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.message,
                                    style: const TextStyle(fontSize: 13, color: AppColors.charcoal),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    Formatters.formatDateTime(n.createdAt),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
