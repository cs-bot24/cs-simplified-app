class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        fullName: json['full_name'],
        email: json['email'],
        role: json['role'],
        isActive: json['is_active'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'role': role,
        'is_active': isActive,
      };
}
