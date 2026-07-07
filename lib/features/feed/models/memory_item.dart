import 'package:flutter/material.dart';

class MemoryItem {
  const MemoryItem({
    required this.id,
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
    this.reactions = const {},
  });

  /// Stable canonical identifier from the backend (UUID string).
  /// Empty string for locally-created mock items only.
  final String id;
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
  final Map<String, int> reactions;

  MemoryItem copyWith({
    String? id,
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
    Map<String, int>? reactions,
  }) {
    return MemoryItem(
      id: id ?? this.id,
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
      reactions: reactions ?? this.reactions,
    );
  }
}
