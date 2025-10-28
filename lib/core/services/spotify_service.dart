import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'spotify_auth_service.dart';

class Playlist {
  final String id;
  final String name;
  final String imageUrl;
  final int? trackCount;
  final DateTime? addedAt;

  Playlist({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.trackCount,
    this.addedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      imageUrl: (json['images'] as List).isNotEmpty
          ? json['images'][0]['url']
          : 'https://via.placeholder.com/150',
      trackCount: json['tracks']?['total'],
      addedAt: json['added_at'] != null
          ? DateTime.parse(json['added_at'])
          : null,
    );
  }
}

class Track {
  final String id;
  final String title;
  final String artist;
  final String imageUrl;
  final String? previewUrl;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.imageUrl,
    this.previewUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] ?? '',
      title: json['name'] ?? 'Unknown',
      artist:
          (json['artists'] as List?)
              ?.map((artist) => artist['name'])
              .join(', ') ??
          'Unknown Artist',
      imageUrl: (json['album']?['images'] as List?)?.isNotEmpty == true
          ? json['album']['images'][0]['url']
          : 'https://via.placeholder.com/150',
      previewUrl: json['preview_url'],
    );
  }
}

class RecentlyPlayed {
  final Track track;
  final DateTime playedAt;

  RecentlyPlayed({required this.track, required this.playedAt});

  factory RecentlyPlayed.fromJson(Map<String, dynamic> json) {
    return RecentlyPlayed(
      track: Track.fromJson(json['track']),
      playedAt: DateTime.parse(json['played_at']),
    );
  }
}

// --- Spotify Service ---
class SpotifyService {
  final String _baseUrl = 'https://api.spotify.com/v1';
  final SpotifyAuthService _authService;

  SpotifyService([SpotifyAuthService? authService])
    : _authService = authService ?? SpotifyAuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getValidToken();

