// DDE-Mart customer app — profile hub + edit profile (original).
//
// Identity header (avatar, name, phone), grouped rows mirroring the legacy
// hub: account (edit/orders/bookings/favorites/gifts/reviews), preferences
// (appearance, addresses), support (chat/help/rate/share), legal, version,
// logout with confirm and store-compliant deletion.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/nav.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../auth/auth_api.dart';

final meProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/me');
  return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to order.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(authApiProvider).logout();
    } catch (_) {
      // Token may already be dead — still sign out locally.
    } finally {
      await ref.read(pushServiceProvider).unregister();
      await ref.read(authStoreProvider.notifier).signOut();
      if (mounted) context.go('/login');
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This permanently removes your account. Orders keep their receipts.'),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (if you set one)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final text = _password.text;
      await ref.read(authApiProvider).deleteAccount(
            password: text.isEmpty ? null : text,
          );
      await ref.read(pushServiceProvider).unregister();
      await ref.read(authStoreProvider.notifier).signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rateApp() async {
    final url = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.ddemart.dde_customer');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the store.')),
        );
      }
    }
  }

  Future<void> _shareApp() async {
    await Clipboard.setData(const ClipboardData(
        text:
            'Order food, parcels, rides and services on DDE-Mart: https://play.google.com/store/apps/details?id=com.ddemart.dde_customer'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App link copied.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(apiMessage(e))),
        data: (data) {
          final name = '${data['name'] ?? ''}';
          final initial =
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      context.safePush('/profile/edit', extra: data),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          child: Text(initial,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge),
                              Text('${data['phone'] ?? ''}'),
                              if ('${data['email'] ?? ''}'
                                  .isNotEmpty)
                                Text('${data['email']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_outlined),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionLabel('My activity'),
              _HubTile(
                icon: Icons.receipt_long_outlined,
                title: 'My orders',
                onTap: () => context.safePush('/orders'),
              ),
              _HubTile(
                icon: Icons.local_shipping_outlined,
                title: 'Parcel orders',
                onTap: () => context.safePush('/parcel/orders'),
              ),
              _HubTile(
                icon: Icons.car_rental_outlined,
                title: 'Rental orders',
                onTap: () => context.safePush('/rental/orders'),
              ),
              _HubTile(
                icon: Icons.local_taxi_outlined,
                title: 'My rides',
                onTap: () => context.safePush('/rides'),
              ),
              _HubTile(
                icon: Icons.home_repair_service_outlined,
                title: 'Service bookings',
                onTap: () => context.safePush('/life/bookings'),
              ),
              _HubTile(
                icon: Icons.restaurant_outlined,
                title: 'Dine-in',
                onTap: () => context.safePush('/life/dinein'),
              ),
              _HubTile(
                icon: Icons.favorite_outline,
                title: 'Favorites',
                onTap: () => context.safePush('/life/favorites'),
              ),
              _HubTile(
                icon: Icons.card_giftcard_outlined,
                title: 'Gifts',
                onTap: () => context.safePush('/life/gifts'),
              ),
              _HubTile(
                icon: Icons.star_outline,
                title: 'My reviews',
                onTap: () => context.safePush('/my-reviews'),
              ),
              const SizedBox(height: 8),
              _SectionLabel('Preferences'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('Appearance',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall),
                      const SizedBox(height: 8),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('Auto')),
                          ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light')),
                          ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark')),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (set) => ref
                            .read(themeModeProvider.notifier)
                            .set(set.first),
                      ),
                    ],
                  ),
                ),
              ),
              _HubTile(
                icon: Icons.location_on_outlined,
                title: 'Delivery addresses',
                onTap: () =>
                    context.safePush('/location-enable'),
              ),
              const SizedBox(height: 8),
              _SectionLabel('Support'),
              _HubTile(
                icon: Icons.chat_outlined,
                title: 'Support chat',
                onTap: () => context.safePush('/life/chat'),
              ),
              _HubTile(
                icon: Icons.help_outline,
                title: 'Help & policies',
                onTap: () => context.safePush('/pages'),
              ),
              _HubTile(
                icon: Icons.star_outline,
                title: 'Rate the app',
                onTap: _rateApp,
              ),
              _HubTile(
                icon: Icons.share_outlined,
                title: 'Share the app',
                onTap: _shareApp,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _busy ? null : _logout,
                child: const Text('Log out'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red),
                onPressed: _busy ? null : _delete,
                child: const Text('Delete account'),
              ),
              const SizedBox(height: 16),
              const _VersionFooter(),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '';
        return Center(
          child: Text(
            version.isEmpty ? '' : 'v$version',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }
}

/// Edit name + email (phone is the identity and stays read-only).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, this.initial});

  final Map<String, dynamic>? initial;

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name =
        TextEditingController(text: '${widget.initial?['name'] ?? ''}');
    _email =
        TextEditingController(text: '${widget.initial?['email'] ?? ''}');
    _phone.text = '${widget.initial?['phone'] ?? ''}';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authApiProvider).updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim().isEmpty
                ? null
                : _email.text.trim(),
          );
      ref.invalidate(meProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration:
                const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration:
                const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Phone (cannot be changed)',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save details'),
          ),
        ],
      ),
    );
  }
}
