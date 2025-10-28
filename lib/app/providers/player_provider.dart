import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:musicalice/core/services/spotify_service.dart';
import 'package:musicalice/core/services/spotify_player_service.dart';

enum RepeatMode { off, all, one }

class PlayerProvider extends ChangeNotifier {
  final SpotifyPlayerService _playerService = SpotifyPlayerService();

  Track? _currentTrack;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _progressTimer;
  String? _currentPlaylistId;

  List<Track> _playlistQueue = [];
  bool _isLikedSongsPlaylist = false;
  int _currentTrackIndex = -1;

  bool _isShuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  List<int> _shuffledIndices = [];
  int _shufflePosition = 0;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get hasTrack => _currentTrack != null;
  String? get currentPlaylistId => _currentPlaylistId;
  bool get isShuffleEnabled => _isShuffleEnabled;
  RepeatMode get repeatMode => _repeatMode;
  List<Track> get playlistQueue => _playlistQueue;

  // === Play New Track ===
  Future<bool> playTrack(Track track, {String? playlistId}) async {
    try {
      final devices = await _playerService.getDevices();

      if (devices.isEmpty) {
        if (kDebugMode) print('❌ No Spotify devices available');
        return false;
      }

      final trackUri = 'spotify:track:${track.id}';
      final success = await _playerService.playTrack(trackUri);

      if (success) {
        _currentTrack = track;
        _isPlaying = true;
        _currentPlaylistId = playlistId;
        _startProgressTracking();
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Error playing track: $e');
      return false;
    }
  }

  // === Play Track from Playlist ===
  Future<bool> playTrackFromPlaylist({
    required Track track,
    required String playlistId,
    bool isLikedSongs = false,
  }) async {
    try {
      final devices = await _playerService.getDevices();

      if (devices.isEmpty) {
        if (kDebugMode) print('❌ No Spotify devices available');
        return false;
      }

      final trackUri = 'spotify:track:${track.id}';
      final success = await _playerService.playTrack(trackUri);

      if (success) {
        _currentTrack = track;
        _isPlaying = true;
        _currentPlaylistId = isLikedSongs ? 'liked_songs' : playlistId;
        _isLikedSongsPlaylist = isLikedSongs;

        // Update current track index in queue
        _currentTrackIndex = _playlistQueue.indexWhere((t) => t.id == track.id);

        // Update shuffle position if shuffle is enabled
        if (_isShuffleEnabled && _shuffledIndices.isNotEmpty) {
          _shufflePosition = _shuffledIndices.indexOf(_currentTrackIndex);
          if (_shufflePosition == -1) _shufflePosition = 0;
        }

        _startProgressTracking();
        notifyListeners();

        if (kDebugMode) {
          print('🎵 Playing track: ${track.title}');
          print('📋 Playlist: $playlistId');
          print('📍 Track index: $_currentTrackIndex');
          print('🔀 Shuffle: $_isShuffleEnabled');
        }

        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Error playing track: $e');
      return false;
    }
  }

  // === Set Playlist Queue ===
  void setPlaylistQueue(
    List<Track> tracks,
    String playlistId,
    bool isLikedSongs,
  ) {
    _playlistQueue = tracks;
    _currentPlaylistId = playlistId;
    _isLikedSongsPlaylist = isLikedSongs;

    // Find current track index
    if (_currentTrack != null) {
      _currentTrackIndex = _playlistQueue.indexWhere(
        (track) => track.id == _currentTrack!.id,
      );
    }

    // Generate shuffled indices if shuffle is enabled
    if (_isShuffleEnabled) {
      _generateShuffledIndices();
    }

    if (kDebugMode) {
      print('📋 Playlist queue set: ${tracks.length} tracks');
      print('📍 Current index: $_currentTrackIndex');
    }

    notifyListeners();
  }

  // === Toggle Shuffle ===
  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    setShuffleMode(_isShuffleEnabled);
  }

  // === Set Shuffle Mode ===
  void setShuffleMode(bool enabled) {
    _isShuffleEnabled = enabled;

    if (enabled) {
      _generateShuffledIndices();
      if (kDebugMode) print('🔀 Shuffle enabled');
    } else {
      _shuffledIndices.clear();
      _shufflePosition = 0;
      if (kDebugMode) print('▶️ Shuffle disabled');
    }

    notifyListeners();
  }

  // === Generate Shuffled Indices ===
  void _generateShuffledIndices() {
    if (_playlistQueue.isEmpty) return;

    // Create list of all indices
    _shuffledIndices = List.generate(_playlistQueue.length, (i) => i);

    // Move current track to first position if exists
    if (_currentTrackIndex >= 0 &&
        _currentTrackIndex < _shuffledIndices.length) {
      _shuffledIndices.remove(_currentTrackIndex);
      _shuffledIndices.insert(0, _currentTrackIndex);
    }

    // Shuffle remaining tracks using Fisher-Yates algorithm
    final random = Random();
    for (int i = 1; i < _shuffledIndices.length; i++) {
      int j = i + random.nextInt(_shuffledIndices.length - i);
      final temp = _shuffledIndices[i];
      _shuffledIndices[i] = _shuffledIndices[j];
      _shuffledIndices[j] = temp;
    }

    _shufflePosition = 0;

    if (kDebugMode) {
      print('🔀 Generated shuffle order: $_shuffledIndices');
    }
  }

  // === Set Repeat Mode ===
  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
    if (kDebugMode) {
      print('🔁 Repeat mode: ${mode.toString().split('.').last}');
    }
    notifyListeners();
  }

