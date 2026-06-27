import 'package:flutter/material.dart';

class MemoryItem {
  const MemoryItem({
    required this.person,
    required this.username,
    required this.initial,
    required this.time,
    required this.caption,
    required this.avatar,
    required this.colors,
    required this.ageHours,
    this.videoPath,
    this.avatarUrl,
  });

  final String person;
  final String username;
  final String initial;
  final String time;
  final String caption;
  final Color avatar;
  final List<Color> colors;
  final double ageHours;
  final String? videoPath;
  final String? avatarUrl;

  MemoryItem copyWith({
    String? person,
    String? username,
    String? initial,
    String? time,
    String? caption,
    Color? avatar,
    List<Color>? colors,
    double? ageHours,
    String? videoPath,
    String? avatarUrl,
  }) {
    return MemoryItem(
      person: person ?? this.person,
      username: username ?? this.username,
      initial: initial ?? this.initial,
      time: time ?? this.time,
      caption: caption ?? this.caption,
      avatar: avatar ?? this.avatar,
      colors: colors ?? this.colors,
      ageHours: ageHours ?? this.ageHours,
      videoPath: videoPath ?? this.videoPath,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
