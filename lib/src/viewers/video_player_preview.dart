import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A widget that displays a video from the given file path.
class VideoPlayerWidget extends StatefulWidget {
  /// The video file to display.
  final File file;

  /// Creates a [VideoPlayerWidget].
  ///
  /// The [filePath] parameter is required.
  const VideoPlayerWidget({super.key, required this.file});

  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

// ignore: public_member_api_docs
class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  /// Reinitialize video when a new file is selected.
  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) {
      _initializeVideo();
    }
  }

  /// Initializes the video player.
  void _initializeVideo() {
    // Dispose of the old controller if it exists
    _controller?.dispose();

    // Create a new controller
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {}); // Refresh UI after initialization
        _controller!.play(); // Auto-play new video
      });
  }

  /// Toggles play and pause on tap.
  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  /// Builds the widget tree for the video player.
  @override

  /// Builds a video player widget.
  ///
  /// The widget is a [GestureDetector] that wraps a [VideoPlayer] in an
  /// [AspectRatio] widget. When the video is not playing, a play arrow icon
  /// is displayed centered on top of the video. If the video is not yet
  /// initialized, a [CircularProgressIndicator] is displayed instead.
  Widget build(BuildContext context) {
    return Center(
      child: _controller != null && _controller!.value.isInitialized
          ? Stack(
              alignment: Alignment.center,
              children: <Widget>[
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
                if (!_isPlaying)
                  const Icon(
                    Icons.play_arrow,
                    size: 60,
                    color: Colors.white,
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  /// Disposes the video player controller when the widget is removed from the widget tree.
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
