import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/live_camera_preview.dart';

class FaceRecognitionScreen extends ConsumerWidget {
  const FaceRecognitionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String>(activeModeProvider, (previous, next) {
      if (next == 'danger') {
        if (context.mounted) {
          context.go('/');
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/face/list'),
            icon: const Icon(Icons.list),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/emergency'),
        icon: const Icon(Icons.warning),
        label: const Text('SOS'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const LiveCameraPreview(),
                    const SizedBox(height: 16),
                    const Text(
                      'Current recognition result',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Consumer(builder: (context, ref, child) {
                      final faceState = ref.watch(faceStateProvider);
                      final isRegistering = faceState.status == 'registering';
                      final isIdentified = faceState.status == 'identified';
                      
                      String titleText = 'No face detected';
                      if (isRegistering) {
                         titleText = 'Registering...';
                      } else if (isIdentified && faceState.personId != null) {
                         titleText = '${faceState.personId} detected';
                      } else if (faceState.status == 'failed') {
                         titleText = 'Recognition failed';
                      }

                      String confText = '';
                      if (isIdentified && faceState.confidence != null) {
                         confText = '${(faceState.confidence! * 100).toStringAsFixed(1)}%';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                titleText,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (confText.isNotEmpty)
                                Text(
                                  confText,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            faceState.message ?? 'Waiting for input...',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Consumer(builder: (context, ref, child) {
                  final faceState = ref.watch(faceStateProvider);
                  final isRegistering = faceState.status == 'registering';
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Face Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isRegistering ? null : () async {
                                final name = await showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    final controller = TextEditingController();
                                    return AlertDialog(
                                      title: const Text('Enter Name'),
                                      content: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(hintText: 'Person Name'),
                                        autofocus: true,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, controller.text),
                                          child: const Text('Register'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                
                                if (name != null && name.trim().isNotEmpty) {
                                  ref.read(controllerSessionProvider).webSocket.send({
                                    'type': 'face_intent',
                                    'intent': 'start_registration',
                                    'metadata': {'person_id': name.trim()},
                                  });
                                }
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Register'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isRegistering ? null : () {
                                ref.read(controllerSessionProvider).webSocket.send({
                                  'type': 'face_intent',
                                  'intent': 'identify',
                                });
                              },
                              icon: const Icon(Icons.search),
                              label: const Text('Identify'),
                            ),
                          ),
                        ],
                      ),
                      if (isRegistering) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2)),
                            onPressed: () {
                              ref.read(controllerSessionProvider).webSocket.send({
                                'type': 'face_intent',
                                'intent': 'cancel_registration',
                              });
                            },
                            icon: const Icon(Icons.cancel, color: Colors.redAccent),
                            label: const Text('Cancel Registration', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/face/list'),
                          icon: const Icon(Icons.manage_accounts),
                          label: const Text('Manage profiles'),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
