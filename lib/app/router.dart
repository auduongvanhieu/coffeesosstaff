import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/device_context.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/pin_page.dart';
import '../features/pos/domain/order.dart';
import '../features/pos/presentation/app_orders_page.dart';
import '../features/pos/presentation/bill_detail_page.dart';
import '../features/pos/presentation/bills_page.dart';
import '../features/pos/presentation/cart_page.dart';
import '../features/pos/presentation/order_page.dart';
import '../features/pos/presentation/payment_page.dart';
import '../features/pos/presentation/pos_shell.dart';
import '../features/pos/presentation/shift_page.dart';
import '../features/pos/presentation/tables_page.dart';
import '../features/pos/presentation/sold_out_page.dart';

abstract final class Routes {
  static const login = '/login';
  static const pin = '/pin';
  static const order = '/';
  static const tables = '/tables';
  static const bills = '/bills';
  static const cart = '/cart';
  static const appOrders = '/app-orders';
  static const soldOut = '/sold-out';
  static const shift = '/shift';
  static String payment(String orderId) => '/payment/$orderId';
  static String bill(String orderId) => '/bills/$orderId';
}

/// Rebuilds GoRouter's redirect when the auth state or device binding changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(deviceContextProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.order,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      // Cold start: still validating stored token. Stay put, splash below.
      if (auth.isLoading && !auth.hasValue) return null;

      final signedIn = auth.value != null;
      final device = ref.read(deviceContextProvider);
      final loc = state.matchedLocation;
      final onAuth = loc == Routes.login || loc == Routes.pin;

      if (!signedIn) {
        if (onAuth) {
          return (loc == Routes.pin && device == null) ? Routes.login : null;
        }
        return device != null ? Routes.pin : Routes.login;
      }
      if (onAuth) return Routes.order;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.pin, builder: (_, _) => const PinPage()),
      ShellRoute(
        builder: (context, state, child) => _AuthGate(
          child: PosShell(location: state.matchedLocation, child: child),
        ),
        routes: [
          GoRoute(path: Routes.order, builder: (_, _) => const OrderPage()),
          GoRoute(path: Routes.tables, builder: (_, _) => const TablesPage()),
          GoRoute(path: Routes.bills, builder: (_, _) => const BillsPage()),
          GoRoute(
            path: Routes.appOrders,
            builder: (_, _) => const AppOrdersPage(),
          ),
          GoRoute(path: Routes.soldOut, builder: (_, _) => const SoldOutPage()),
          GoRoute(path: Routes.shift, builder: (_, _) => const ShiftPage()),
        ],
      ),
      GoRoute(
        path: Routes.cart,
        builder: (_, _) => const _AuthGate(child: CartPage()),
      ),
      GoRoute(
        path: '/bills/:orderId',
        builder: (_, state) => _AuthGate(
          child: BillDetailPage(orderId: state.pathParameters['orderId']!),
        ),
      ),
      GoRoute(
        path: '/payment/:orderId',
        builder: (_, state) => _AuthGate(
          child: PaymentPage(
            orderId: state.pathParameters['orderId']!,
            initial: state.extra is Order ? state.extra as Order : null,
          ),
        ),
      ),
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
