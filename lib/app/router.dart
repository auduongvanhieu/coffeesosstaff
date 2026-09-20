import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/pos/presentation/pos_home_page.dart';

abstract final class Routes {
  static const login = '/login';
  static const pos = '/';
}

/// Rebuilds GoRouter's redirect when the auth state changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.pos,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      // Cold start: still validating stored token. Stay put, splash below.
      if (auth.isLoading && !auth.hasValue) return null;

      final signedIn = auth.value != null;
      final onLogin = state.matchedLocation == Routes.login;
      if (!signedIn && !onLogin) return Routes.login;
      if (signedIn && onLogin) return Routes.pos;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.pos, builder: (_, _) => const _AuthGate(child: PosHomePage())),
    ],
  );
});

/// Shows a splash while the stored session is being restored.
class _AuthGate extends ConsumerWidget {
  const _AuthGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.isLoading && !auth.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return child;
  }
}
