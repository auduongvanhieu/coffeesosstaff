import 'package:flutter/widgets.dart';

/// POS targets two form factors from one codebase:
/// tablet landscape (1280x800) and phone (390x844).
abstract final class Breakpoints {
  static const tablet = 840.0;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}

/// Picks a layout by width. Keeps screen widgets free of MediaQuery noise.
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({super.key, required this.phone, required this.tablet});

  final WidgetBuilder phone;
  final WidgetBuilder tablet;

  @override
  Widget build(BuildContext context) =>
      Breakpoints.isTablet(context) ? tablet(context) : phone(context);
}
