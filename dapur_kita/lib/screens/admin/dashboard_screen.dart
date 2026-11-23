import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../auth/login_screen.dart';
import '../auth/server_config_dialog.dart';
import '../notifications_screen.dart';
import 'category_screen.dart';
import 'expense_screen.dart';
import 'order_screen.dart';
import 'product_screen.dart';
import 'user_screen.dart';

/// Halaman Dashboard Penjualan & Analitik Keuangan (Admin)
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _chartData = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _chartType = 'daily'; // 'daily' atau 'monthly'

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final analyticsFuture = ApiService.get('/api/dashboard/analytics');
      final chartFuture = ApiService.get('/api/dashboard/chart?type=$_chartType');

      final results = await Future.wait([analyticsFuture, chartFuture]);
      final analyticsData = results[0]['data'];
      final chartData = results[1]['data'] as List? ?? [];

      if (!mounted) return;
      setState(() {
        _summary = analyticsData?['summary'];
        _chartData = chartData;
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

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Akun Admin?'),
        content: const Text('Apakah Anda yakin ingin keluar dari panel admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      SocketService.disconnect();
      await AuthService().logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.dashboard, color: AppColors.forestGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'Panel Penjual DapurKita',
              style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Setup IP Server',
            icon: const Icon(Icons.settings_ethernet, color: AppColors.forestGreen),
            onPressed: () => ServerConfigDialog.show(context),
          ),
          IconButton(
            tooltip: 'Notifikasi',
            icon: const Icon(Icons.notifications_outlined, color: AppColors.charcoal),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: _handleLogout,
          ),
        ],
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
                          onPressed: _fetchDashboardData,
                          child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              color: AppColors.forestGreen,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kartu Ringkasan Utama
                    const Text(
                      'Ringkasan Keuangan UMKM',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                    ),
                    const SizedBox(height: 12),

                    // Grid Kartu Metrik
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.4,
                      children: [
                        _metricCard(
                          title: 'Omset Penjualan',
                          value: Formatters.formatRupiah(_summary?['gross_revenue'] ?? 0),
                          icon: Icons.payments_outlined,
                          color: AppColors.forestGreen,
                        ),
                        _metricCard(
                          title: 'Laba Bersih',
                          value: Formatters.formatRupiah(_summary?['net_profit'] ?? 0),
                          icon: Icons.trending_up,
                          color: AppColors.success,
                        ),
                        _metricCard(
                          title: 'Total Modal (HPP)',
                          value: Formatters.formatRupiah(_summary?['total_cogs'] ?? 0),
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.mutedOrange,
                        ),
                        _metricCard(
                          title: 'Biaya Operasional',
                          value: Formatters.formatRupiah(_summary?['total_operational_expenses'] ?? 0),
                          icon: Icons.money_off,
                          color: AppColors.error,
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, color: AppColors.forestGreen, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Pesanan: ${_summary?['total_orders'] ?? 0}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.attach_money, color: AppColors.forestGreen, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                'Laba Kotor: ${Formatters.formatRupiah(_summary?['gross_profit'] ?? 0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bagian Grafik Penjualan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Grafik Tren Penjualan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                        ),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Harian', style: TextStyle(fontSize: 11)),
                              selected: _chartType == 'daily',
                              selectedColor: AppColors.forestGreen,
                              labelStyle: TextStyle(color: _chartType == 'daily' ? Colors.white : AppColors.charcoal),
                              onSelected: (_) {
                                setState(() => _chartType = 'daily');
                                _fetchDashboardData();
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Bulanan', style: TextStyle(fontSize: 11)),
                              selected: _chartType == 'monthly',
                              selectedColor: AppColors.forestGreen,
                              labelStyle: TextStyle(color: _chartType == 'monthly' ? Colors.white : AppColors.charcoal),
                              onSelected: (_) {
                                setState(() => _chartType = 'monthly');
                                _fetchDashboardData();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Visualisasi Grafik Batang Sederhana & Ringan
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _chartData.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text('Belum ada transaksi pada periode ini.'),
                              ),
                            )
                          : Column(
                              children: [
                                // Backend mengirim data tertua -> terbaru, jadi ambil 7 terakhir.
                                ...(_chartData.length > 7
                                        ? _chartData.sublist(_chartData.length - 7)
                                        : _chartData)
                                    .map((c) {
                                  final double rev = (c['revenue'] as num?)?.toDouble() ?? 0.0;
                                  final String period = c['period']?.toString() ?? '';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            period,
                                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                        ),
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              Container(
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: AppColors.sageGreen.withOpacity(0.4),
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: rev > 0 ? (rev / 500000).clamp(0.05, 1.0) : 0.0,
                                                child: Container(
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.forestGreen,
                                                    borderRadius: BorderRadius.circular(7),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Formatters.formatRupiah(rev),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),

                    const SizedBox(height: 24),

                    // Menu Manajemen
                    const Text(
                      'Menu Manajemen Toko',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _managementCard(
                          title: 'Kelola Menu Produk',
                          subtitle: 'Tambah menu, stok, foto',
                          icon: Icons.restaurant_menu,
                          color: AppColors.forestGreen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminProductScreen()),
                            );
                          },
                        ),
                        _managementCard(
                          title: 'Kelola Pesanan',
                          subtitle: 'Status & verifikasi bayar',
                          icon: Icons.receipt_long,
                          color: AppColors.mutedOrange,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminOrderScreen()),
                            );
                          },
                        ),
                        _managementCard(
                          title: 'Kelola Kategori',
                          subtitle: 'Kategori sayur & lauk',
                          icon: Icons.category,
                          color: AppColors.info,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminCategoryScreen()),
                            );
                          },
                        ),
                        _managementCard(
                          title: 'Biaya Pengeluaran',
                          subtitle: 'Bensin, kemasan, dsb.',
                          icon: Icons.account_balance_wallet,
                          color: AppColors.error,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminExpenseScreen()),
                            );
                          },
                        ),
                        _managementCard(
                          title: 'Data Pelanggan',
                          subtitle: 'Daftar pembeli terdaftar',
                          icon: Icons.people_outline,
                          color: Colors.teal,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AdminUserScreen()),
                            );
                          },
                        ),
                        _managementCard(
                          title: 'Setup IP HP',
                          subtitle: 'Ganti alamat IP server',
                          icon: Icons.settings_ethernet,
                          color: Colors.indigo,
                          onTap: () => ServerConfigDialog.show(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _managementCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.charcoal),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
