import 'package:supabase_flutter/supabase_flutter.dart';

class UserModel {
  final String id;
  final String? email;
  final String? username;
  final String? name;
  final String? avatarUrl;
  final String? bio;
  final List<String>? professions;

  UserModel({
    required this.id,
    this.email,
    this.username,
    this.name,
    this.avatarUrl,
    this.bio,
    this.professions,
  });

  // Create from Supabase auth User
  factory UserModel.fromAuthUser(User user) {
    return UserModel(
      id: user.id,
      email: user.email,
    );
  }

  // Create from profile data
  factory UserModel.fromProfile(Map<String, dynamic> profile) {
    return UserModel(
      id: profile['user_id'] ?? '',
      username: profile['username'],
      name: profile['name'],
      avatarUrl: profile['avatar_url'],
      bio: profile['bio'],
      professions: profile['professions'] != null 
          ? List<String>.from(profile['professions'])
          : null,
    );
  }
}