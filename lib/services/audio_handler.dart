import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import '../jellyfin/jellyfin_track.dart';

class NautuneAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final void Function() onPlay;
  final void Function() onPause;
  final void Function() onStop;
  final void Function() onSkipToNext;
  final void Function() onSkipToPrevious;
  final void Function(Duration) onSeek;
  
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _stateSubscription;

  NautuneAudioHandler({
    required AudioPlayer player,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onSkipToNext,
    required this.onSkipToPrevious,
    required this.onSeek,
  }) : _player = player {
    _listenToPlayerState();
  }

  void _listenToPlayerState() {
    // Listen to position changes
    _positionSubscription = _player.onPositionChanged.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // Listen to duration changes
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      final currentItem = mediaItem.value;
      if (currentItem != null) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    });

    // Listen to playback state changes
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      final processingState = state == PlayerState.completed
          ? AudioProcessingState.completed
          : state == PlayerState.playing || state == PlayerState.paused
              ? AudioProcessingState.ready
              : AudioProcessingState.idle;

      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: processingState,
      ));
    });
  }

  void updateNautuneMediaItem(JellyfinTrack track) {
    final item = MediaItem(
      id: track.id,
      album: track.album,
      title: track.name,
      artist: track.displayArtist,
      duration: track.duration,
      artUri: track.artworkUrl() != null ? Uri.parse(track.artworkUrl()!) : null,
    );
    mediaItem.add(item);
  }

  void updateNautuneQueue(List<JellyfinTrack> tracks) {
    queue.add(tracks.map((track) => MediaItem(
      id: track.id,
      album: track.album,
      title: track.name,
      artist: track.displayArtist,
      duration: track.duration,
      artUri: track.artworkUrl() != null ? Uri.parse(track.artworkUrl()!) : null,
    )).toList());
  }

  @override
  Future<void> play() async {
    onPlay();
  }

  @override
  Future<void> pause() async {
    onPause();
  }

  @override
  Future<void> stop() async {
    onStop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    onSkipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious();
  }

  @override
  Future<void> seek(Duration position) async {
    onSeek(position);
  }

  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _stateSubscription?.cancel();
  }
}
