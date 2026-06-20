import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/connection_status.dart';
import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/live_camera_preview.dart';
import '../../services/flutter_tts_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure controller starts in danger mode by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(controllerSessionProvider);
      session.webSocket.send({
        'type': 'set_mode',
        'mode': 'danger',
      });
    });
  }

  /// Human-readable label for a mode key.
  String _modeLabel(String mode) {
    switch (mode) {
      case 'danger':
        return 'Danger Detection';
      case 'sign':
        return 'Sign Language';
      case 'face':
        return 'Face Recognition';
      case 'caption':
        return 'Image Captioning';
      default:
        return mode;
    }
  }

  /// Switch the active mode and notify the controller via WebSocket.
  void _switchMode(String mode) async {
    final current = ref.read(activeModeProvider);
    if (current == mode) return;
    if (current == 'caption') {
      FlutterTtsService.instance.stop();
    }
    ref.read(activeModeProvider.notifier).state = mode;
    final session = ref.read(controllerSessionProvider);
    session.webSocket.send({
      'type': 'set_mode',
      'mode': mode,
    });

    if (mode == 'sign') {
      await context.push('/sign');
      _resetToDanger();
    } else if (mode == 'face') {
      await context.push('/face');
      _resetToDanger();
    }
  }

  void _resetToDanger() {
    if (!mounted) return;
    ref.read(activeModeProvider.notifier).state = 'danger';
    final session = ref.read(controllerSessionProvider);
    session.webSocket.send({
      'type': 'set_mode',
      'mode': 'danger',
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final activeMode = ref.watch(activeModeProvider);
    final hazardState = ref.watch(hazardStateProvider);
    final isAlert = hazardState.toLowerCase().contains('alert');
    final frameAge = ref.watch(frameAgeProvider);
    final wsUrl = ref.watch(websocketUrlProvider);

    // Derive controller IP display string
    String controllerIpValue = 'Unknown';
    try {
      final uri = Uri.parse(wsUrl);
      controllerIpValue = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    } catch (_) {
      controllerIpValue = wsUrl;
    }

    final statusLabel = connectionStatus == ConnectionStatus.connected
        ? 'Connected'
        : connectionStatus == ConnectionStatus.connecting
            ? 'Connecting'
            : connectionStatus == ConnectionStatus.reconnecting
                ? 'Reconnecting'
                : 'Disconnected';

    final statusColor = connectionStatus == ConnectionStatus.connected
        ? Colors.greenAccent
        : connectionStatus == ConnectionStatus.disconnected
            ? Colors.redAccent
            : Colors.amberAccent;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Bar ─────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Connection status chip
                  StatusChip(label: statusLabel, color: statusColor),
                  const SizedBox(width: 10),
                  // Controller IP
                  Expanded(
                    child: Text(
                      'IP $controllerIpValue',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // WebRTC indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'WebRTC',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Settings
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings, color: Colors.white70, size: 22),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ),

            // ─── Status Bar ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                elevation: 0,
                child: Row(
                  children: [
                    // State / Alert from backend
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'State · ${_modeLabel(activeMode)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hazardState,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: hazardState.toLowerCase().contains('alert')
                                  ? Colors.redAccent
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Frame age placeholder
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'frame-age',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          frameAge,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ─── Main Camera Feed ────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: const LiveCameraPreview(height: null),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ─── Mode Switcher Circles ───────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ModeCircleButton(
                    label: 'Danger\nDetection',
                    icon: Icons.shield,
                    isActive: activeMode == 'danger',
                    activeColor: Colors.redAccent,
                    onTap: () => _switchMode('danger'),
                  ),
                  _ModeCircleButton(
                    label: 'Sign\nLanguage',
                    icon: Icons.sign_language,
                    isActive: activeMode == 'sign',
                    onTap: isAlert ? null : () => _switchMode('sign'),
                  ),
                  _ModeCircleButton(
                    label: 'Face\nRecognition',
                    icon: Icons.face_retouching_natural,
                    isActive: activeMode == 'face',
                    onTap: isAlert ? null : () => _switchMode('face'),
                  ),
                  _ModeCircleButton(
                    label: 'Image\nCaptioning',
                    icon: Icons.image_search,
                    isActive: activeMode == 'caption',
                    onTap: isAlert ? null : () => _switchMode('caption'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ─── Mode Circle Button Widget ───────────────────────────────────────────────

class _ModeCircleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;
  final Color? activeColor;

  const _ModeCircleButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onTap != null;
    final Color effectiveActiveColor =
        activeColor ?? Theme.of(context).colorScheme.primary;
    
    final Color borderColor = isActive
        ? effectiveActiveColor
        : isEnabled
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.08);

    final Color bgColor = isActive
        ? effectiveActiveColor.withValues(alpha: 0.15)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isActive
                  ? effectiveActiveColor
                  : isEnabled
                      ? Colors.white70
                      : Colors.white24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? effectiveActiveColor
                  : isEnabled
                      ? Colors.white60
                      : Colors.white24,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
