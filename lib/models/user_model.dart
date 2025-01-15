class UserModel {
  final int userId;
  final String username;
  final String namaLengkap;
  final String accessToken;
  final String role;
  final String? platNomor;
  final String? modelKendaraan;
  final int? tahunKendaraan;

  UserModel({
    required this.userId,
    required this.username,
    required this.namaLengkap,
    required this.accessToken,
    required this.role,
    this.platNomor,
    this.modelKendaraan,
    this.tahunKendaraan,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'],
      username: json['username'],
      namaLengkap: json['nama_lengkap'],
      accessToken: json['access_token'],
      role: json['role'],
      platNomor: json['plat_nomor'], // Bisa null
      modelKendaraan: json['model_kendaraan'], // Bisa null
      tahunKendaraan: json['tahun_kendaraan'], // Bisa null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'nama_lengkap': namaLengkap,
      'access_token': accessToken,
      'role': role,
      'plat_nomor': platNomor,
      'model_kendaraan': modelKendaraan,
      'tahun_kendaraan': tahunKendaraan,
    };
  }
}