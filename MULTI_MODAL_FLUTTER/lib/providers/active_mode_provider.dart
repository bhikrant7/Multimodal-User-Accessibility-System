import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which detection mode is currently active.
///
/// Possible values: `'danger'`, `'sign'`, `'face'`, `'caption'`.
/// Defaults to `'danger'` (Danger Detection).
final activeModeProvider = StateProvider<String>((ref) => 'danger');
