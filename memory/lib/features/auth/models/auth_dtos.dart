import 'package:memory_app/core/error_handler.dart';

String normalizeEmail(String input) => input.trim().toLowerCase();
String normalizeUsername(String input) =>
    input.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
String normalizePhone(String input) {
  final trimmed = input.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

class LoginRequestDto {
  final String identity;
  final String password;

  LoginRequestDto({required this.identity, required this.password}) {
    validate();
  }

  void validate() {
    if (identity.trim().isEmpty) {
      throw ValidationException('Username or email is required.');
    }
    if (password.isEmpty) {
      throw ValidationException('Password is required.');
    }
    if (password.length < 8) {
      throw ValidationException('Password must be at least 8 characters long.');
    }
  }

  Map<String, dynamic> toJson() {
    final cleanId = identity.trim().replaceFirst('@', '').toLowerCase();
    return {'identity': cleanId, 'password': password};
  }
}

class RegisterRequestDto {
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phone;
  final String password;
  final bool acceptedTerms;

  RegisterRequestDto({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phone,
    required this.password,
    required this.acceptedTerms,
  }) {
    validate();
  }

  void validate() {
    if (firstName.trim().isEmpty) {
      throw ValidationException('First name is required.');
    }
    if (lastName.trim().isEmpty) {
      throw ValidationException('Last name is required.');
    }

    final cleanUsername = username.trim().replaceFirst('@', '').toLowerCase();
    if (cleanUsername.isEmpty) {
      throw ValidationException('Username is required.');
    }
    if (cleanUsername.length < 3) {
      throw ValidationException('Username must be at least 3 characters.');
    }
    if (cleanUsername.length > 30) {
      throw ValidationException('Username must be 30 characters or fewer.');
    }
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(cleanUsername)) {
      throw ValidationException(
        'Username can only contain letters, numbers, periods, and underscores.',
      );
    }
    if (cleanUsername.startsWith('.') ||
        cleanUsername.endsWith('.') ||
        cleanUsername.contains('..')) {
      throw ValidationException(
        'Periods in username cannot start, end, or repeat.',
      );
    }

    if (email.trim().isEmpty) {
      throw ValidationException('Email is required.');
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email.trim())) {
      throw ValidationException('Please enter a valid email address.');
    }

    if (phone.trim().isEmpty) {
      throw ValidationException('Phone number is required.');
    }

    if (password.length < 8) {
      throw ValidationException('Password must be at least 8 characters.');
    }

    if (!acceptedTerms) {
      throw ValidationException(
        'You must accept the terms and conditions to register.',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'username': normalizeUsername(username),
      'email': normalizeEmail(email),
      'phone': normalizePhone(phone),
      'password': password,
      'accepted_terms': acceptedTerms,
    };
  }
}

class TokenDto {
  final String accessToken;
  final String refreshToken;

  TokenDto({required this.accessToken, required this.refreshToken});

  factory TokenDto.fromJson(Map<String, dynamic> json) {
    return TokenDto(
      accessToken:
          json['access_token'] as String? ??
          json['accessToken'] as String? ??
          '',
      refreshToken:
          json['refresh_token'] as String? ??
          json['refreshToken'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'access_token': accessToken, 'refresh_token': refreshToken};
  }
}

class UserDto {
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String phone;
  final String? avatarUrl;

  UserDto({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.phone,
    this.avatarUrl,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      firstName:
          json['first_name'] as String? ?? json['firstName'] as String? ?? '',
      lastName:
          json['last_name'] as String? ?? json['lastName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
    );
  }
}

class AuthResponseDto {
  final TokenDto? tokens;
  final UserDto user;
  final String message;

  AuthResponseDto({this.tokens, required this.user, required this.message});

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    final tokensJson = json['tokens'] as Map<String, dynamic>?;
    final userJson = json['user'] as Map<String, dynamic>? ?? json;

    return AuthResponseDto(
      tokens: tokensJson != null ? TokenDto.fromJson(tokensJson) : null,
      user: UserDto.fromJson(userJson),
      message: json['message'] as String? ?? '',
    );
  }
}
