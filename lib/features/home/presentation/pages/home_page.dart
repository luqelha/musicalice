import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:musicalice/core/services/spotify_auth_service.dart';
import 'package:musicalice/core/services/spotify_service.dart';
import 'package:musicalice/features/player/presentation/pages/music_play_page.dart';
import 'package:musicalice/features/library/presentation/pages/playlist_detail_page.dart';
import 'package:musicalice/features/home/presentation/widgets/recently_played_card.dart';
import 'package:musicalice/features/home/presentation/widgets/recommended_song_title.dart';
import 'package:musicalice/app/widgets/animated_equalizer.dart';
import 'package:musicalice/app/providers/player_provider.dart';

class HomePage extends StatefulWidget {
  final SpotifyAuthService authService;

  const HomePage({super.key, required this.authService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SpotifyService _spotifyService;
  late Future<List<Playlist>> _userPlaylists;
  late Future<List<Track>> _recommendations;
  late Future<List<RecentlyPlayed>> _recentlyPlayed;
  String? currentPlayingPlaylistId;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _spotifyService = SpotifyService(widget.authService);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _userPlaylists = _spotifyService.getUserPlaylists();
      _recommendations = _spotifyService.getPersonalizedRecommendations();
      _recentlyPlayed = _spotifyService.getRecentlyPlayed(limit: 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.3),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
        ),
        title: const Text(
          'Musicalice',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadData();
        },
        color: const Color(0xFF1DB954),
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(overscroll: false),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Playlists',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildUserPlaylists(),

                // Recently Played Section
                const Text(
                  'Recently Played',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecentlyPlayed(),
                const SizedBox(height: 30),

                // Recommendations Section
                const Text(
                  'Recommend for you',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecommendations(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserPlaylists() {
    return FutureBuilder<List<Playlist>>(
      future: _userPlaylists,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid();
        }
        if (snapshot.hasError) {
          return _buildErrorWidget(
            'Failed to load your playlists',
            snapshot.error,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No playlists found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final playlists = snapshot.data!.take(8).toList();
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
          ),
          itemCount: playlists.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return _buildPlaylistGridItem(playlist);
          },
          padding: const EdgeInsets.only(bottom: 35),
        );
      },
    );
  }

  Widget _buildPlaylistGridItem(Playlist playlist) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final bool isCurrentPlaylist = player.currentPlaylistId == playlist.id;
        final bool isPlaying = player.isPlaying;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaylistDetailPage(
                  spotifyService: _spotifyService,
                  playlistId: playlist.id,
                  playlistName: playlist.name,
                  playlistImageUrl: playlist.imageUrl,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  child: Image.network(
                    playlist.imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.grey,
                          size: 30,
                        ),
                      );
                    },
                  ),
                ),

                // Nama Playlist
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      playlist.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ),

                // 🎵 Equalizer aktif kalau playlist ini sedang diputar
                if (isCurrentPlaylist && isPlaying)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: AnimatedEqualizer(
                      size: 20,
                      color: Color(0xFF1DB954),
                      isAnimating: true,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentlyPlayed() {
    return FutureBuilder<List<RecentlyPlayed>>(
      future: _recentlyPlayed,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingHorizontalList();
        }
        if (snapshot.hasError) {
          return _buildErrorWidget(
            'Failed to load recently played',
            snapshot.error,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No recently played tracks.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final recentTracks = snapshot.data!;
        return SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recentTracks.length,
            itemBuilder: (context, index) {
              final recent = recentTracks[index];
              return RecentlyPlayedCard(
                track: recent.track,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MusicPlayPage(track: recent.track),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecommendations() {
    return FutureBuilder<List<Track>>(
      future: _recommendations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingList();
        }
        if (snapshot.hasError) {
          return _buildErrorWidget(
            'Failed to load recommendations',
            snapshot.error,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No recommendations found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final tracks = snapshot.data!;
        return ListView.builder(
          itemCount: tracks.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final track = tracks[index];
            return RecommendedSongTitle(
              track: track,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MusicPlayPage(track: track),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }

  Widget _buildLoadingHorizontalList() {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      itemCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String message, Object? error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
