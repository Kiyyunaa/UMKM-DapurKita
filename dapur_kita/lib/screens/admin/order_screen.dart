import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';

/// Halaman Kelola Pesanan & Verifikasi Pembayaran Pelanggan (Admin)
class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    ApiService.addRealtimeListener(_onRealtime);
  }

  @override
  void dispose() {
    ApiService.removeRealtimeListener(_onRealtime);
    super.dispose();
  }

  void _onRealtime(String event) {
    if (event == 'new_order' || event == 'order_status_updated') {
      _fetchOrders();
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ApiService.get('/api/orders');
      final list = (res['data'] as List? ?? [])
          .map((item) => OrderModel.fromJson(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _orders = list;
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

  Future<void> _updateStatus(int orderId, String newStatus) async {
    try {
      await ApiService.patch('/api/orders/$orderId/status', {'status': newStatus});
      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal perbarui status: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _updatePaymentStatus(int orderId, String newPaymentStatus) async {
    try {
      await ApiService.patch('/api/payments/$orderId/status', {'payment_status': newPaymentStatus});
      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal verifikasi pembayaran: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  /// Ikuti aturan backend: status tidak boleh mundur, pesanan selesai tidak
  /// bisa dibatalkan, dan pesanan yang sudah dibatalkan tidak diubah lagi.
  bool _statusAllowed(String current, String next) {
    const urutan = {
      'pending': 1,
      'processing': 2,
      'ready_to_deliver': 3,
      'delivering': 4,
      'completed': 5,
    };

    if (current == 'cancelled') return false;
    if (next == 'cancelled') return (urutan[current] ?? 0) <= 3;
    return (urutan[next] ?? 0) >= (urutan[current] ?? 0);
  }

  Future<void> _confirmPaymentStatus(
    BuildContext ctx,
    OrderModel order,
    String status,
  ) async {
    final label = status == 'paid' ? 'Tandai Lunas' : 'Tolak Pembayaran';
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text('$label?'),
        content: Text(
          'Pesanan ${order.orderCode} akan ditandai ${status == 'paid' ? 'lunas' : 'gagal'}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'paid' ? AppColors.success : AppColors.error,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _updatePaymentStatus(order.id, status);
    if (ctx.mounted) Navigator.pop(ctx);
  }

  Future<void> _showOrderDetail(OrderModel awal) async {
    // Daftar pesanan tidak membawa item, jadi ambil detailnya dari backend.
    var order = awal;
    try {
      final res = await ApiService.get('/api/orders/${awal.id}');
      if (res['data'] != null) {
        order = OrderModel.fromJson(res['data']);
      }
    } catch (_) {
      // Tetap pakai data dari daftar kalau detail gagal dimuat.
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pesanan ${order.orderCode}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  Text(
                    'Penerima: ${order.displayRecipientName} (${order.displayRecipientPhone})',
                  ),
                  const SizedBox(height: 4),
                  Text('Alamat Antar: ${order.deliveryAddress}'),
                  if (order.notes != null && order.notes!.isNotEmpty)
                    Text('Catatan: ${order.notes}', style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 12),

                  const Text('Item Pesanan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (order.items.isEmpty)
                    const Text('Item tidak tersedia.', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
                  else
                    ...order.items.map(
                      (it) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${it.productName} x${it.quantity}', style: const TextStyle(fontSize: 12)),
                            Text(
                              Formatters.formatRupiah(it.subtotalAmount),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  const Text('Ubah Status Pesanan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _statusButton(
                        ctx, order.id, 'pending', 'Tertunda', order.status == 'pending',
                        isAllowed: _statusAllowed(order.status, 'pending'),
                      ),
                      _statusButton(
                        ctx, order.id, 'processing', 'Diproses', order.status == 'processing',
                        isAllowed: _statusAllowed(order.status, 'processing'),
                      ),
                      _statusButton(
                        ctx, order.id, 'ready_to_deliver', 'Siap', order.status == 'ready_to_deliver',
                        isAllowed: _statusAllowed(order.status, 'ready_to_deliver'),
                      ),
                      _statusButton(
                        ctx, order.id, 'delivering', 'Dikirim', order.status == 'delivering',
                        isAllowed: _statusAllowed(order.status, 'delivering'),
                      ),
                      _statusButton(
                        ctx, order.id, 'completed', 'Selesai', order.status == 'completed',
                        isAllowed: _statusAllowed(order.status, 'completed'),
                      ),
                      _statusButton(
                        ctx, order.id, 'cancelled', 'Batalkan', order.status == 'cancelled',
                        isAllowed: _statusAllowed(order.status, 'cancelled'), isDanger: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bagian Bukti & Status Pembayaran
                  const Text('Verifikasi Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Metode: ${order.paymentMethodDisplay} • Status: ${order.paymentStatusDisplay}'),
                  const SizedBox(height: 8),

                  if (order.proofUrl != null && order.proofUrl!.isNotEmpty) ...[
                    const Text('Bukti Transfer yang Diunggah Pelanggan:', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        order.proofUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Text('Gagal memuat gambar bukti transfer.'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
                          onPressed: () => _confirmPaymentStatus(ctx, order, 'paid'),
                          child: const Text('Tandai Lunas (Paid)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          onPressed: () => _confirmPaymentStatus(ctx, order, 'failed'),
                          child: const Text('Tolak / Gagal'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusButton(
    BuildContext ctx,
    int orderId,
    String statusKey,
    String label,
    bool isSelected, {
    bool isDanger = false,
    bool isAllowed = true,
  }) {
    // Chip yang tidak diizinkan sengaja dinonaktifkan agar admin tidak
    // mengirim status yang akan ditolak backend (400).
    final bool aktif = isAllowed && !isSelected;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: isDanger ? AppColors.error : AppColors.forestGreen,
      labelStyle: TextStyle(
        color: !aktif && !isSelected
            ? AppColors.textMuted
            : (isSelected ? Colors.white : (isDanger ? AppColors.error : AppColors.charcoal)),
        fontSize: 11,
      ),
      onSelected: aktif
          ? (_) {
              Navigator.pop(ctx);
              _updateStatus(orderId, statusKey);
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _selectedStatusFilter == 'all'
        ? _orders
        : _orders.where((o) => o.status.toLowerCase() == _selectedStatusFilter).toList();

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text(
          'Kelola Pesanan Masuk',
          style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            height: 48,
            color: AppColors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _buildFilterChip('all', 'Semua'),
                _buildFilterChip('pending', 'Menunggu'),
                _buildFilterChip('processing', 'Diproses'),
                _buildFilterChip('ready_to_deliver', 'Siap'),
                _buildFilterChip('delivering', 'Dikirim'),
                _buildFilterChip('completed', 'Selesai'),
                _buildFilterChip('cancelled', 'Batal'),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
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
                                onPressed: _fetchOrders,
                                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                    onRefresh: _fetchOrders,
                    color: AppColors.forestGreen,
                    child: filteredOrders.isEmpty
                        ? const Center(child: Text('Tidak ada pesanan dalam status ini.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredOrders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              return InkWell(
                                onTap: () async {
                                  await _showOrderDetail(order);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            order.orderCode,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.sageGreen,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              order.statusDisplay,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Pemesan: ${order.userName ?? "Pelanggan"} • ${order.userPhone ?? ""}'),
                                      Text('Metode: ${order.paymentMethodDisplay} • Status: ${order.paymentStatusDisplay}'),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            Formatters.formatDateTime(order.createdAt),
                                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                          Text(
                                            Formatters.formatRupiah(order.totalAmount),
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedStatusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.charcoal)),
        selected: isSelected,
        selectedColor: AppColors.forestGreen,
        backgroundColor: AppColors.warmCream,
        onSelected: (_) => setState(() => _selectedStatusFilter = key),
      ),
    );
  }
}
