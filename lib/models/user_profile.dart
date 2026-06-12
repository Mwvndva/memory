import 'dart:typed_data';

class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phone,
    this.avatarBytes,
    this.isAuthenticated = false,
  });

  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phone;
  final Uint8List? avatarBytes;
  final bool isAuthenticated;

  factory UserProfile.empty() {
    return const UserProfile(
      firstName: '',
      lastName: '',
      username: '',
      email: '',
      phone: '',
      isAuthenticated: false,
    );
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? phone,
    Uint8List? avatarBytes,
    bool? isAuthenticated,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
