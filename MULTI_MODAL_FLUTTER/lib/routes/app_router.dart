import 'package:go_router/go_router.dart';

import '../features/dashboard/dashboard_screen.dart';
import '../features/danger_detection/danger_detection_screen.dart';
import '../features/face_recognition/face_recognition_screen.dart';
import '../features/sign_language/sign_language_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/emergency/emergency_screen.dart';
import '../features/face_recognition/face_list_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(
      path: '/danger',
      builder: (context, state) => const DangerDetectionScreen(),
    ),
    GoRoute(
      path: '/face',
      builder: (context, state) => const FaceRecognitionScreen(),
    ),
    GoRoute(
      path: '/sign',
      builder: (context, state) => const SignLanguageScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/emergency',
      builder: (context, state) => const EmergencyScreen(),
    ),
    GoRoute(
      path: '/face/list',
      builder: (context, state) => const FaceListScreen(),
    ),
  ],
);
