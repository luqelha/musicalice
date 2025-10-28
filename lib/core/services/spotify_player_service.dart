import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'spotify_auth_service.dart';

class SpotifyPlayerService {
  final SpotifyAuthService _authService;

  SpotifyPlayerService([SpotifyAuthService? authService])
    : _authService = authService ?? SpotifyAuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getValidToken();
    if (token == null) throw Exception('No valid token');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // === Get Available Devices ===
  Future<List<Map<String, dynamic>>> getDevices() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/player/devices'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['devices'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // === Play Track on Active Device ===
  Future<bool> playTrack(String trackUri, {String? deviceId}) async {
    try {
      final headers = await _getHeaders();

      // Cari device aktif jika tidak dispesifikkan
      if (deviceId == null) {
        final devices = await getDevices();
        if (devices.isEmpty) {
          if (kDebugMode) print('❌ No active Spotify devices found');
          return false;
        }
        // Gunakan device pertama yang aktif atau device pertama
        final activeDevice = devices.firstWhere(
          (d) => d['is_active'] == true,
          orElse: () => devices.first,
        );
        deviceId = activeDevice['id'];
      }

      final url = deviceId != null
          ? 'https://api.spotify.com/v1/me/player/play?device_id=$deviceId'
          : 'https://api.spotify.com/v1/me/player/play';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'uris': [trackUri],
        }),
      );

      if (kDebugMode) {
        print('🎵 Play Status: ${response.statusCode}');
        if (response.statusCode != 204) {
          print('❌ Error: ${response.body}');
        }
      }

      return response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('❌ Error playing track: $e');
      return false;
    }
  }

  // === Pause Playback ===
  Future<bool> pause() async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/pause'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('❌ Error pausing: $e');
      return false;
    }
  }

  // === Resume Playback ===
  Future<bool> resume() async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/play'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('❌ Error resuming: $e');
      return false;
    }
  }

  // === Skip to Next ===
  Future<bool> skipNext() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('https://api.spotify.com/v1/me/player/next'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('❌ Error skipping: $e');
      return false;
    }
  }

  // === Skip to Previous ===
  Future<bool> skipPrevious() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('https://api.spotify.com/v1/me/player/previous'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('❌ Error going back: $e');
      return false;
    }
  }

  // === Seek to Position ===
  Future<bool> seek(int positionMs) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(
          'https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs',
        ),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('❌ Error seeking: $e');
      return false;
    }
  }

  // === Set Volume ===
  Future<bool> setVolume(int volumePercent) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(
          'https://api.spotify.com/v1/me/player/volume?volume_percent=$volumePercent',
        ),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('❌ Error setting volume: $e');
      return false;
    }
  }

  // === Get Current Playback State ===
  Future<Map<String, dynamic>?> getCurrentPlayback() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 204) {
        // No active playback
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error getting playback: $e');
    }
    return null;
  }

  // === Toggle Shuffle ===
  Future<bool> setShuffle(bool state) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/shuffle?state=$state'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('❌ Error setting shuffle: $e');
      return false;
    }
  }

  // === Set Repeat Mode ===
  Future<bool> setRepeat(String state) async {
    // state: 'track', 'context', 'off'
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/repeat?state=$state'),
        headers: headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) print('❌ Error setting repeat: $e');
      return false;
    }
  }
}
