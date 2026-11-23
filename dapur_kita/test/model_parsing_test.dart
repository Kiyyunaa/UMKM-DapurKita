import 'package:dapur_kita/models/order_model.dart';
import 'package:dapur_kita/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserModel membaca image_url dari backend', () {
    final user = UserModel.fromJson({
      'id': 1,
      'name': 'Budi',
      'email': 'budi@example.com',
      'role': 'user',
      'image_url': 'https://example.com/foto.jpg',
      'created_at': '2026-01-01',
    });

    expect(user.imageUrl, 'https://example.com/foto.jpg');
    expect(user.createdAt, '2026-01-01');
  });

  test('OrderModel memberi label dompet digital', () {
    final order = OrderModel.fromJson({
      'id': 1,
      'order_code': 'ORD-1',
      'user_id': 1,
      'total_amount': 25000,
      'status': 'pending',
      'delivery_address': 'Jl. Melati No. 5',
      'payment_method': 'dompet_digital',
    });

    expect(order.paymentMethodDisplay, 'Dompet Digital');
  });
}
