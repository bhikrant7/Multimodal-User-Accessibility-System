import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';

import 'core/app_theme.dart';
import 'routes/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SentinelCompanionApp()));
}

class SentinelCompanionApp extends ConsumerStatefulWidget {
  const SentinelCompanionApp({super.key});

  @override
  ConsumerState<SentinelCompanionApp> createState() =>
      _SentinelCompanionAppState();
}

class _SentinelCompanionAppState extends ConsumerState<SentinelCompanionApp> {
  @override
  void initState() {
    super.initState();
    // Load persisted websocket URL (if any) and set controller providers
    ref
        .read(preferencesProvider.future)
        .then((prefs) {
          final saved = prefs.getString('websocket_url');
          if (saved != null && saved.isNotEmpty) {
            try {
              final uri = Uri.parse(saved);
              if (uri.host.isNotEmpty) {
                ref.read(controllerIpProvider.notifier).state = uri.host;
              }
              if (uri.hasPort) {
                ref.read(controllerPortProvider.notifier).state = uri.port;
              }
            } catch (_) {
              // ignore parse errors
            }
          }
        })
        .catchError((_) {
          // ignore prefs errors
        });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(controllerSessionProvider);
    return MaterialApp.router(
      title: 'Sentinel Companion',
      theme: SentinelTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
