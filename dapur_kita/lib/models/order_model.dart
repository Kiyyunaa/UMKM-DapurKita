/// Model Item Pesanan
class OrderItemModel {
  final int id;
  final int orderId;
  final int productId;
  final String productName;
  final double capitalPrice;
  final double sellingPrice;
  final int quantity;
  final double subtotalAmount;
  final String? imageUrl;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.capitalPrice,
    required this.sellingPrice,
    required this.quantity,
    required this.subtotalAmount,
    this.imageUrl,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderId: int.tryParse(json['order_id']?.toString() ?? '0') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      productName: json['product_name']?.toString() ?? '',
      capitalPrice: double.tryParse(json['capital_price']?.toString() ?? '0') ?? 0.0,
      sellingPrice: double.tryParse(json['selling_price']?.toString() ?? '0') ?? 0.0,
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      subtotalAmount: double.tryParse(json['subtotal_amount']?.toString() ?? '0') ?? 0.0,
      imageUrl: json['image_url']?.toString(),
    );
  }
}

/// Model Pesanan (Order)
class OrderModel {
  final int id;
  final String orderCode;
  final int userId;
  final String? userName;
  final String? userPhone;
  final String? recipientName;
  final String? recipientPhone;
  final double totalAmount;
  final double totalCapital;
  final String status; // pending, processing, ready_to_deliver, delivering, completed, cancelled
  final String deliveryAddress;
  final String? notes;
  final String paymentMethod; // cod, transfer, qris
  final String? paymentStatus; // unpaid, paid, failed
  final String? proofUrl;
  final String? createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.orderCode,
    required this.userId,
    this.userName,
    this.userPhone,
    this.recipientName,
    this.recipientPhone,
    required this.totalAmount,
    this.totalCapital = 0.0,
    required this.status,
    required this.deliveryAddress,
    this.notes,
    required this.paymentMethod,
    this.paymentStatus,
    this.proofUrl,
    this.createdAt,
    this.items = const [],
  });

  /// Data lama mungkin belum punya nama penerima, jadi jatuh ke data akun.
  String get displayRecipientName =>
      (recipientName ?? '').isNotEmpty ? recipientName! : (userName ?? '-');

  String get displayRecipientPhone =>
      (recipientPhone ?? '').isNotEmpty ? recipientPhone! : (userPhone ?? '-');

  /// Label status yang ramah dibaca pengguna
  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'processing':
        return 'Sedang Diproses';
      case 'ready_to_deliver':
        return 'Siap Dikirim';
      case 'delivering':
        return 'Dalam Pengiriman';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  /// Label metode pembayaran
  String get paymentMethodDisplay {
    switch (paymentMethod.toLowerCase()) {
      case 'cod':
        return 'Bayar di Tempat (COD)';
      case 'transfer':
        return 'Transfer Bank';
      case 'qris':
        return 'QRIS';
      case 'dompet_digital':
        return 'Dompet Digital';
      default:
        return paymentMethod;
    }
  }

  /// Label status pembayaran
  String get paymentStatusDisplay {
    switch ((paymentStatus ?? 'unpaid').toLowerCase()) {
      case 'paid':
        return 'Sudah Dibayar';
      case 'failed':
        return 'Gagal';
      case 'unpaid':
      default:
        return 'Belum Dibayar';
    }
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<OrderItemModel> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => OrderItemModel.fromJson(i))
          .toList();
    }

    return OrderModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      orderCode: json['order_code']?.toString() ?? 'ORD-${json['id']}',
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      userName: json['user_name']?.toString(),
      userPhone: json['user_phone']?.toString(),
      recipientName: json['recipient_name']?.toString(),
      recipientPhone: json['recipient_phone']?.toString(),
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      totalCapital: double.tryParse(json['total_capital']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'pending',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      notes: json['notes']?.toString(),
      paymentMethod: json['payment_method']?.toString() ?? 'cod',
      paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
      proofUrl: json['proof_url']?.toString(),
      createdAt: json['created_at']?.toString(),
      items: parsedItems,
    );
  }
}
