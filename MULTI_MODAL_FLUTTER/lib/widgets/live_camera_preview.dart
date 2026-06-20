import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../providers/app_providers.dart';
import '../services/webrtc_service.dart';

class LiveCameraPreview extends ConsumerWidget {
  const LiveCameraPreview({super.key, this.height = 220});

  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(activeModeProvider);
    return _Preview(
      service: ref.watch(webrtcServiceProvider),
      height: height,
      activeMode: activeMode,
    );
  }
}

class _Preview extends StatefulWidget {
  const _Preview({
    required this.service,
    required this.activeMode,
    this.height,
  });

  final String activeMode;
  final WebRTCService service;
  final double? height;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  final GlobalKey _boundaryKey = GlobalKey();
  StreamSubscription<MediaStream>? _subscription;
  bool _ready = false;
  Uint8List? _frozenBytes;

  @override
  void initState() {
    super.initState();
    _attach();
    if (widget.activeMode == 'caption') {
      _captureFrame();
    }
  }

  @override
  void didUpdateWidget(covariant _Preview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) _attach();

    if (widget.activeMode == 'caption' && oldWidget.activeMode != 'caption') {
      _captureFrame();
    } else if (widget.activeMode != 'caption' && oldWidget.activeMode == 'caption') {
      setState(() {
        _frozenBytes = null;
      });
    }
  }

  Future<void> _attach() async {
    await _subscription?.cancel();
    if (!_ready) {
      await _renderer.initialize();
      _ready = true;
    }
    _renderer.srcObject = widget.service.currentStream;
    _subscription = widget.service.localStream.listen((stream) {
      if (mounted) setState(() => _renderer.srcObject = stream);
    });
    if (mounted) setState(() {});
  }

  Future<void> _captureFrame() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted) {
          setState(() {
            _frozenBytes = byteData.buffer.asUint8List();
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to capture frame: $e");
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: RepaintBoundary(
        key: _boundaryKey,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: _frozenBytes != null
              ? Image.memory(
                  _frozenBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: widget.height,
                )
              : (_renderer.srcObject == null
                  ? const ColoredBox(
                      color: Colors.white10,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : RTCVideoView(
                      _renderer,
                      mirror: false,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )),
        ),
      ),
    );
  }
}
