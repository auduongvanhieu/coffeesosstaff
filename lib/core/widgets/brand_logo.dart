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
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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

/// Rounded product photo with the beige placeholder used across the POS.
class ItemThumb extends StatelessWidget {
  const ItemThumb({
    super.key,
    required this.url,
    this.size = 44,
    this.radius = 10,
  });

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: url == null || url!.isEmpty
          ? Icon(
              Icons.local_cafe_outlined,
              size: size * 0.45,
              color: AppColors.primary.withValues(alpha: 0.5),
            )
          : Image.network(
              url!,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
    );
  }
}

/// Round staff photo; falls back to initials on teal so every account has a face.
class StaffAvatar extends StatelessWidget {
  const StaffAvatar({
    super.key,
    required this.initials,
    this.url,
    this.size = 36,
  });

  final String initials;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: url == null || url!.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.38,
              ),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.38,
                ),
              ),
            ),
    );
  }
}
