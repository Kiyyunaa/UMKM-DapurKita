import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_text_field.dart';

/// Halaman Pengelolaan Kategori Makanan (Admin)
class AdminCategoryScreen extends StatefulWidget {
  const AdminCategoryScreen({super.key});

  @override
  State<AdminCategoryScreen> createState() => _AdminCategoryScreenState();
}

class _AdminCategoryScreenState extends State<AdminCategoryScreen> {
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/api/categories');
      final list = (res['data'] as List? ?? [])
          .map((c) => CategoryModel.fromJson(c))
          .toList();
      setState(() {
        _categories = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat kategori: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showCategoryDialog({CategoryModel? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            category == null ? 'Tambah Kategori Baru' : 'Ubah Kategori',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Nama Kategori',
                hint: 'Contoh: Sayur Segar, Lauk Basah',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: descController,
                label: 'Deskripsi Singkat (Opsional)',
                hint: 'Keterangan kategori...',
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: AppColors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final nama = nameController.text.trim();
                      if (nama.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nama kategori minimal 2 karakter.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        if (category == null) {
                          await ApiService.post('/api/categories', {
                            'name': nama,
                            'description': descController.text.trim(),
                          });
                        } else {
                          await ApiService.put('/api/categories/${category.id}', {
                            'name': nama,
                            'description': descController.text.trim(),
                          });
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _fetchCategories();
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text('Kategori "${category.name}" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.delete('/api/categories/${category.id}');
        _fetchCategories();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat menghapus: Kategori mungkin masih memiliki produk.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text(
          'Kelola Kategori',
          style: TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forestGreen))
          : RefreshIndicator(
              onRefresh: _fetchCategories,
              color: AppColors.forestGreen,
              child: _categories.isEmpty
                  ? const Center(child: Text('Belum ada kategori yang dibuat.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: AppColors.sageGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.category, color: AppColors.forestGreen, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    if (cat.description != null && cat.description!.isNotEmpty)
                                      Text(
                                        cat.description!,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.forestGreen, size: 20),
                                onPressed: () => _showCategoryDialog(category: cat),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                onPressed: () => _deleteCategory(cat),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.forestGreen,
        icon: const Icon(Icons.add, color: AppColors.white),
        label: const Text('Tambah Kategori', style: TextStyle(color: AppColors.white)),
        onPressed: () => _showCategoryDialog(),
      ),
    );
  }
}
