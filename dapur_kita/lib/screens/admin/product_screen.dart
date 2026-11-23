import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

/// Halaman Pengelolaan Menu / Produk (Admin)
class AdminProductScreen extends StatefulWidget {
  const AdminProductScreen({super.key});

  @override
  State<AdminProductScreen> createState() => _AdminProductScreenState();
}

class _AdminProductScreenState extends State<AdminProductScreen> {
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final resCategories = await ApiService.get('/api/categories');
      final resProducts = await ApiService.get('/api/products');

      if (!mounted) return;
      setState(() {
        _categories = (resCategories['data'] as List? ?? [])
            .map((c) => CategoryModel.fromJson(c))
            .toList();
        _products = (resProducts['data'] as List? ?? [])
            .map((p) => ProductModel.fromJson(p))
            .toList();
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

  /// Dialog Form Tambah / Edit Produk dengan Dukungan Kamera & Galeri (Bagian 11 contoh.md)
  void _openProductForm({ProductModel? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final descController = TextEditingController(text: product?.description ?? '');
    final capitalController = TextEditingController(
      text: product != null ? product.capitalPrice.toInt().toString() : '',
    );
    final sellingController = TextEditingController(
      text: product != null ? product.sellingPrice.toInt().toString() : '',
    );
    final stockController = TextEditingController(
      text: product != null ? product.stock.toString() : '10',
    );

    int? selectedCategory = product?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : null);
    bool isAvailable = product?.isAvailable ?? true;
    XFile? pickedImage;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final ImagePicker picker = ImagePicker();

          Future<void> pickImage(ImageSource source) async {
            final XFile? img = await picker.pickImage(source: source, imageQuality: 80);
            if (img != null) {
              setModalState(() => pickedImage = img);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product == null ? 'Tambah Menu Produk Baru' : 'Edit Menu Produk',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Area Foto Produk (Kamera / Galeri)
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppColors.sageGreen.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: pickedImage != null
                              ? Image.file(File(pickedImage!.path), fit: BoxFit.cover)
                              : product?.imageUrl != null && product!.imageUrl!.isNotEmpty
                                  ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                                  : const Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.forestGreen),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.forestGreen),
                              ),
                              icon: const Icon(Icons.camera_alt, size: 16, color: AppColors.forestGreen),
                              label: const Text('Kamera', style: TextStyle(fontSize: 12, color: AppColors.forestGreen)),
                              onPressed: () => pickImage(ImageSource.camera),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.forestGreen),
                              ),
                              icon: const Icon(Icons.photo_library, size: 16, color: AppColors.forestGreen),
                              label: const Text('Galeri', style: TextStyle(fontSize: 12, color: AppColors.forestGreen)),
                              onPressed: () => pickImage(ImageSource.gallery),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Kategori Dropdown
                  const Text('Kategori Menu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 12),

                  CustomTextField(
                    controller: nameController,
                    label: 'Nama Produk / Menu',
                    hint: 'Contoh: Sayur Bayam Matang, Ayam Goreng Lengkuas',
                  ),
                  const SizedBox(height: 12),

                  CustomTextField(
                    controller: descController,
                    label: 'Deskripsi Produk',
                    hint: 'Porsi, bahan, atau rasa...',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Harga Modal & Harga Jual
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: capitalController,
                          label: 'Harga Modal (HPP)',
                          hint: 'Contoh: 5000',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          controller: sellingController,
                          label: 'Harga Jual',
                          hint: 'Contoh: 8000',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stok & Ketersediaan
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: stockController,
                          label: 'Jumlah Stok',
                          hint: 'Contoh: 25',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tersedia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Switch(
                            value: isAvailable,
                            activeColor: AppColors.forestGreen,
                            onChanged: (val) => setModalState(() => isAvailable = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tombol Simpan
                  CustomButton(
                    text: product == null ? 'Tambah Menu Sekarang' : 'Simpan Perubahan',
                    isLoading: isSaving,
                    onPressed: () async {
                      final nama = nameController.text.trim();
                      final modal = double.tryParse(capitalController.text.trim());
                      final jual = double.tryParse(sellingController.text.trim());
                      final stok = int.tryParse(stockController.text.trim().isEmpty
                          ? '0'
                          : stockController.text.trim());

                      if (nama.length < 2 ||
                          selectedCategory == null ||
                          modal == null ||
                          jual == null ||
                          stok == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lengkapi nama (min. 2), kategori, modal, harga jual, dan stok berupa angka.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);
                      try {
                        final fields = {
                          'category_id': selectedCategory.toString(),
                          'name': nameController.text.trim(),
                          'description': descController.text.trim(),
                          'capital_price': capitalController.text.trim(),
                          'selling_price': sellingController.text.trim(),
                          'stock': stockController.text.trim().isNotEmpty ? stockController.text.trim() : '0',
                          'is_available': isAvailable ? 'true' : 'false',
                        };

                        if (product == null) {
                          // Create
                          await ApiService.uploadMultipart(
                            '/api/products',
                            fields: fields,
                            fileFieldName: pickedImage != null ? 'image' : null,
                            filePath: pickedImage?.path,
                          );
                        } else {
                          // Update
                          await ApiService.uploadMultipart(
                            '/api/products/${product.id}',
                            method: 'PUT',
                            fields: fields,
                            fileFieldName: pickedImage != null ? 'image' : null,
                            filePath: pickedImage?.path,
                          );
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadData();
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setModalState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('Hapus produk "${product.name}"?'),
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
        await ApiService.delete('/api/products/${product.id}');
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus produk: ${e.toString().replaceAll('Exception: ', '')}'),
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
          'Kelola Menu & Stok',
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
                          onPressed: _loadData,
                          child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.forestGreen,
              child: _products.isEmpty
                  ? const Center(child: Text('Belum ada menu produk.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  color: AppColors.sageGreen.withOpacity(0.3),
                                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          product.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: AppColors.forestGreen),
                                        )
                                      : const Icon(Icons.restaurant, color: AppColors.forestGreen),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Jual: ${Formatters.formatRupiah(product.sellingPrice)} (Modal: ${Formatters.formatRupiah(product.capitalPrice)})',
                                      style: const TextStyle(fontSize: 12, color: AppColors.forestGreen),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Stok: ${product.stock} • ${product.isAvailable ? "Tersedia" : "Nonaktif"}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: product.stock <= 5 ? AppColors.warning : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.forestGreen, size: 20),
                                onPressed: () => _openProductForm(product: product),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                onPressed: () => _deleteProduct(product),
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
        label: const Text('Tambah Menu', style: TextStyle(color: AppColors.white)),
        onPressed: () => _openProductForm(),
      ),
    );
  }
}
