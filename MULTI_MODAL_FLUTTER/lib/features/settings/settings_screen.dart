import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../widgets/glass_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _stunController;

  @override
  void initState() {
    super.initState();
    final ip = ref.read(controllerIpProvider);
    final port = ref.read(controllerPortProvider);
    final stun = ref.read(webrtcStunServerProvider);

    _ipController = TextEditingController(text: ip);
    _portController = TextEditingController(text: port.toString());
    _stunController = TextEditingController(text: stun);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _stunController.dispose();
    super.dispose();
  }

  Future<void> _saveConnectionSettings() async {
    ref.read(controllerIpProvider.notifier).state = _ipController.text.trim();
    final portValue = int.tryParse(_portController.text.trim());
    if (portValue != null && portValue > 0) {
      ref.read(controllerPortProvider.notifier).state = portValue;
    }
    ref.read(webrtcStunServerProvider.notifier).state = _stunController.text
        .trim();

    // Persist websocket URL so it can be restored on app start
    final ip = ref.read(controllerIpProvider);
    final port = ref.read(controllerPortProvider);
    final wsUrl = 'ws://$ip:$port';
    try {
      final prefs = await ref.read(preferencesProvider.future);
      await prefs.setString('websocket_url', wsUrl);
    } catch (_) {
      // ignore persistence errors
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection settings updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ListView(
            children: [
              const Text(
                'Connection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'Controller IP',
                        hintText: '192.168.1.10',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'WebSocket Port',
                        hintText: '8765',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _stunController,
                      decoration: const InputDecoration(
                        labelText: 'WebRTC STUN server',
                        hintText: 'stun:stun.l.google.com:19302',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _saveConnectionSettings,
                      child: const Text('Save settings'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Accessibility',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    _SettingRow(label: 'Text size', value: 'Large'),
                    _SettingRow(label: 'High contrast mode', value: 'On'),
                    _SettingRow(label: 'Haptic feedback', value: 'On'),
                    _SettingRow(label: 'Voice feedback', value: 'On'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Audio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Alert Volume'),
                    Slider(value: 0.8, onChanged: (value) {}),
                    const Text('TTS Volume'),
                    Slider(value: 0.7, onChanged: (value) {}),
                    SwitchListTile(
                      value: true,
                      onChanged: (value) {},
                      title: const Text('Mute all audio'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Camera',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    _SettingRow(label: 'Resolution', value: '1280x720'),
                    _SettingRow(label: 'Camera selection', value: 'Rear'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;

  const _SettingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
