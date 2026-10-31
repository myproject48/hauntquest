import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/navigation/mist_route.dart';
import '../../core/theme/app_colors.dart';
import '../intro/intro_screen.dart';

/// Every route that can replace a journey shares the same confirmation.
Future<void> beginNewGame(BuildContext context) async {
  final game = AppScope.of(context).game;
  if (game.needsNewGameConfirmation) {
    final restart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('Begin a new quest?'),
        content: const Text(
          'Your current saved journey will be replaced. Choose Continue on the title screen to return to it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep my journey'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (restart != true || !context.mounted) return;
  }
  if (context.mounted) await context.pushMist(const IntroScreen());
}
