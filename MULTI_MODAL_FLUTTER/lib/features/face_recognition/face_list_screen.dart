import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/face_profile.dart';
import '../../widgets/glass_card.dart';

class FaceListScreen extends ConsumerWidget {
  const FaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = [
      FaceProfile(
        id: '1',
        name: 'John',
        tag: 'Friend',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      FaceProfile(
        id: '2',
        name: 'Mother',
        tag: 'Family',
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Face Profiles')),
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
                      'Manage enrolled faces',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Edit or remove profiles that the controller can recognize.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: profiles.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    return GlassCard(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(0),
                        title: Text(
                          profile.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${profile.tag} • added ${profile.createdAt.month}/${profile.createdAt.day}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.white70,
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