    if (token == null || token.isEmpty) {
      if (kDebugMode) print('🚫 No valid token found. Please log in again.');
      throw Exception('No valid Spotify token available');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // === Get User Profile ===
  Future<Map<String, dynamic>> getUserProfile() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/me'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user profile: ${response.body}');
    }
  }

  // === Get User's Playlists ===
  Future<List<Playlist>> getUserPlaylists() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/me/playlists?limit=50'),
      headers: headers,
    );

    if (kDebugMode) print('📚 User Playlists Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['items'] as List)
          .map((json) => Playlist.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to get user playlists: ${response.body}');
    }
  }

  // === Get Recently Played ===
  Future<List<RecentlyPlayed>> getRecentlyPlayed({int limit = 20}) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/me/player/recently-played?limit=$limit'),
      headers: headers,
    );

    if (kDebugMode) print('⏮️ Recently Played Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['items'] as List)
          .map((json) => RecentlyPlayed.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to get recently played: ${response.body}');
    }
  }

  // === Get Personalized Recommendations (Advanced Algorithm) ===
  Future<List<Track>> getPersonalizedRecommendations() async {
    try {
      final headers = await _getHeaders();

      if (kDebugMode) print('🔍 Doing fallback via search');

      // Sebuah query fallback umum
      final query = 'top english songs';
      final encodedQuery = Uri.encodeComponent(query);
      final url =
          'https://api.spotify.com/v1/search?q=$encodedQuery&type=track&limit=20';

      if (kDebugMode) print('🔎 Search URL: $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracksList = (data['tracks']?['items'] as List?) ?? [];

        final tracks = tracksList.map((json) => Track.fromJson(json)).toList();
        if (tracks.isNotEmpty) {
          if (kDebugMode)
            print('✅ Search fallback got ${tracks.length} tracks');
          return tracks;
        } else {
          if (kDebugMode) print('⚠️ Search returned no tracks');
        }
      } else {
        if (kDebugMode) {
          print('❌ Search request failed: ${response.statusCode}');
          print('❌ Body: ${response.body}');
        }
      }

      throw Exception('No recommendations via search');
    } catch (e) {
      if (kDebugMode) print('❌ Error in search fallback: $e');
      throw Exception('Failed to get recommendations');
    }
  }

  // === Get Featured Playlists (dengan User Auth ini seharusnya work) ===
  Future<List<Playlist>> getFeaturedPlaylists() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/browse/featured-playlists?country=ID&limit=20'),
      headers: headers,
    );

    if (kDebugMode)
      print('⭐ Featured Playlists Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['playlists']['items'] as List)
          .map((json) => Playlist.fromJson(json))
          .toList();
    } else {
      // Fallback ke search playlists
      return searchPlaylists('top hits');
    }
  }

  // === Search Playlists ===
  Future<List<Playlist>> searchPlaylists(String query) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/search?q=${Uri.encodeComponent(query)}&type=playlist&limit=20',
      ),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['playlists']['items'] as List)
          .map((json) => Playlist.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to search playlists: ${response.body}');
    }
  }

  Future<List<Track>> getTracksWithPreview() async {
    final headers = await _getHeaders();

    final playlistId = '37i9dQZEVXbMDoHDwVN2tF';

    final response = await http.get(
      Uri.parse('$_baseUrl/playlists/$playlistId/tracks'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tracks = (data['items'] as List)
          .where((item) => item['track'] != null)
          .map((item) => Track.fromJson(item['track']))
          .toList();

      if (kDebugMode) {
        final withPreview = tracks.where((t) => t.previewUrl != null).length;
        print('✅ Tracks with preview: $withPreview / ${tracks.length}');
      }

      return tracks;
    } else {
      throw Exception('Failed to get tracks: ${response.body}');
    }
  }

  // === Search Tracks ===
  Future<List<Track>> searchTracks(String query) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/search?q=${Uri.encodeComponent(query)}&type=track&limit=20',
      ),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['tracks']['items'] as List)
          .map((json) => Track.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to search tracks: ${response.body}');
    }
  }

  // === Get Playlist Tracks ===
  Future<List<Track>> getPlaylistTracks(String playlistId) async {
    final headers = await _getHeaders();

    if (kDebugMode) print('📋 Fetching tracks for playlist ID: $playlistId');

    final response = await http.get(
      Uri.parse('$_baseUrl/playlists/$playlistId/tracks?market=ID'),
      headers: headers,
    );

    if (kDebugMode) print('🔍 Playlist Tracks Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['items'] as List)
          .where((item) => item['track'] != null)
          .map((item) => Track.fromJson(item['track']))
          .toList();
    } else {
      throw Exception('Failed to load playlist tracks: ${response.body}');
    }
  }

  // === Get User's Saved/Liked Tracks ===
  Future<List<Track>> getSavedTracks({int limit = 50}) async {
    final headers = await _getHeaders();
    List<Track> allTracks = [];
    int offset = 0;
    bool hasMore = true;

    while (hasMore) {
      final response = await http.get(
        Uri.parse('$_baseUrl/me/tracks?limit=$limit&offset=$offset'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List;

        allTracks.addAll(
          items.map((item) => Track.fromJson(item['track'])).toList(),
        );

        if (items.length < limit) {
          hasMore = false;
        } else {
          offset += limit;
        }
      } else {
        throw Exception('Failed to get saved tracks: ${response.body}');
      }
    }

    return allTracks;
  }

  // === Check if Track is Saved ===
  Future<bool> isTrackSaved(String trackId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/me/tracks/contains?ids=$trackId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> result = jsonDecode(response.body);
      return result.isNotEmpty && result[0] == true;
    }
    return false;
  }

  // === Save/Like Track ===
  Future<bool> saveTrack(String trackId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$_baseUrl/me/tracks?ids=$trackId'),
      headers: headers,
    );

    if (kDebugMode) print('💚 Save Track Status: ${response.statusCode}');
    return response.statusCode == 200;
  }

  // === Remove/Unlike Track ===
  Future<bool> removeTrack(String trackId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/me/tracks?ids=$trackId'),
      headers: headers,
    );

    if (kDebugMode) print('💔 Remove Track Status: ${response.statusCode}');
    return response.statusCode == 200;
  }

  // === Get New Releases ===
  Future<List<Track>> getNewReleases() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/browse/new-releases?country=ID&limit=10'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<Track> tracks = [];

      for (var album in data['albums']['items']) {
        final albumId = album['id'];
        final albumTracksResponse = await http.get(
          Uri.parse('$_baseUrl/albums/$albumId/tracks?limit=1'),
          headers: headers,
        );

        if (albumTracksResponse.statusCode == 200) {
          final trackData = jsonDecode(albumTracksResponse.body);
          if (trackData['items'].isNotEmpty) {
            final trackJson = trackData['items'][0];
            trackJson['album'] = album;
            tracks.add(Track.fromJson(trackJson));
          }
        }
      }

      return tracks;
    } else {
      throw Exception('Failed to get new releases: ${response.body}');
    }
  }

  // === Get Artist's Top Tracks ===
  Future<List<Track>> getArtistTopTracks(String artistId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/artists/$artistId/top-tracks?market=ID'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['tracks'] as List)
          .map((json) => Track.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to get artist top tracks: ${response.body}');
    }
  }

  // === Get Current User's Top Artists ===
  Future<List<Map<String, dynamic>>> getTopArtists({
    String timeRange = 'medium_term',
    int limit = 20,
  }) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/me/top/artists?time_range=$timeRange&limit=$limit'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['items'] as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to get top artists: ${response.body}');
    }
  }

  // === Get Current User's Top Tracks ===
  Future<List<Track>> getTopTracks({
    String timeRange = 'medium_term',
    int limit = 20,
  }) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/me/top/tracks?time_range=$timeRange&limit=$limit'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['items'] as List)
          .map((json) => Track.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to get top tracks: ${response.body}');
    }
  }
}
