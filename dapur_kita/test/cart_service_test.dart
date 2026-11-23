import 'package:dapur_kita/models/product_model.dart';
import 'package:dapur_kita/services/cart_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('jumlah keranjang dibatasi oleh stok produk', () {
    final cart = CartService();
    cart.clear();

    final product = ProductModel(
      id: 1,
      categoryId: 1,
      name: 'Sayur Ubi',
      capitalPrice: 1000,
      sellingPrice: 2000,
      stock: 2,
      isAvailable: true,
    );

    cart.addToCart(product, quantity: 3);
    expect(cart.items.first.quantity, 2);

    cart.addToCart(product, quantity: 1);
    expect(cart.items.first.quantity, 2);

    cart.updateQuantity(product.id, 5);
    expect(cart.items.first.quantity, 2);

    cart.clear();
  });
}
