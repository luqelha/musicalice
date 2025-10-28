// lib/core/services/spotify_auth_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SpotifyAuthService {
  // Singleton pattern
  static final SpotifyAuthService _instance = SpotifyAuthService._internal();
  factory SpotifyAuthService() => _instance;
  SpotifyAuthService._internal();

  static const String _authUrl = 'https://accounts.spotify.com/authorize';
  static const String _tokenUrl = 'https://accounts.spotify.com/api/token';
  static const String _redirectUri = 'musicalice://callback';

  final String _clientId = dotenv.env['SPOTIFY_CLIENT_ID']!;

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  String? _codeVerifier;
  String? _state;

  static const List<String> _scopes = [
    'user-read-private',
    'user-read-email',
    'user-library-read',
    'user-library-modify',
    'user-read-playback-state',
    'user-modify-playback-state',
    'user-read-currently-playing',
    'user-read-recently-played',
    'user-read-playback-position',
    'user-top-read',
    'playlist-read-private',
    'playlist-read-collaborative',
    'playlist-modify-public',
    'playlist-modify-private',
    'streaming',
  ];

  // === PKCE Helpers ===
  String _generateCodeVerifier() => _generateRandomString(96);

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(
      digest.bytes,
    ).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
  }

  String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // === LOGIN FLOW ===
  Future<String> getLoginUrl() async {
    _codeVerifier = _generateCodeVerifier();
    _state = _generateRandomString(16);

    final codeChallenge = _generateCodeChallenge(_codeVerifier!);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spotify_code_verifier', _codeVerifier!);
    await prefs.setString('spotify_state', _state!);

    final authUri = Uri.parse(_authUrl).replace(
      queryParameters: {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
        'state': _state,
        'scope': _scopes.join(' '),
      },
    );

    return authUri.toString();
  }

  Future<void> login() async {
    final url = await getLoginUrl();
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch Spotify login URL');
    }
  }

  Future<bool> handleCallback(Uri callbackUri) async {
    try {
      final code = callbackUri.queryParameters['code'];
      final state = callbackUri.queryParameters['state'];
      final error = callbackUri.queryParameters['error'];

      if (error != null) throw Exception('Spotify auth error: $error');

      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getString('spotify_state');
      final verifier = prefs.getString('spotify_code_verifier');

      if (state != savedState || verifier == null) {
        throw Exception('State mismatch or missing verifier');
      }

      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'code': code!,
          'redirect_uri': _redirectUri,
          'code_verifier': verifier,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: data['expires_in']),
        );

        await _saveTokens();

        await prefs.remove('spotify_state');
        await prefs.remove('spotify_code_verifier');
        if (kDebugMode) print('✅ Login berhasil dan token disimpan!');
        return true;
      } else {
        throw Exception('Token exchange failed: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error handleCallback: $e');
      return false;
    }
  }

  // === TOKEN MANAGEMENT ===
  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spotify_access_token', _accessToken ?? '');
    await prefs.setString('spotify_refresh_token', _refreshToken ?? '');
    await prefs.setInt(
      'spotify_token_expiry',
      _tokenExpiry?.millisecondsSinceEpoch ?? 0,
    );
  }

  Future<bool> loadSavedTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('spotify_access_token');
    _refreshToken = prefs.getString('spotify_refresh_token');
    final expiryMs = prefs.getInt('spotify_token_expiry');

    if (expiryMs != null) {
      _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    }

    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(_tokenExpiry!)) {
        if (kDebugMode) print('✅ Token masih valid, tidak perlu login ulang.');
        return true;
      } else if (_refreshToken != null) {
        return await refreshAccessToken();
      }
    }

    return false;
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _tokenExpiry = DateTime.now().add(
          Duration(seconds: data['expires_in']),
        );

        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
        }

        await _saveTokens();
        if (kDebugMode) print('🔄 Token refreshed!');
        return true;
      } else {
        if (kDebugMode)
          print('⚠️ Refresh failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error refreshing token: $e');
    }

    return false;
  }

  Future<String?> getValidToken() async {
    // Load token dulu kalau belum ada di memori
    if (_accessToken == null) {
      await loadSavedTokens();
    }

    // Coba refresh kalau sudah hampir kadaluarsa
    if (_tokenExpiry != null &&
        DateTime.now().isAfter(
          _tokenExpiry!.subtract(const Duration(minutes: 5)),
        )) {
      await refreshAccessToken();
    }

    return _accessToken;
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotify_access_token');
    await prefs.remove('spotify_refresh_token');
    await prefs.remove('spotify_token_expiry');

    if (kDebugMode) print('👋 Logged out successfully.');
  }

  String? get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken != null;
}
