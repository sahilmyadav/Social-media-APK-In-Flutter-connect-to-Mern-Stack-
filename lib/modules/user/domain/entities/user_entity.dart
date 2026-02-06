import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String? bio;
  final String? profilePicture;
  final String? coverPhoto;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool isFollowing;
  final bool isBlocked; // Checks if I blocked them
  final List<String> blockedUsers; // List of IDs I have blocked (only for current user)

  const UserEntity({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.bio,
    this.profilePicture,
    this.coverPhoto,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.isFollowing = false,
    this.isBlocked = false,
    this.blockedUsers = const [],
  });

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['_id'] ?? '',
      username: json['username'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      bio: json['bio'],
      profilePicture: json['profilePicture'] ?? json['avatar'],
      coverPhoto: json['coverPhoto'],
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      postsCount: json['postsCount'] ?? 0, // Mapped from 'totalPosts' or 'postsCount'
      isFollowing: json['isFollowing'] ?? false,
      isBlocked: json['isBlocked'] ?? false,
      blockedUsers: (json['blockedUsers'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }

  UserEntity copyWith({
    bool? isFollowing,
    int? followersCount,
    bool? isBlocked,
    List<String>? blockedUsers,
  }) {
    return UserEntity(
      id: id,
      username: username,
      firstName: firstName,
      lastName: lastName,
      bio: bio,
      profilePicture: profilePicture,
      coverPhoto: coverPhoto,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      postsCount: postsCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }

  @override
  List<Object?> get props => [id, username, isFollowing, isBlocked, followersCount, coverPhoto, blockedUsers];
}