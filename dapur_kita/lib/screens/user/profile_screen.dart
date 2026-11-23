import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../auth/login_screen.dart';
import '../auth/server_config_dialog.dart';
import '../notifications_screen.dart';

/// Halaman Profil Pelanggan & Pengaturan
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = AuthService().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _addressController.text = user.address ?? '';
    }
  }

  Future<void> _handleSave() async {
    final nama = _nameController.text.trim();
    final telepon = _phoneController.text.trim();

    // Samakan dengan aturan backend supaya tidak mengirim data yang pasti 400.
    if (nama.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama minimal 2 karakter.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (telepon.isNotEmpty && telepon.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon minimal 8 karakter, atau kosongkan.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AuthService().updateProfile(
        name: nama,
        phone: telepon,
        address: _addressController.text,
      );
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui.'),
          backgroundColor: AppColors.forestGreen,
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Akun?'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi DapurKita?'),
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
    final user = AuthService().currentUser;
    final fotoProfil = user?.imageUrl ?? '';
    final adaFoto = fotoProfil.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.charcoal),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Kartu Profil
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.forestGreen,
                    backgroundImage: adaFoto ? NetworkImage(fotoProfil) : null,
                    child: adaFoto
                        ? null
                        : Text(
                            (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.white),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Pengguna',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.sageGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user?.role.toUpperCase() ?? 'USER',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form Edit Data
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Informasi Akun',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                      ),
                      IconButton(
                        icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined, color: AppColors.forestGreen),
                        onPressed: () {
                          setState(() {
                            if (_isEditing) _loadUserData();
                            _isEditing = !_isEditing;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: _nameController,
                    label: 'Nama Lengkap',
                    readOnly: !_isEditing,
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _phoneController,
                    label: 'Nomor WhatsApp / HP',
                    readOnly: !_isEditing,
                    prefixIcon: Icons.phone_outlined,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _addressController,
                    label: 'Alamat Utama',
                    readOnly: !_isEditing,
                    maxLines: 2,
                    prefixIcon: Icons.home_outlined,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Simpan Perubahan',
                      isLoading: _isSaving,
                      onPressed: _handleSave,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Opsi Tambahan (IP Server & Logout)
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_ethernet, color: AppColors.forestGreen),
                    title: const Text('Setup Alamat IP Server'),
                    subtitle: const Text('Atur IP PC untuk koneksi HP fisik', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => ServerConfigDialog.show(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Keluar Akun', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                    onTap: _handleLogout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
