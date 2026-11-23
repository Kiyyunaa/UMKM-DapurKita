import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/order_model.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_button.dart';

/// Halaman Riwayat & Status Pesanan Pelanggan
class UserOrderScreen extends StatefulWidget {
  const UserOrderScreen({super.key});

  @override
  State<UserOrderScreen> createState() => _UserOrderScreenState();
}

class _UserOrderScreenState extends State<UserOrderScreen> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchMyOrders();
    ApiService.addRealtimeListener(_onRealtime);
  }

  @override
  void dispose() {
    ApiService.removeRealtimeListener(_onRealtime);
    super.dispose();
  }

  void _onRealtime(String event) {
    if (event == 'order_status_updated') _fetchMyOrders();
  }

  Future<void> _fetchMyOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.get('/api/orders/my-orders');
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

  /// Ambil detail pesanan supaya daftar item yang tersimpan di backend ikut tampil.
  Future<void> _showOrderDetail(OrderModel awal) async {
    var order = awal;
    try {
      final res = await ApiService.get('/api/orders/${awal.id}');
      if (res['data'] != null) {
        order = OrderModel.fromJson(res['data']);
      }
    } catch (_) {
      // Kalau detail gagal dimuat, tetap tampilkan data dari daftar pesanan.
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detail ${order.orderCode}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Text('Status: ${order.statusDisplay}'),
              Text(
                'Penerima: ${order.displayRecipientName} (${order.displayRecipientPhone})',
              ),
              Text('Alamat: ${order.deliveryAddress}'),
              const SizedBox(height: 12),
              const Text('Item Pesanan:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (order.items.isEmpty)
                const Text('Item tidak tersedia.', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
              else
                ...order.items.map(
                  (it) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${it.productName} x${it.quantity}', style: const TextStyle(fontSize: 13)),
                        Text(
                          Formatters.formatRupiah(it.subtotalAmount),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    Formatters.formatRupiah(order.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Upload bukti pembayaran dengan Kamera atau Galeri (Sesuai Bagian 11 contoh.md)
  Future<void> _pickAndUploadProof(OrderModel order) async {
    if (_isUploading) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Pilih Sumber Foto Bukti Pembayaran',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.forestGreen),
              title: const Text('Ambil Foto Lewat Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _executeUpload(order, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.forestGreen),
              title: const Text('Pilih dari Galeri HP'),
              onTap: () {
                Navigator.pop(ctx);
                _executeUpload(order, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeUpload(OrderModel order, ImageSource source) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image == null) return;

      // Validasi di aplikasi supaya file yang ditolak backend tidak perlu
      // diunggah dulu (backend menerima JPG/JPEG/PNG/WEBP maksimal 5MB).
      final String namaFile = image.name.toLowerCase();
      final bool formatDiterima = namaFile.endsWith('.jpg') ||
          namaFile.endsWith('.jpeg') ||
          namaFile.endsWith('.png') ||
          namaFile.endsWith('.webp');
      if (!formatDiterima) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format gambar harus JPG, JPEG, PNG, atau WEBP.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final int ukuran = await image.length();
      if (ukuran > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ukuran gambar maksimal 5MB.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mengunggah bukti pembayaran...'),
          backgroundColor: AppColors.forestGreen,
          duration: Duration(seconds: 2),
        ),
      );

      await ApiService.uploadMultipart(
        '/api/payments/${order.id}/proof',
        fileFieldName: 'proof',
        filePath: image.path,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bukti pembayaran berhasil diunggah! Penjual akan memverifikasi.'),
          backgroundColor: AppColors.forestGreen,
        ),
      );

      await _fetchMyOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal unggah: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.info;
      case 'ready_to_deliver':
      case 'delivering':
        return AppColors.mutedOrange;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text(
          'Pesanan Saya',
          style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMyOrders,
        color: AppColors.forestGreen,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.forestGreen));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Coba Lagi',
                onPressed: _fetchMyOrders,
                isFullWidth: false,
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.sageGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, size: 60, color: AppColors.forestGreen),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Pesanan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.charcoal),
              ),
              const SizedBox(height: 6),
              const Text(
                'Riwayat pesanan sayur dan lauk Anda akan tampil di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyOrders,
      color: AppColors.forestGreen,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final order = _orders[index];
        final bool butuhBukti = order.paymentMethod == 'transfer' ||
            order.paymentMethod == 'qris' ||
            order.paymentMethod == 'dompet_digital';
        final bool canUploadProof = butuhBukti &&
            (order.proofUrl == null || order.paymentStatus != 'paid') &&
            order.status != 'cancelled' &&
            order.status != 'completed' &&
            !_isUploading;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Pesanan: Kode & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.charcoal),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.statusDisplay,
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                Formatters.formatDateTime(order.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const Divider(height: 18),

              // Alamat & Pembayaran
              Text(
                'Tujuan: ${order.deliveryAddress}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.charcoal),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Metode: ${order.paymentMethodDisplay}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  Text(
                    'Status: ${order.paymentStatusDisplay}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: order.paymentStatus == 'paid' ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Total Belanja
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(
                    Formatters.formatRupiah(order.totalAmount),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showOrderDetail(order),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('Lihat Detail Item', style: TextStyle(fontSize: 12)),
                ),
              ),

              // Tombol Upload Bukti Pembayaran jika diperlukan
              if (canUploadProof) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mutedOrange,
                      side: const BorderSide(color: AppColors.mutedOrange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(
                      order.proofUrl != null ? 'Ganti Foto Bukti Pembayaran' : 'Upload Bukti Pembayaran (Foto/Galeri)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _pickAndUploadProof(order),
                  ),
                ),
              ],
            ],
          ),
        );
        },
      ),
    );
  }
}
