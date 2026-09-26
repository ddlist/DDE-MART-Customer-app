// DDE-Mart customer app — registration + OTP + password-reset screens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import 'auth_api.dart';
import 'auth_chrome.dart';

Future<void> _savePayload(WidgetRef ref, Map<String, dynamic> payload) {
  return ref.read(authStoreProvider.notifier).signIn(
        token: '${payload['token']}',
        name: '${payload['name'] ?? ''}',
        phone: '${payload['phone'] ?? ''}',
      );
}

void _fail(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(apiMessage(e))),
  );
}

/// Snackbar via a pre-captured messenger (lint-clean across async gaps).
void _failMsg(ScaffoldMessengerState messenger, Object e) {
  messenger.showSnackBar(SnackBar(content: Text(apiMessage(e))));
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const AuthHeader(
              title: 'Join DDE-Mart',
              subtitle: 'One account for food, rides and services.',
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (_name.text.trim().isEmpty ||
                                _phone.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter your name and phone.'),
                                ),
                              );
                              return;
                            }
                            setState(() => _busy = true);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await _savePayload(
                                ref,
                                await ref.read(authApiProvider).register(
                                      name: _name.text.trim(),
                                      phone: _phone.text.trim(),
                                    ),
                              );
                              if (context.mounted) {
                                context.go('/home');
                              }
                            } catch (e) {
                              _failMsg(messenger, e);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: Text(_busy ? 'Creating…' : 'Create account'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Have an account?'),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, this.phone});

  final String? phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  late final _phone = TextEditingController(text: widget.phone ?? '');
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await _savePayload(
        ref,
        await ref.read(authApiProvider).otpVerify(
              phone: _phone.text.trim(),
              code: code,
            ),
      );
      router.go('/home');
    } catch (e) {
      _failMsg(messenger, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const AuthHeader(
              title: 'Check your SMS',
              subtitle: 'Enter the 6-digit code we sent you.',
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final debug = await ref
                                  .read(authApiProvider)
                                  .otpRequest(_phone.text.trim());
                              if (!mounted) return;
                              setState(() => _sent = true);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    debug == null
                                        ? 'Code sent.'
                                        : 'Code sent (debug: $debug).',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (context.mounted) _fail(context, e);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: Text(_sent ? 'Resend code' : 'Send code'),
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Enter code',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    PinCodeField(onCompleted: _verify),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _reset(String code) async {
    if (_password.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type your new password first (min 8).')),
      );
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await _savePayload(
        ref,
        await ref.read(authApiProvider).passwordReset(
              phone: _phone.text.trim(),
              code: code,
              password: _password.text,
            ),
      );
      router.go('/home');
    } catch (e) {
      _failMsg(messenger, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const AuthHeader(
              title: 'Reset password',
              subtitle: 'We will text you a reset code.',
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await ref
                                  .read(authApiProvider)
                                  .passwordRequest(_phone.text.trim());
                              if (mounted) setState(() => _sent = true);
                            } catch (e) {
                              _failMsg(messenger, e);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Send reset code'),
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 24),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password (min 8)',
                        prefixIcon: Icon(Icons.lock_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter code',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    PinCodeField(onCompleted: _reset),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

