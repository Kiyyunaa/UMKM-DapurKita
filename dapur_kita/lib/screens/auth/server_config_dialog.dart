import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_text_field.dart';

/// Dialog untuk mengatur dan menguji koneksi IP backend (Sangat krusial untuk setup HP fisik)
class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  final TextEditingController _urlController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  /// Terima hanya http/https dengan host. Mencegah token terkirim ke alamat
  /// yang salah ketik atau ke server yang tidak diinginkan.
  bool _isValidBaseUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _loadCurrentUrl() async {
    final current = await ApiService.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _urlController.text = current;
    });
  }

  Future<bool> _testConnection() async {
    final newUrl = _urlController.text.trim();
    if (!_isValidBaseUrl(newUrl)) {
      setState(() {
        _isSuccess = false;
        _testResult = 'Alamat harus diawali http:// atau https:// dan memiliki host.';
      });
      return false;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final oldUrl = await ApiService.getBaseUrl();
    try {
      await ApiService.setBaseUrl(newUrl);
      await ApiService.get('/api/categories');
      if (!mounted) return false;
      setState(() {
        _isTesting = false;
        _isSuccess = true;
        _testResult = 'Koneksi Berhasil! Terhubung ke backend DapurKita.';
      });
      return true;
    } catch (_) {
      // Uji gagal: kembalikan alamat lama supaya aplikasi tetap bisa dipakai.
      await ApiService.setBaseUrl(oldUrl);
      if (!mounted) return false;
      setState(() {
        _isTesting = false;
        _isSuccess = false;
        _testResult = 'Gagal terhubung. Alamat server lama dikembalikan.';
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.settings_ethernet, color: AppColors.forestGreen),
          SizedBox(width: 8),
          Text(
            'Pengaturan IP Server',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agar HP dapat mengakses backend Express.js, masukkan alamat IP PC Anda dan port 6000.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _urlController,
              label: 'Alamat Base URL',
              hint: 'http://192.168.100.43:6000',
              prefixIcon: Icons.link,
              onChanged: (_) {
                if (_testResult != null && mounted) {
                  setState(() {
                    _testResult = null;
                    _isSuccess = false;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ActionChip(
                  label: const Text('Wi-Fi PC (HP)', style: TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.sageGreen.withOpacity(0.5),
                  onPressed: () {
                    setState(() {
                      _urlController.text = ApiService.defaultPhoneIp;
                      _testResult = null;
                      _isSuccess = false;
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.sageGreen.withOpacity(0.5),
                  onPressed: () {
                    setState(() {
                      _urlController.text = ApiService.defaultEmulatorIp;
                      _testResult = null;
                      _isSuccess = false;
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Localhost', style: TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.sageGreen.withOpacity(0.5),
                  onPressed: () {
                    setState(() {
                      _urlController.text = ApiService.defaultLocalIp;
                      _testResult = null;
                      _isSuccess = false;
                    });
                  },
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isSuccess ? AppColors.sageGreen.withOpacity(0.4) : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isSuccess ? AppColors.forestGreen : AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTesting ? null : () async {
                    await _testConnection();
                  },
          child: _isTesting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Uji Koneksi', style: TextStyle(color: AppColors.forestGreen)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.forestGreen,
            foregroundColor: AppColors.white,
          ),
          onPressed: _isTesting
              ? null
              : () async {
                  // Simpan hanya setelah uji koneksi berhasil.
                  final berhasil = await _testConnection();
                  if (berhasil && context.mounted) Navigator.pop(context);
                },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
