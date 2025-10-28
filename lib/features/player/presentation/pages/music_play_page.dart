import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:musicalice/core/services/spotify_service.dart';
import 'package:musicalice/app/providers/player_provider.dart';

class MusicPlayPage extends StatefulWidget {
  final Track track;
  const MusicPlayPage({super.key, required this.track});

  @override
  State<MusicPlayPage> createState() => _MusicPlayPageState();
}

class _MusicPlayPageState extends State<MusicPlayPage> {
  bool _isLoading = false;
  RepeatMode _repeatMode = RepeatMode.off;

  @override
  void initState() {
    super.initState();
    _playTrack();
  }

  Future<void> _playTrack() async {
    final player = Provider.of<PlayerProvider>(context, listen: false);

    // Jika track yang sama sudah playing, tidak perlu play ulang
    if (player.currentTrack?.id == widget.track.id) {
      return;
    }

    setState(() => _isLoading = true);

    final success = await player.playTrack(widget.track);

    if (!success && mounted) {
      _showDeviceRequiredDialog();
    }

    setState(() => _isLoading = false);
  }

  void _showDeviceRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text(
          'No Spotify Device Found',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please open Spotify app on your phone, computer, or any device, then try again.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _playTrack();
            },
            child: const Text('Retry', style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _toggleRepeat() {
    setState(() {
      switch (_repeatMode) {
        case RepeatMode.off:
          _repeatMode = RepeatMode.all;
          break;
        case RepeatMode.all:
          _repeatMode = RepeatMode.one;
          break;
        case RepeatMode.one:
          _repeatMode = RepeatMode.off;
          break;
      }
    });

    final player = Provider.of<PlayerProvider>(context, listen: false);
    player.setRepeatMode(_repeatMode);

    String message;
    switch (_repeatMode) {
      case RepeatMode.off:
        message = 'Repeat off';
        break;
      case RepeatMode.all:
        message = 'Repeat playlist';
        break;
      case RepeatMode.one:
        message = 'Repeat one song';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF282828),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleShuffle() {
    final player = Provider.of<PlayerProvider>(context, listen: false);
    player.toggleShuffle();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(player.isShuffleEnabled ? 'Shuffle on' : 'Shuffle off'),
        backgroundColor: const Color(0xFF282828),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildRepeatButton() {
    Color iconColor;
    Widget icon;

    switch (_repeatMode) {
      case RepeatMode.off:
        iconColor = Colors.grey[400]!;
        icon = const Icon(Icons.repeat, size: 28);
        break;
      case RepeatMode.all:
        iconColor = const Color(0xFF1DB954);
        icon = const Icon(Icons.repeat, size: 28);
        break;
      case RepeatMode.one:
        iconColor = const Color(0xFF1DB954);
        icon = Stack(
          alignment: Alignment.center,
          children: const [
            Icon(Icons.repeat, size: 28),
            Positioned(
              bottom: 2,
              child: Text(
                '1',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1DB954),
                ),
              ),
            ),
          ],
        );
        break;
    }

    return IconButton(
      icon: icon,
      iconSize: 28,
      color: iconColor,
      onPressed: _toggleRepeat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final isPlaying = player.isPlaying;
        final position = player.position;
        final duration = player.duration;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              children: [
                const Text(
                  'Playing from Spotify',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  widget.track.artist,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  // Album Art
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          widget.track.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF282828),
                              child: const Icon(
                                Icons.music_note,
                                size: 100,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Track Info
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.track.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.track.artist,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[400],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Progress Bar
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.grey[800],
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: position.inSeconds.toDouble(),
                          max: duration.inSeconds.toDouble() > 0
                              ? duration.inSeconds.toDouble()
                              : 1.0,
                          onChanged: (value) {
                            player.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shuffle),
                        iconSize: 28,
                        color: player.isShuffleEnabled
                            ? const Color(0xFF1DB954)
                            : Colors.grey[400],
                        onPressed: _toggleShuffle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        iconSize: 40,
                        color: Colors.white,
                        onPressed: () => player.skipPrevious(),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 40,
                                ),
                                color: Colors.black,
                                onPressed: () => player.togglePlayPause(),
                              ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        iconSize: 40,
                        color: Colors.white,
                        onPressed: () => player.skipNext(),
                      ),
                      _buildRepeatButton(),
                    ],
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
