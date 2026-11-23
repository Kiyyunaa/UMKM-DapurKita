import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

/// Halaman Checkout Pemesanan (Pilih Alamat, Catatan, & Metode Pembayaran)
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedPaymentMethod = 'cod'; // 'cod', 'transfer', 'qris'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    if (user != null) {
      _addressController.text = user.address ?? '';
      _recipientNameController.text = user.name;
      _recipientPhoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateOrder() async {
    final cart = CartService();
    if (cart.items.isEmpty) return;

    final alamat = _addressController.text.trim();
    final namaPenerima = _recipientNameController.text.trim();
    final teleponPenerima = _recipientPhoneController.text.trim();

    if (namaPenerima.length < 2 || (teleponPenerima.isNotEmpty && teleponPenerima.length < 8)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama penerima minimal 2 karakter dan telepon minimal 8 karakter.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (alamat.isEmpty || alamat.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat pengiriman wajib diisi dan minimal 5 karakter.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final itemsPayload = cart.items.map((it) {
        return {
          'product_id': it.product.id,
          'quantity': it.quantity,
        };
      }).toList();

      // Backend memakai Zod: 'notes' bertipe string opsional, jadi jangan kirim null.
      final notes = _notesController.text.trim();
      final res = await ApiService.post('/api/orders', {
        'items': itemsPayload,
        'delivery_address': alamat,
        'recipient_name': namaPenerima,
        'recipient_phone': teleponPenerima,
        if (notes.isNotEmpty) 'notes': notes,
        'payment_method': _selectedPaymentMethod,
      });

      // Bersihkan keranjang setelah berhasil
      cart.clear();

      if (!mounted) return;

      final orderData = res['data'];
      final orderCode = orderData?['order_code'] ?? '';

      // Tampilkan dialog sukses
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 8),
              Text('Pesanan Dibuat!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nomor Pesanan: $orderCode'),
              const SizedBox(height: 8),
              Text(
                _selectedPaymentMethod == 'cod'
                    ? 'Pesanan Anda dengan metode Bayar di Tempat (COD) sedang diproses penjual.'
                    : 'Silakan lakukan pembayaran lalu unggah foto bukti transfer di halaman Pesanan Saya.',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: AppColors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx); // Tutup dialog
                Navigator.pop(context); // Kembali ke beranda / pesanan
              },
              child: const Text('Lihat Pesanan'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService();

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text(
          'Checkout Pesanan',
          style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ringkasan Item
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan Pesanan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 12),
                  ...cart.items.map((it) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${it.product.name} (x${it.quantity})',
                              style: const TextStyle(fontSize: 13, color: AppColors.charcoal),
                            ),
                            Text(
                              Formatters.formatRupiah(it.subtotal),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        Formatters.formatRupiah(cart.totalAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form Pengiriman
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Pengiriman',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _recipientNameController,
                    label: 'Nama Penerima',
                    hint: 'Nama orang yang menerima pesanan',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _recipientPhoneController,
                    label: 'Telepon Penerima',
                    hint: '08xxxxxxxxxx',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _addressController,
                    label: 'Alamat Lengkap Pengiriman',
                    hint: 'Contoh: Jl. Melati No. 5, RT 02/03, Bandung',
                    prefixIcon: Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _notesController,
                    label: 'Catatan untuk Penjual (Opsional)',
                    hint: 'Contoh: Jangan terlalu pedas, bungkus terpisah',
                    prefixIcon: Icons.note_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pilihan Metode Pembayaran
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Metode Pembayaran',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentRadio(
                    value: 'cod',
                    title: 'COD (Bayar di Tempat)',
                    subtitle: 'Bayar tunai langsung saat pesanan diantar kurir',
                    icon: Icons.local_shipping_outlined,
                  ),
                  const Divider(height: 1),
                  _buildPaymentRadio(
                    value: 'transfer',
                    title: 'Transfer Bank',
                    subtitle: 'BCA / Mandiri / BRI (Upload bukti transfer setelah pesan)',
                    icon: Icons.account_balance_outlined,
                  ),
                  const Divider(height: 1),
                  _buildPaymentRadio(
                    value: 'qris',
                    title: 'QRIS',
                    subtitle: 'Scan QRIS dari aplikasi GoPay, OVO, Dana, atau Mobile Banking',
                    icon: Icons.qr_code_scanner,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Pesan
            CustomButton(
              text: 'Konfirmasi & Buat Pesanan',
              isLoading: _isLoading,
              onPressed: _handleCreateOrder,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRadio({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.forestGreen : AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: AppColors.charcoal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedPaymentMethod,
              activeColor: AppColors.forestGreen,
              onChanged: (val) {
                if (val != null) setState(() => _selectedPaymentMethod = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
