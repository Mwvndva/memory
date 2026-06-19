import 'dart:typed_data';

class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phone,
    this.avatarBytes,
    this.avatarUrl,
    this.isAuthenticated = false,
    this.streakDays = 0,
    this.circlePulseDays = 0,
    this.countryRank = 1,
    this.globalRank,
  });

  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phone;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final bool isAuthenticated;
  final int streakDays;
  final int circlePulseDays;
  final int countryRank;
  final int? globalRank;

  factory UserProfile.empty() {
    return const UserProfile(
      firstName: '',
      lastName: '',
      username: '',
      email: '',
      phone: '',
      isAuthenticated: false,
      streakDays: 0,
      circlePulseDays: 0,
      countryRank: 1,
      globalRank: null,
      avatarUrl: null,
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
    int? streakDays,
    int? circlePulseDays,
    int? countryRank,
    int? globalRank,
    String? avatarUrl,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      streakDays: streakDays ?? this.streakDays,
      circlePulseDays: circlePulseDays ?? this.circlePulseDays,
      countryRank: countryRank ?? this.countryRank,
      globalRank: globalRank ?? this.globalRank,
    );
  }
}
