// DDE-Mart customer app — router + launch gate (original).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/api_client.dart';
import 'core/auth_store.dart';
import 'core/config.dart';
import 'core/gate.dart';
import 'features/account/profile_screen.dart';
import 'features/auth/account_screens.dart';
import 'features/auth/login_screen.dart';
import 'features/cart/cart_screens.dart';
import 'features/catalog/browse_screens.dart';
import 'features/content/pages.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding.dart';
import 'features/orders/order_success.dart';
import 'features/orders/orders.dart';
import 'features/reviews/reviews.dart';
import 'features/support/support.dart';
import 'features/verticals/life.dart';
import 'features/verticals/rental_ride.dart';
import 'features/verticals/transport.dart';
import 'features/wallet/wallet.dart';

/// Fetches GET /app-config and decides the launch gate. Refreshable so the
/// maintenance screen can retry without restarting the app.
final launchGateProvider = FutureProvider<GateDecision>((ref) async {
  final dio = ref.watch(dioProvider);
  final info = await PackageInfo.fromPlatform();

  try {
    final response = await dio.get('/app-config');
    final config = LaunchConfig.fromJson(
      Map<String, dynamic>.from((response.data as Map)['data'] as Map),
    );
    return gateStatus(
      current: info.version,
      minimum: config.minVersions[AppConfig.audience] ?? '1.0.0',
      maintenance: config.maintenance,
    );
  } on DioException {
    // Backend unreachable (emulator without host, airplane mode): let the
    // user in — every screen handles its own errors with retry.
    return GateDecision.ok;
  }
});

