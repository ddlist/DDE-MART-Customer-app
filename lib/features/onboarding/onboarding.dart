// DDE-Mart customer app — onboarding + location enable (original).
//
// Onboarding slides come from GET /onboarding?audience=customer; completion
// is stored locally. Location (GPS fix or typed address, saved list) is
// stored locally and reused as parcel/rental/ride source addresses.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';

final onboardingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/onboarding', queryParameters: {
    'audience': 'customer',
  });
  return (((response.data as Map)['data'] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

Future<bool> onboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding.done') ?? false;
}

Future<void> setOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding.done', true);
}

/// First screen: sends first-timers through onboarding, guests to sign-in,
/// signed-in users home (maintenance/update gates run in the router).
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  @override
  void initState() {
    super.initState();
    // Defer past the first frame: navigating synchronously from initState
    // marks the Router dirty while it is still building (crash + stuck
    // spinner on real devices).
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    if (!mounted) return;
    final signedIn = ref.read(authStoreProvider).signedIn;
    final router = GoRouter.of(context);
    if (signedIn) {
      router.go('/home');
      return;
    }
    final done = await onboardingDone();
    if (!mounted) return;
    router.go(done ? '/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final router = GoRouter.of(context);
    await setOnboardingDone();
    router.go('/location-enable');
  }

  @override
  Widget build(BuildContext context) {
    final slides = ref.watch(onboardingProvider);

    return Scaffold(
      body: SafeArea(
        child: slides.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(apiMessage(e)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              // No slides configured — don't trap the user.
              Future.microtask(_finish);
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: rows.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) {
                      final slide = rows[index];
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (resolveAsset(slide['image'] as String?) != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.network(
                                  resolveAsset(slide['image'] as String?)!,
                                  height: 220,
                                  errorBuilder: (context, error, stack) =>
                                      const Icon(Icons.image_outlined, size: 120),
                                ),
                              )
                            else
                              const Icon(Icons.delivery_dining_outlined, size: 120),
                            const SizedBox(height: 32),
                            Text(
                              '${slide['title'] ?? ''}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${slide['description'] ?? ''}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      Container(
                        width: _page == i ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _page == i
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _finish,
                        child: const Text('Skip'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          if (_page == rows.length - 1) {
                            _finish();
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        child: Text(_page == rows.length - 1 ? 'Get started' : 'Next'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Saved delivery addresses, stored on-device.
class SavedAddresses extends StateNotifier<List<String>> {
  SavedAddresses() : super(const []) {
    _restore();
  }

  static const _key = 'addresses.v1';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? const [];
  }

  Future<void> add(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    state = [...state, trimmed];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state);
  }

  Future<void> remove(String address) async {
    state = state.where((a) => a != address).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state);
  }
}

final savedAddressesProvider =
    StateNotifierProvider<SavedAddresses, List<String>>(
  (ref) => SavedAddresses(),
);

class LocationEnableScreen extends ConsumerStatefulWidget {  const LocationEnableScreen({super.key});

  @override
  ConsumerState<LocationEnableScreen> createState() =>
      _LocationEnableScreenState();
}

class _LocationEnableScreenState
    extends ConsumerState<LocationEnableScreen> {
  final _manual = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Permission denied — type it instead.')),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      await ref.read(savedAddressesProvider.notifier).add(
            'GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
          );
      router.go('/home');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not fix location.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedAddressesProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.location_on_outlined, size: 72),
            const SizedBox(height: 16),
            Text(
              'Where are you?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'We use it for deliveries, rides and nearby stores.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.my_location_outlined),
              label: Text(_busy ? 'Locating…' : 'Use my location'),
              onPressed: _busy ? null : _useGps,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    decoration: const InputDecoration(
                      labelText: 'Or type an address',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    await ref
                        .read(savedAddressesProvider.notifier)
                        .add(_manual.text);
                    _manual.clear();
                    if (context.mounted) {
                      context.go('/home');
                    }
                  },
                ),
              ],
            ),
            if (saved.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Saved', style: Theme.of(context).textTheme.titleSmall),
              for (final address in saved)
                Card(
                  child: ListTile(
                    title: Text(address),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(savedAddressesProvider.notifier)
                          .remove(address),
                    ),
                    onTap: () => context.go('/home'),
                  ),
                ),
            ],
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}

