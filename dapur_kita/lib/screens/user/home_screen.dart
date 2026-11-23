import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/product_card.dart';
import '../notifications_screen.dart';
import 'cart_screen.dart';
import 'order_screen.dart';
import 'product_detail_screen.dart';
import 'profile_screen.dart';

/// Halaman Beranda Utama Pelanggan (Katalog Menu, Keranjang, Pesanan, Profil)
class UserHomeScreen extends StatefulWidget {
  /// Dipakai notifikasi untuk langsung membuka tab Pesanan.
  final int initialIndex;

  const UserHomeScreen({super.key, this.initialIndex = 0});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;

  // State untuk Tab Katalog
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Supaya ikon "hapus" langsung muncul saat user mengetik, bukan setelah submit.
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    ApiService.addRealtimeListener(_onRealtime);
    _fetchCatalog();
  }

  void _onRealtime(String event) {
    if (event == 'new_product') _fetchCatalog();
  }

  @override
  void dispose() {
    ApiService.removeRealtimeListener(_onRealtime);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ambil kategori & produk secara bersamaan
      final catFuture = ApiService.get('/api/categories');

      String prodUrl = '/api/products';
      List<String> queryParams = [];
      if (_selectedCategoryId != null) {
        queryParams.add('category_id=$_selectedCategoryId');
      }
      if (_searchQuery.trim().isNotEmpty) {
        queryParams.add('search=${Uri.encodeComponent(_searchQuery.trim())}');
      }
      if (queryParams.isNotEmpty) {
        prodUrl += '?${queryParams.join('&')}';
      }

      final prodFuture = ApiService.get(prodUrl);

      final results = await Future.wait([catFuture, prodFuture]);
      final catData = results[0]['data'] as List? ?? [];
      final prodData = results[1]['data'] as List? ?? [];

      if (!mounted) return;
      setState(() {
        _categories = catData.map((c) => CategoryModel.fromJson(c)).toList();
        _products = prodData.map((p) => ProductModel.fromJson(p)).toList();
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

  void _onCategorySelected(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _fetchCatalog();
  }

  void _onSearchSubmitted(String query) {
    setState(() {
      _searchQuery = query;
    });
    _fetchCatalog();
  }

  Widget _buildCatalogTab() {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchCatalog,
          color: AppColors.forestGreen,
          child: CustomScrollView(
            slivers: [
              // Header Aplikasi & Salam Pelanggan
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Halo, ${user?.name ?? "Pelanggan"}!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Mau masak apa hari ini?',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: AppColors.forestGreen),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearchSubmitted,
                      decoration: InputDecoration(
                        hintText: 'Cari sayuran atau lauk favorit...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.forestGreen, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchSubmitted('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Kategori (Horizontal Chips)
              SliverToBoxAdapter(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: const Text('Semua'),
                          selected: _selectedCategoryId == null,
                          selectedColor: AppColors.forestGreen,
                          labelStyle: TextStyle(
                            color: _selectedCategoryId == null ? AppColors.white : AppColors.charcoal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: AppColors.white,
                          onSelected: (_) => _onCategorySelected(null),
                        ),
                      ),
                      ..._categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat.name),
                            selected: isSelected,
                            selectedColor: AppColors.forestGreen,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.white : AppColors.charcoal,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: AppColors.white,
                            onSelected: (_) => _onCategorySelected(cat.id),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Judul Bagian Menu
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Pilihan Menu Siap Santap',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ),

              // Grid Produk
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.forestGreen)),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Center(
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
                            onPressed: _fetchCatalog,
                            child: const Text('Muat Ulang', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_products.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Tidak ada menu yang sesuai kriteria.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = _products[index];
                        return ProductCard(
                          product: product,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(product: product),
                              ),
                            ).then((_) => _fetchCatalog());
                          },
                          onAddToCart: () {
                            CartService().addToCart(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} dimasukkan ke keranjang.'),
                                backgroundColor: AppColors.forestGreen,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _products.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildCatalogTab(),
          CartScreen(onBrowseProducts: () => setState(() => _currentIndex = 0)),
          const UserOrderScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: CartService(),
        builder: (context, child) {
          final cartCount = CartService().totalItemCount;

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: AppColors.forestGreen,
            unselectedItemColor: AppColors.textMuted,
            backgroundColor: AppColors.white,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.restaurant_menu),
                label: 'Menu',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: cartCount > 0,
                  label: Text('$cartCount'),
                  backgroundColor: AppColors.mutedOrange,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                label: 'Keranjang',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Pesanan',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profil',
              ),
            ],
          );
        },
      ),
    );
  }
}
