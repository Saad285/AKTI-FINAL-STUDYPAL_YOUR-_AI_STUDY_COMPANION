class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
  });

  // 1. To Map (Saving to DB)
  Map<String, dynamic> toMap() {
    return {'uid': uid, 'email': email, 'name': name, 'role': role};
  }

  // 2. From Map (Reading from DB)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? 'User', // ✅ Reading Name (Default 'User')
      role: map['role'] ?? 'Student',
    );
  }
}
