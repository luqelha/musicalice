import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:musicalice/core/services/spotify_service.dart';
import 'package:provider/provider.dart';
import 'package:musicalice/app/providers/player_provider.dart';
import 'package:musicalice/app/widgets/mini_player.dart';
import 'package:musicalice/app/widgets/animated_equalizer.dart';

// Enum untuk sorting
enum PlaylistSortOption {
  title, // A-Z by title
  artist, // A-Z by artist
  album, // A-Z by album
}

class PlaylistDetailPage extends StatefulWidget {
  final SpotifyService spotifyService;
  final String? playlistId;
  final bool isLikedSongs;
  final String? playlistName;
  final String? playlistImageUrl;

  const PlaylistDetailPage({
    super.key,
    required this.spotifyService,
    this.playlistId,
    this.isLikedSongs = false,
    this.playlistName,
    this.playlistImageUrl,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late Future<List<Track>> _tracksFuture;
  String _title = '';
  int _songCount = 0;
  String? _imageUrl;

  List<Track> _allTracks = [];
  List<Track> _filteredTracks = [];
  PlaylistSortOption _currentSort = PlaylistSortOption.title;
  bool _isShuffled = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _title = widget.isLikedSongs
        ? 'Liked Songs'
        : widget.playlistName ?? 'Playlist';
    _imageUrl = widget.playlistImageUrl;
    _tracksFuture = _fetchTracks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Track>> _fetchTracks() async {
    try {
      List<Track> tracks;
      if (widget.isLikedSongs) {
        tracks = await widget.spotifyService.getSavedTracks();
      } else if (widget.playlistId != null) {
        tracks = await widget.spotifyService.getPlaylistTracks(
          widget.playlistId!,
        );
      } else {
        throw Exception('No playlist ID or Liked Songs flag provided');
      }

      if (mounted) {
        setState(() {
          _songCount = tracks.length;
          _allTracks = tracks;
          _filteredTracks = tracks;
          if (_imageUrl == null && tracks.isNotEmpty) {
            _imageUrl = tracks.first.imageUrl;
          }
        });
      }
      return tracks;
    } catch (e) {
      rethrow;
    }
  }

  // === SEARCH FUNCTION ===
  void _filterTracks(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTracks = _allTracks;
      } else {
        _filteredTracks = _allTracks.where((track) {
          final titleMatch = track.title.toLowerCase().contains(
            query.toLowerCase(),
          );
          final artistMatch = track.artist.toLowerCase().contains(
            query.toLowerCase(),
          );
          return titleMatch || artistMatch;
        }).toList();
      }
    });
  }

  // === SORT FUNCTION ===
  List<Track> _getSortedTracks() {
    List<Track> tracks = List.from(_filteredTracks);

    switch (_currentSort) {
      case PlaylistSortOption.title:
        tracks.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;

      case PlaylistSortOption.artist:
        tracks.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()),
        );
        break;

      case PlaylistSortOption.album:
        // Sort by album name (using imageUrl as proxy since we don't have album name)
        tracks.sort(
          (a, b) =>
              a.imageUrl.toLowerCase().compareTo(b.imageUrl.toLowerCase()),
        );
        break;
    }

    return tracks;
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Sort by',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF404040), height: 1),
              _buildSortOption('Title', PlaylistSortOption.title),
              _buildSortOption('Artist', PlaylistSortOption.artist),
              _buildSortOption('Album', PlaylistSortOption.album),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, PlaylistSortOption option) {
    final isSelected = _currentSort == option;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF1DB954) : Colors.white,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF1DB954), size: 24)
          : null,
      onTap: () {
        setState(() {
          _currentSort = option;
        });
        Navigator.pop(context);
      },
    );
  }

  // === SHUFFLE FUNCTION ===
  void _toggleShuffle() {
    setState(() {
      _isShuffled = !_isShuffled;
    });

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    playerProvider.setShuffleMode(_isShuffled);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isShuffled ? 'Shuffle is on' : 'Shuffle is off'),
        backgroundColor: const Color(0xFF282828),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // === PLAY PLAYLIST FUNCTION ===
  Future<void> _playPlaylist() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    List<Track> tracksToPlay = _getSortedTracks();

    if (tracksToPlay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tracks to play'),
          backgroundColor: Color(0xFF282828),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Set playlist queue
    playerProvider.setPlaylistQueue(
      tracksToPlay,
      widget.playlistId ?? 'liked_songs',
      widget.isLikedSongs,
    );

    // Shuffle if enabled
    if (_isShuffled) {
      playerProvider.setShuffleMode(true);
    }

    // Play first track from the list
    final success = await playerProvider.playTrackFromPlaylist(
      track: tracksToPlay.first,
      playlistId: widget.playlistId ?? 'liked_songs',
      isLikedSongs: widget.isLikedSongs,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active Spotify device found!'),
          backgroundColor: Color(0xFF282828),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          FutureBuilder<List<Track>>(
            future: _tracksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _songCount == 0) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load songs',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                );
              }

              final tracks = _getSortedTracks();

              return ListView.builder(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 160,
                ),
                itemCount: tracks.length + 4,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildSearchAndSort();
                  if (index == 1) return _buildHeader();
                  if (index == 2) return _buildControls();
                  if (index == 3) {
                    return widget.isLikedSongs
                        ? const SizedBox.shrink()
                        : _buildAddSong();
                  }

                  final trackIndex = widget.isLikedSongs
                      ? index - 3
                      : index - 4;
                  if (trackIndex >= 0 && trackIndex < tracks.length) {
                    return _buildSongTile(tracks[trackIndex]);
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                ClipRRect(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, -2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: BottomNavigationBar(
                        type: BottomNavigationBarType.fixed,
                        backgroundColor: Colors.transparent,
                        selectedItemColor: Colors.white,
                        unselectedItemColor: Colors.grey[600],
                        currentIndex: 2,
                        onTap: (index) {
                          if (index != 2) Navigator.of(context).pop();
                        },
                        selectedFontSize: 12,
                        unselectedFontSize: 12,
                        elevation: 0,
                        items: const [
                          BottomNavigationBarItem(
                            icon: Icon(Icons.home_outlined),
                            activeIcon: Icon(Icons.home),
                            label: 'Home',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(
                              Symbols.search,
                              weight: 400,
                              opticalSize: 24,
                            ),
                            activeIcon: Icon(
                              Symbols.search,
                              weight: 800,
                              opticalSize: 24,
                            ),
                            label: 'Search',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.library_music_outlined),
                            activeIcon: Icon(Icons.library_music),
                            label: 'Library',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.settings_outlined),
                            activeIcon: Icon(Icons.settings),
                            label: 'Settings',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _filterTracks('');
                  }
                });
              },
              child: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Find in playlist',
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                          size: 26,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.grey,
                            size: 26,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filterTracks('');
                            setState(() {
                              _isSearching = false;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.grey[850],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      onChanged: _filterTracks,
                    )
                  : Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.search,
                              color: Colors.grey,
                              size: 26,
                            ),
                          ),
                          Text(
                            'Find in playlist',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _showSortBottomSheet,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'Sort',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!widget.isLikedSongs)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _imageUrl!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                      ),
                    )
                  : _buildImagePlaceholder(),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_filteredTracks.length} songs',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        gradient: widget.isLikedSongs
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple.shade400, Colors.blue.shade300],
              )
            : null,
        color: widget.isLikedSongs ? null : Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        widget.isLikedSongs ? Icons.favorite : Icons.music_note,
        color: Colors.white,
        size: 80,
      ),
    );
  }

  Widget _buildControls() {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final isPlayingThisPlaylist =
            player.currentPlaylistId == (widget.playlistId ?? 'liked_songs') &&
            player.isPlaying;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: _toggleShuffle,
                child: Icon(
                  Icons.shuffle,
                  color: _isShuffled
                      ? const Color(0xFF1DB954)
                      : Colors.grey[400],
                  size: 28,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (isPlayingThisPlaylist) {
                    player.togglePlayPause();
                  } else {
                    _playPlaylist();
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1DB954),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlayingThisPlaylist ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddSong() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 50,
        height: 50,
        color: Colors.grey[800],
        child: const Icon(Icons.add, color: Colors.grey, size: 30),
      ),
      title: const Text(
        'Add to this playlist',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      onTap: () {},
    );
  }

  Widget _buildSongTile(Track track) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final isCurrentTrack = player.currentTrack?.id == track.id;
        final isPlaying = isCurrentTrack && player.isPlaying;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  track.imageUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[800],
                    child: const Icon(Icons.music_note, color: Colors.grey),
                  ),
                ),
              ),
              if (isCurrentTrack)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          title: Text(
            track.title,
            style: TextStyle(
              color: isCurrentTrack ? const Color(0xFF1DB954) : Colors.white,
              fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track.artist,
            style: const TextStyle(color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isCurrentTrack
              ? Padding(
                  padding: const EdgeInsets.only(right: 17.0),
                  child: AnimatedEqualizer(
                    size: 18,
                    color: const Color(0xFF1DB954),
                    isAnimating: isPlaying,
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onPressed: () {},
                  padding: const EdgeInsets.only(right: 8.0),
                  constraints: const BoxConstraints(),
                ),
          onTap: () async {
            final playerProvider = Provider.of<PlayerProvider>(
              context,
              listen: false,
            );

            if (playerProvider.currentTrack?.id == track.id) {
              playerProvider.togglePlayPause();
              return;
            }

            // Set playlist queue sebelum play
            final tracksToPlay = _getSortedTracks();
            playerProvider.setPlaylistQueue(
              tracksToPlay,
              widget.playlistId ?? 'liked_songs',
              widget.isLikedSongs,
            );

            final success = await playerProvider.playTrackFromPlaylist(
              track: track,
              playlistId: widget.playlistId ?? 'liked_songs',
              isLikedSongs: widget.isLikedSongs,
            );

            if (!success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No active Spotify device found!'),
                  backgroundColor: Color(0xFF282828),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      },
    );
  }
}
