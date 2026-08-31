import 'package:shared_preferences/shared_preferences.dart';
import 'merchant_profile.dart';
import 'dart:convert';

class MerchantProfileService {
  static const String _profileKey = 'merchant_profile';

  // Save profile to local storage
  static Future<void> saveProfile(MerchantProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = jsonEncode(profile.toJson());
      await prefs.setString(_profileKey, profileJson);
    } catch (e) {
      throw Exception('Failed to save profile: $e');
    }
  }

  // Load profile from local storage
  static Future<MerchantProfile?> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_profileKey);

      if (profileJson == null) {
        return null;
      }

      final profileMap = jsonDecode(profileJson) as Map<String, dynamic>;
      return MerchantProfile.fromJson(profileMap);
    } catch (e) {
      throw Exception('Failed to load profile: $e');
    }
  }

  // Check if profile exists
  static Future<bool> hasProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_profileKey);
    } catch (e) {
      throw Exception('Failed to check profile: $e');
    }
  }

  // Delete profile
  static Future<void> deleteProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
    } catch (e) {
      throw Exception('Failed to delete profile: $e');
    }
  }
}
