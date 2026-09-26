// DDE-Mart customer app — sign-in screen (original).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import 'auth_api.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final payload = await ref.read(authApiProvider).login(
            phone: _phone.text.trim(),
            password: _password.text,
          );
      await ref.read(authStoreProvider.notifier).signIn(
            token: '${payload['token']}',
            name: '${payload['name'] ?? ''}',
            phone: '${payload['phone'] ?? ''}',
          );
      if (mounted) context.go('/home');
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
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome back')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Signing in…' : 'Sign in'),
          ),
          TextButton(
            onPressed: () => context.push('/otp', extra: _phone.text.trim()),
            child: const Text('Use a code instead'),
          ),
          TextButton(
            onPressed: () => context.push('/forgot'),
            child: const Text('Forgot password'),
          ),
          TextButton(
            onPressed: () => context.push('/register'),
            child: const Text('Create account'),
          ),
        ],
      ),
    );
  }
}
