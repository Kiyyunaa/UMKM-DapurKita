/// Model Pengguna (User / Admin)
class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String? imageUrl;
  final String role; // 'user' atau 'admin'
  final String? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    this.imageUrl,
    required this.role,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      imageUrl: json['image_url']?.toString(),
      role: json['role']?.toString() ?? 'user',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'image_url': imageUrl,
      'role': role,
      'created_at': createdAt,
    };
  }
}
