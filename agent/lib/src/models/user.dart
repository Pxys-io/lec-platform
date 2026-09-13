class User {
  final String id;
  final String email;
  final String phone;
  final String role;
  final String firstName;
  final String lastName;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    this.phone = '',
    required this.role,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      phone: json['phone'] ?? '',
      role: json['role'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'avatar_url': avatarUrl,
    };
  }
}
