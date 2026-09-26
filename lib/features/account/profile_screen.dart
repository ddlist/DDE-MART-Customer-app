// DDE-Mart customer app — profile (original).
//
// Shows GET /me, with logout and store-compliant account deletion
// (DELETE /me, password confirmed when one is set).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/push.dart';
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
            const Text('This permanently removes your account. Orders keep their receipts.'),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
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

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final auth = ref.watch(authStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          me.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(apiMessage(e)),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${data['name'] ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
                Text('${data['phone'] ?? ''}'),
                if ('${data['email'] ?? ''}'.isNotEmpty) Text('${data['email']}'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Signed in as ${auth.phone ?? ''}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton.tonal(onPressed: _busy ? null : _logout, child: const Text('Sign out')),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _busy ? null : _delete,
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}
