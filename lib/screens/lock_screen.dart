import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_lock.dart';
import '../theme/theme.dart';
import '../widgets/inky.dart';

/// Shown over everything while the app lock is engaged.
class LockGate extends StatelessWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locked = context.select<AppLockController, bool>((l) => l.locked);
    return Stack(
      children: [
        ExcludeSemantics(excluding: locked, child: child),
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    // Only prompt while we're actually in the foreground.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    await context.read<AppLockController>().unlock();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = context.select<AppLockController, String?>((l) => l.lastError);
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Inky(size: 128, face: InkyFace.covering, semanticLabel: 'Inky covering its eyes'),
                const SizedBox(height: 20),
                Text('Inkling is locked', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Inky’s covering its eyes until you unlock 🙈',
                  textAlign: TextAlign.center,
                  style: handStyle(23, color: scheme.onSurfaceVariant, weight: FontWeight.w500),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