  // === Toggle Play/Pause ===
  Future<void> togglePlayPause() async {
    try {
      final success = _isPlaying
          ? await _playerService.pause()
          : await _playerService.resume();

      if (success) {
        _isPlaying = !_isPlaying;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error toggling play/pause: $e');
    }
  }

  // === Skip Next ===
  Future<void> skipNext() async {
    if (_playlistQueue.isEmpty) {
      // Fallback ke Spotify API next
      try {
        await _playerService.skipNext();
        await Future.delayed(const Duration(milliseconds: 500));
        await _updateCurrentTrack();
      } catch (e) {
        if (kDebugMode) print('❌ Error skipping: $e');
      }
      return;
    }

    Track? nextTrack;

    if (_isShuffleEnabled) {
      // Shuffle mode: use shuffled indices
      _shufflePosition++;

      if (_shufflePosition >= _shuffledIndices.length) {
        // End of shuffled list
        if (_repeatMode == RepeatMode.all) {
          // Restart from beginning
          _shufflePosition = 0;
          nextTrack = _playlistQueue[_shuffledIndices[_shufflePosition]];
          if (kDebugMode) print('🔁 Restarting playlist (shuffle)');
        } else if (_repeatMode == RepeatMode.one) {
          // Replay current track
          nextTrack = _currentTrack;
          _shufflePosition--; // Stay at current position
          if (kDebugMode) print('🔂 Repeating one song');
        } else {
          // Stop playback
          if (kDebugMode) print('⏹️ End of playlist');
          return;
        }
      } else {
        nextTrack = _playlistQueue[_shuffledIndices[_shufflePosition]];
      }
    } else {
      // Normal mode: sequential playback
      if (_repeatMode == RepeatMode.one) {
        // Replay current track
        nextTrack = _currentTrack;
        if (kDebugMode) print('🔂 Repeating one song');
      } else {
        // Move to next track
        _currentTrackIndex++;

        if (_currentTrackIndex >= _playlistQueue.length) {
          // End of playlist
          if (_repeatMode == RepeatMode.all) {
            // Restart from beginning
            _currentTrackIndex = 0;
            nextTrack = _playlistQueue[_currentTrackIndex];
            if (kDebugMode) print('🔁 Restarting playlist');
          } else {
            // Stop playback
            if (kDebugMode) print('⏹️ End of playlist');
            return;
          }
        } else {
          nextTrack = _playlistQueue[_currentTrackIndex];
        }
      }
    }

    if (nextTrack != null) {
      if (kDebugMode) print('⏭️ Skipping to: ${nextTrack.title}');
      await playTrackFromPlaylist(
        track: nextTrack,
        playlistId: _currentPlaylistId ?? '',
        isLikedSongs: _isLikedSongsPlaylist,
      );
    }
  }

  // === Skip Previous ===
  Future<void> skipPrevious() async {
    // If more than 3 seconds into the song, restart current track
    if (_position.inSeconds > 3) {
      if (kDebugMode) print('⏮️ Restarting current track');
      await seek(Duration.zero);
      return;
    }

    if (_playlistQueue.isEmpty) {
      // Fallback ke Spotify API previous
      try {
        await _playerService.skipPrevious();
        await Future.delayed(const Duration(milliseconds: 500));
        await _updateCurrentTrack();
      } catch (e) {
        if (kDebugMode) print('❌ Error going back: $e');
      }
      return;
    }

    Track? previousTrack;

    if (_isShuffleEnabled) {
      // Shuffle mode: go back in shuffled list
      _shufflePosition--;

      if (_shufflePosition < 0) {
        if (_repeatMode == RepeatMode.all) {
          // Go to last track in shuffled list
          _shufflePosition = _shuffledIndices.length - 1;
          previousTrack = _playlistQueue[_shuffledIndices[_shufflePosition]];
          if (kDebugMode) print('🔁 Going to end of playlist (shuffle)');
        } else {
          // Stay at first track
          _shufflePosition = 0;
          previousTrack = _playlistQueue[_shuffledIndices[_shufflePosition]];
          if (kDebugMode) print('⏮️ Already at first track');
        }
      } else {
        previousTrack = _playlistQueue[_shuffledIndices[_shufflePosition]];
      }
    } else {
      // Normal mode: sequential playback
      _currentTrackIndex--;

      if (_currentTrackIndex < 0) {
        if (_repeatMode == RepeatMode.all) {
          // Go to last track
          _currentTrackIndex = _playlistQueue.length - 1;
          previousTrack = _playlistQueue[_currentTrackIndex];
          if (kDebugMode) print('🔁 Going to end of playlist');
        } else {
          // Stay at first track
          _currentTrackIndex = 0;
          previousTrack = _playlistQueue[_currentTrackIndex];
          if (kDebugMode) print('⏮️ Already at first track');
        }
      } else {
        previousTrack = _playlistQueue[_currentTrackIndex];
      }
    }

    if (kDebugMode) print('⏮️ Going back to: ${previousTrack.title}');
    await playTrackFromPlaylist(
      track: previousTrack,
      playlistId: _currentPlaylistId ?? '',
      isLikedSongs: _isLikedSongsPlaylist,
    );
  }

  // === Handle Track End (Auto-play next) ===
  Future<void> onTrackEnd() async {
    if (kDebugMode) print('🏁 Track ended');

    if (_repeatMode == RepeatMode.one) {
      // Replay current track
      if (kDebugMode) print('🔂 Auto-replaying track');
      await seek(Duration.zero);
      return;
    }

    // Auto play next track
    await skipNext();
  }

  // === Seek ===
  Future<void> seek(Duration position) async {
    try {
      await _playerService.seek(position.inMilliseconds);
      _position = position;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ Error seeking: $e');
    }
  }

  // === Progress Tracking ===
  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final playback = await _playerService.getCurrentPlayback();
        if (playback != null) {
          _isPlaying = playback['is_playing'] ?? false;
          final progressMs = playback['progress_ms'] ?? 0;
          final durationMs = playback['item']?['duration_ms'] ?? 0;

          _position = Duration(milliseconds: progressMs);
          _duration = Duration(milliseconds: durationMs);

          // Check if track ended (within 1 second of duration)
          if (durationMs > 0 && progressMs >= durationMs - 1000 && _isPlaying) {
            if (kDebugMode) print('🏁 Track about to end, preparing next...');
            // Don't call onTrackEnd here, let Spotify handle it naturally
          }

          // Update current track info jika berbeda
          final trackId = playback['item']?['id'];
          if (trackId != null && trackId != _currentTrack?.id) {
            await _updateCurrentTrack();
          }

          notifyListeners();
        }
      } catch (e) {
        if (kDebugMode) print('❌ Error tracking progress: $e');
      }
    });
  }

  // === Update Current Track Info ===
  Future<void> _updateCurrentTrack() async {
    try {
      final playback = await _playerService.getCurrentPlayback();
      if (playback != null && playback['item'] != null) {
        final trackData = playback['item'];
        _currentTrack = Track.fromJson(trackData);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error updating track: $e');
    }
  }

  // === Clear Playlist Context ===
  void clearPlaylistContext() {
    _currentPlaylistId = null;
    _playlistQueue.clear();
    _currentTrackIndex = -1;
    _shuffledIndices.clear();
    _shufflePosition = 0;
    notifyListeners();
  }

  // === Stop Playback ===
  void stop() {
    _progressTimer?.cancel();
    _currentTrack = null;
    _isPlaying = false;
    _duration = Duration.zero;
    _position = Duration.zero;
    _currentPlaylistId = null;
    _playlistQueue.clear();
    _currentTrackIndex = -1;
    _shuffledIndices.clear();
    _shufflePosition = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}
