import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:musicalice/core/services/spotify_auth_service.dart';
import 'package:musicalice/core/services/spotify_service.dart';
import 'package:musicalice/features/library/presentation/pages/playlist_detail_page.dart';
import 'package:musicalice/app/providers/player_provider.dart';

enum SortOption { recents, recentlyAdded, alphabetical }

class LibraryPage extends StatefulWidget {
  final SpotifyAuthService authService;

  const LibraryPage({super.key, required this.authService});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final SpotifyService _spotifyService;
  late Future<Map<String, dynamic>> _libraryDataFuture;
  SortOption _currentSort = SortOption.recents;
  bool _isGridView = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _spotifyService = SpotifyService(widget.authService);
    _libraryDataFuture = _loadLibraryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadLibraryData() async {
    final results = await Future.wait([
      _spotifyService.getUserPlaylists(),
      _spotifyService.getSavedTracks(limit: 50),
    ]);

    final playlists = results[0] as List<Playlist>;
    final likedSongs = results[1] as List<Track>;

    return {
      'playlists': playlists,
      'likedSongs': likedSongs,
      'likedSongsCount': likedSongs.length,
    };
  }

  String _getSortLabel() {
    switch (_currentSort) {
      case SortOption.recents:
        return 'Recents';
      case SortOption.recentlyAdded:
        return 'Recently Added';
      case SortOption.alphabetical:
        return 'Alphabetical';
    }
  }

  List<Playlist> _sortPlaylists(List<Playlist> playlists) {
    final sorted = List<Playlist>.from(playlists);

    switch (_currentSort) {
      case SortOption.recents:
        return sorted.reversed.toList();
      case SortOption.recentlyAdded:
        sorted.sort((a, b) {
          if (a.addedAt != null && b.addedAt != null) {
            return b.addedAt!.compareTo(a.addedAt!);
          }
          return 0;
        });
        return sorted;
      case SortOption.alphabetical:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return sorted;
    }
  }

  List<Playlist> _filterPlaylists(List<Playlist> playlists) {
    if (_searchQuery.isEmpty) return playlists;

    return playlists.where((playlist) {
      return playlist.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
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
                margin: const EdgeInsets.only(top: 12, bottom: 2),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 126, 126, 126),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Sort by',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Divider(color: Color.fromARGB(255, 54, 54, 54), height: 1),
              _buildSortOption('Recents', SortOption.recents),
              _buildSortOption('Recently Added', SortOption.recentlyAdded),
              _buildSortOption('Alphabetical', SortOption.alphabetical),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, SortOption option) {
    final isSelected = _currentSort == option;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF1DB954) : Colors.white,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF1DB954))
          : null,
      onTap: () {
        setState(() {
          _currentSort = option;
        });
        Navigator.pop(context);
      },
    );
  }

  AppBar _buildMainAppBar() {
    return AppBar(
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
        'Your Library',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 28),
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.3),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search in Your Library',
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        onChanged: (query) {
          setState(() {
            _searchQuery = query;
          });
        },
      ),
      actions: [
        if (_searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isSearching ? _buildSearchAppBar() : _buildMainAppBar(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _libraryDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading library: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'No data found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final allPlaylists = snapshot.data!['playlists'] as List<Playlist>;
          final sortedPlaylists = _sortPlaylists(allPlaylists);
          final playlists = _filterPlaylists(sortedPlaylists);
          final likedSongsCount = snapshot.data!['likedSongsCount'] as int;
          final likedSongsImage = snapshot.data!['likedSongsImage'] as String?;

          // Filter Liked Songs jika ada search query
          final showLikedSongs =
              _searchQuery.isEmpty ||
              'liked songs'.contains(_searchQuery.toLowerCase());

          return Consumer<PlayerProvider>(
            builder: (context, player, child) {
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                  overscroll: false,
                  physics: const ClampingScrollPhysics(),
                ),
                child: CustomScrollView(
                  slivers: [
                    // Sort and Grid Toggle Controls
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          right: 0,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: _showSortBottomSheet,
                              icon: const Icon(
                                Icons.import_export,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                _getSortLabel(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isGridView
                                    ? Icons.list
                                    : Icons.grid_view_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isGridView = !_isGridView;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Content (List or Grid)
                    _isGridView
                        ? _buildGridContent(
                            playlists,
                            player,
                            likedSongsImage,
                            likedSongsCount,
                            showLikedSongs,
                          )
                        : _buildListContent(
                            playlists,
                            player,
                            likedSongsImage,
                            likedSongsCount,
                            showLikedSongs,
                          ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLikedSongsPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple, Colors.blue],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Icon(Icons.favorite, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildListContent(
    List<Playlist> playlists,
    PlayerProvider player,
    String? likedSongsImage,
    int likedSongsCount,
    bool showLikedSongs,
  ) {
    final itemCount = showLikedSongs ? playlists.length + 1 : playlists.length;

    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 145),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (showLikedSongs && index == 0) {
            final isActiveLikedSongs =
                player.currentPlaylistId == 'liked_songs';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0, // sudah ada padding di SliverPadding
                vertical: 8,
              ),
              leading: likedSongsImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        likedSongsImage,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildLikedSongsPlaceholder();
                        },
                      ),
                    )
                  : _buildLikedSongsPlaceholder(),
              title: Text(
                'Liked Songs',
                style: TextStyle(
                  color: isActiveLikedSongs
                      ? const Color(0xFF1DB954)
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Playlist • $likedSongsCount songs',
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaylistDetailPage(
                      spotifyService: _spotifyService,
                      isLikedSongs: true,
                      playlistImageUrl: likedSongsImage,
                    ),
                  ),
                );
              },
            );
          }

          final playlistIndex = showLikedSongs ? index - 1 : index;
          final playlist = playlists[playlistIndex];
          final isActivePlaylist = player.currentPlaylistId == playlist.id;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 8,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
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
                    child: const Icon(Icons.music_note, color: Colors.grey),
                  );
                },
              ),
            ),
            title: Text(
              playlist.name,
              style: TextStyle(
                color: isActivePlaylist
                    ? const Color(0xFF1DB954)
                    : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Playlist • ${playlist.trackCount ?? 0} songs',
              style: TextStyle(color: Colors.grey),
            ),
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
          );
        }, childCount: itemCount),
      ),
    );
  }

  Widget _buildGridContent(
    List<Playlist> playlists,
    PlayerProvider player,
    String? likedSongsImage,
    int likedSongsCount,
    bool showLikedSongs,
  ) {
    final itemCount = showLikedSongs ? playlists.length + 1 : playlists.length;

    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 160),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 30,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (showLikedSongs && index == 0) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaylistDetailPage(
                      spotifyService: _spotifyService,
                      isLikedSongs: true,
                      playlistImageUrl: likedSongsImage,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: likedSongsImage != null
                          ? Image.network(
                              likedSongsImage,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Colors.purple, Colors.blue],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.favorite,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                            )
                          : Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.purple, Colors.blue],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.favorite,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Liked Songs',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$likedSongsCount songs',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                  ),
                ],
              ),
            );
          }

          final playlistIndex = showLikedSongs ? index - 1 : index;
          final playlist = playlists[playlistIndex];

          return GestureDetector(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      playlist.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  playlist.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${playlist.trackCount ?? 0} songs',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                ),
              ],
            ),
          );
        }, childCount: itemCount),
      ),
    );
  }
}
