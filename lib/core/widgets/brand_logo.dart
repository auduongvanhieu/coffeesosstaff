import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Terracotta circle with the brand logo (or plain, like the Figma frames).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64, this.url});

  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: url == null || url!.isEmpty
          ? null
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
    );
  }
}

/// Centered white card used by both login screens.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child, this.maxWidth = 340});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
