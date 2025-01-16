class UserModel {
  final String accessToken;
  final String namaLengkap;
  final String role;

  UserModel({
    required this.accessToken,
    required this.namaLengkap,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      accessToken: json['access_token'],
      namaLengkap: json['nama_lengkap'],
      role: json['role'],
    );
  }
}