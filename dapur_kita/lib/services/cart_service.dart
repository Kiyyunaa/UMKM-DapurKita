import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

/// Layanan Pengelola Keranjang Belanja Pelanggan
class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItemModel> _items = [];

  List<CartItemModel> get items => List.unmodifiable(_items);

  /// Total kuantitas barang di keranjang (untuk angka badge)
  int get totalItemCount {
    int total = 0;
    for (var item in _items) {
      total += item.quantity;
    }
    return total;
  }

  /// Total harga belanjaan di keranjang
  double get totalAmount {
    double total = 0.0;
    for (var item in _items) {
      total += item.subtotal;
    }
    return total;
  }

  /// Tambah produk ke keranjang. Total jumlah untuk produk yang sama tidak
  /// boleh melebihi stok, walaupun user menambah dari katalog/detail berkali-kali.
  void addToCart(ProductModel product, {int quantity = 1}) {
    if (quantity <= 0 || product.stock <= 0) return;

    final index = _items.indexWhere((it) => it.product.id == product.id);
    final jumlahSekarang = index >= 0 ? _items[index].quantity : 0;
    var jumlahBaru = jumlahSekarang + quantity;
    if (jumlahBaru > product.stock) jumlahBaru = product.stock;
    if (jumlahBaru == jumlahSekarang) return;

    if (index >= 0) {
      _items[index].quantity = jumlahBaru;
    } else {
      _items.add(CartItemModel(product: product, quantity: jumlahBaru));
    }
    notifyListeners();
  }

  /// Perbarui kuantitas produk tertentu, tetap dibatasi stok.
  void updateQuantity(int productId, int delta) {
    final index = _items.indexWhere((it) => it.product.id == productId);
    if (index >= 0) {
      final stok = _items[index].product.stock;
      var jumlahBaru = _items[index].quantity + delta;
      if (jumlahBaru > stok) jumlahBaru = stok;
      _items[index].quantity = jumlahBaru;
      if (_items[index].quantity <= 0) {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// Hapus produk dari keranjang
  void removeItem(int productId) {
    _items.removeWhere((it) => it.product.id == productId);
    notifyListeners();
  }

  /// Bersihkan keranjang belanja
  void clear() {
    _items.clear();
    notifyListeners();
  }
}
