import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../admin/dashboard_screen.dart';
import '../user/home_screen.dart';
import 'register_screen.dart';
import 'server_config_dialog.dart';

// Kredensial demo tidak ditulis di source. Isi lewat --dart-define bila dibutuhkan,
// sehingga tidak ikut terkompilasi di APK/IPA release.
const String _demoAdminEmail = String.fromEnvironment('ADMIN_DEMO_EMAIL');
const String _demoAdminPassword = String.fromEnvironment('ADMIN_DEMO_PASSWORD');

/// Halaman Masuk Akun (Login) untuk User dan Admin
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService().login(
        _emailController.text,
        _passwordController.text,
      );

      await SocketService.connect();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang, ${user.name}!'),
          backgroundColor: AppColors.forestGreen,
        ),
      );

      // Navigasi sesuai role (User / Admin)
      if (user.isAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserHomeScreen()),
        );
      }
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
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Setup IP Server',
            icon: const Icon(Icons.settings_ethernet, color: AppColors.forestGreen),
            onPressed: () => ServerConfigDialog.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.forestGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        size: 48,
                        color: AppColors.warmCream,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DapurKita',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.forestGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pesan sayuran dan lauk matang siap santap',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 32),

                  // Form Kartu
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Masuk Akun',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'nama@email.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email wajib diisi';
                            }
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Kata Sandi',
                          hint: 'Minimal 6 karakter',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kata sandi wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        CustomButton(
                          text: 'Masuk Sekarang',
                          isLoading: _isLoading,
                          onPressed: _handleLogin,
                          icon: Icons.login,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Navigasi ke Daftar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Belum memiliki akun? ',
                        style: TextStyle(color: AppColors.charcoal, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: const Text(
                          'Daftar Akun',
                          style: TextStyle(
                            color: AppColors.forestGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tombol cepat hanya untuk pengujian (debug). Di rilis,
                  // kredensial admin tidak boleh tersedia di aplikasi.
                  if (kDebugMode && _demoAdminEmail.isNotEmpty && _demoAdminPassword.isNotEmpty)
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                        ),
                        icon: const Icon(Icons.flash_on, size: 16),
                        label: const Text('Isi Akun Admin Otomatis', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _emailController.text = _demoAdminEmail;
                          _passwordController.text = _demoAdminPassword;
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