/// Bumps whenever auth or the launch gate changes so the router re-runs its
/// redirect without ever recreating the [GoRouter] itself. Recreating the
/// router mid-session (the old `ref.watch` approach) swaps Navigator
/// delegates under live pages and corrupts the tree with duplicate keys
/// (`!keyReservation.contains(key)` red screens).
final _routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final bump = ValueNotifier(0);
  ref.listen<AuthState>(authStoreProvider, (prev, next) {
    if (prev?.signedIn != next.signedIn) bump.value++;
  });
  ref.listen<AsyncValue<GateDecision>>(
      launchGateProvider, (prev, next) {
    if (prev?.valueOrNull != next.valueOrNull) bump.value++;
  });
  ref.onDispose(bump.dispose);
  return bump;
});

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/start',
    refreshListenable: ref.watch(_routerRefreshProvider),
    onException: (context, state, router) {
      // ignore: avoid_print
      print(
          'ROUTER_EXCEPTION uri=${state.uri} matched=${state.matchedLocation} '
          'stack=${router.routerDelegate.currentConfiguration.matches.map((m) => m.matchedLocation).toList()}');
      router.go('/home');
    },
    redirect: (context, state) {
      final auth = ref.read(authStoreProvider);
      final gate = ref.read(launchGateProvider);
      final location = state.matchedLocation;

      if (gate.valueOrNull == GateDecision.maintenance && location != '/maintenance') {
        return '/maintenance';
      }
      if (gate.valueOrNull == GateDecision.updateRequired && location != '/update') {
        return '/update';
      }

      const public = [
        '/start', '/login', '/register', '/otp', '/forgot',
        '/onboarding', '/location-enable', '/maintenance', '/update',
      ];
      if (!auth.signedIn && !public.any(location.startsWith)) {
        return '/login';
      }
      if (auth.signedIn && (location == '/login' || location == '/')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/start', builder: (context, state) => const StartupScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(
        path: '/location-enable',
        builder: (context, state) => const LocationEnableScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/pages', builder: (context, state) => const PagesScreen()),
      GoRoute(
        path: '/page/:slug',
        builder: (context, state) => PageDetailScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
          GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
          GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
          GoRoute(path: '/wallet', builder: (context, state) => const WalletScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => EditProfileScreen(
          initial: state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null,
        ),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return CategoriesScreen(
            sectionId: params['section'] == null ? null : int.tryParse(params['section']!),
            sectionName: params['name'],
          );
        },
      ),
      GoRoute(
        path: '/stores',
        builder: (context, state) => const StoresScreen(),
      ),
      GoRoute(
        path: '/category/:id',
        builder: (context, state) => CategoryProductsScreen(
          categoryId: int.parse(state.pathParameters['id']!),
          name: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(
        path: '/store/:id',
        builder: (context, state) => StoreScreen(
          storeId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => ProductScreen(
          productId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/product/:id/reviews',
        builder: (context, state) => ReviewsScreen(
          productId: int.parse(state.pathParameters['id']!),
          title: 'Product reviews',
        ),
      ),
      GoRoute(
        path: '/store/:id/reviews',
        builder: (context, state) => ReviewsScreen(
          storeId: int.parse(state.pathParameters['id']!),
          title: 'Store reviews',
        ),
      ),
      GoRoute(
        path: '/my-reviews',
        builder: (context, state) => const MyReviewsScreen(),
      ),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutScreen()),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) => OrderDetailScreen(
          orderId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/order-success/:id',
        builder: (context, state) => OrderSuccessScreen(
          orderId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/services', builder: (context, state) => const ServicesHubScreen()),
      GoRoute(path: '/parcel', builder: (context, state) => const ParcelScreen()),
      GoRoute(path: '/parcel/orders', builder: (context, state) => const ParcelOrdersScreen()),
      GoRoute(
        path: '/parcel/order/:id',
        builder: (context, state) => ParcelTrackScreen(
          orderId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/rental', builder: (context, state) => const RentalScreen()),
      GoRoute(path: '/rental/orders', builder: (context, state) => const RentalOrdersScreen()),
      GoRoute(
        path: '/rental/order/:id',
        builder: (context, state) => RentalTrackScreen(
          orderId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/ride', builder: (context, state) => const RideScreen()),
      GoRoute(path: '/rides', builder: (context, state) => const RidesScreen()),
      GoRoute(
        path: '/ride/:id',
        builder: (context, state) => RideTrackScreen(
          rideId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/life/services', builder: (context, state) => const LifeServicesScreen()),
      GoRoute(
        path: '/life/services/:cid',
        builder: (context, state) => LifeServiceListScreen(
          categoryId: int.parse(state.pathParameters['cid']!),
        ),
      ),
      GoRoute(
        path: '/life/service/:id',
        builder: (context, state) => LifeServiceBookScreen(
          serviceId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/life/bookings', builder: (context, state) => const LifeBookingsScreen()),
      GoRoute(
        path: '/life/booking/:id',
        builder: (context, state) => LifeBookingTrackScreen(
          bookingId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/life/dinein', builder: (context, state) => const DineinScreen()),
      GoRoute(path: '/life/gifts', builder: (context, state) => const GiftsScreen()),
      GoRoute(path: '/life/favorites', builder: (context, state) => const FavoritesScreen()),
      GoRoute(path: '/life/chat', builder: (context, state) => const ChatThreadsScreen()),
      GoRoute(
        path: '/life/chat/new',
        builder: (context, state) => const ChatThreadScreen(),
      ),
      GoRoute(
        path: '/life/chat/:id',
        builder: (context, state) => ChatThreadScreen(
          threadId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: '/life/safety', builder: (context, state) => const SafetyScreen()),
      GoRoute(path: '/life/safety/sos', builder: (context, state) => const SosRaiseScreen()),
      GoRoute(path: '/life/complaints', builder: (context, state) => const ComplaintsScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) => OtpScreen(phone: state.extra as String?),
      ),
      GoRoute(path: '/forgot', builder: (context, state) => const ForgotScreen()),
      GoRoute(path: '/maintenance', builder: (context, state) => const MaintenanceScreen()),
      GoRoute(path: '/update', builder: (context, state) => const UpdateScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    var index = 0;
    if (location.startsWith('/search')) {
      index = 1;
    } else if (location.startsWith('/cart') || location.startsWith('/checkout')) {
      index = 2;
    } else if (location.startsWith('/order')) {
      index = 3;
    } else if (location.startsWith('/wallet')) {
      index = 4;
    } else if (location.startsWith('/profile')) {
      index = 5;
    }

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          switch (value) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/search');
            case 2:
              context.go('/cart');
            case 3:
              context.go('/orders');
            case 4:
              context.go('/wallet');
            case 5:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search_outlined), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.wallet_outlined), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('DDE-Mart is under maintenance', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(launchGateProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_outlined, size: 64),
              SizedBox(height: 16),
              Text(
                'Please update DDE-Mart to continue.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
