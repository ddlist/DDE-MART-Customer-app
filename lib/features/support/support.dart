// DDE-Mart customer app — support (original).
//
// Support chat (threads/list/send with staff replies), complaints filing and
// SOS raising. Matches /chat/*, /complaints*, /sos.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../verticals/helpers.dart';

class SupportApi {
  SupportApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> threads() async {
    final r = await _dio.get('/chat/threads');
    return apiList((r.data as Map)['data']);
  }

  Future<Map<String, dynamic>> thread(int id) async {
    final r = await _dio.get('/chat/threads/$id');
    return apiItem((r.data as Map)['data'] as Map);
  }

  Future<int> send({int? threadId, String? subject, required String message}) async {
    final r = await _dio.post('/chat/send', data: cleanMap({
      'thread_id': threadId,
      'subject': subject,
      'message': message,
    }));
    return (((r.data as Map)['data'] as Map)['thread_id'] as num).toInt();
  }

  Future<void> complaint({
    required String title,
    required String description,
    String? orderRef,
  }) async {
    await _dio.post('/complaints', data: {
      'title': title,
      'description': description,
      if (orderRef != null && orderRef.isNotEmpty) 'order_ref': orderRef,
    });
  }

  Future<List<Map<String, dynamic>>> complaints() async {
    final r = await _dio.get('/complaints');
    return apiList((r.data as Map)['data']);
  }

  Future<void> sos({
    required double latitude,
    required double longitude,
    String? orderRef,
  }) async {
    await _dio.post('/sos', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (orderRef != null && orderRef.isNotEmpty) 'order_ref': orderRef,
    });
  }
}

final supportApiProvider = Provider<SupportApi>(
  (ref) => SupportApi(ref.watch(dioProvider)),
);

class ChatThreadsScreen extends ConsumerWidget {
  const ChatThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support chat')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/life/chat/new'),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.watch(supportApiProvider).threads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(apiMessage(snapshot.error!)));
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No conversations. Start one with +.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text('${row['subject'] ?? 'Conversation'}'),
                    subtitle: Text('${row['last_message'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/life/chat/${row['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, this.threadId});

  /// Null = new conversation (subject asked inline).
  final int? threadId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  Map<String, dynamic>? _thread;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.threadId != null) _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _thread = await ref.read(supportApiProvider).thread(widget.threadId!);
    } catch (e) {
      if (mounted) failSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;

    setState(() => _busy = true);
    try {
      final id = await ref.read(supportApiProvider).send(
            threadId: _thread?['id'] as int? ?? widget.threadId,
            subject: _subject.text.trim(),
            message: text,
          );
      _message.clear();
      if (widget.threadId == null && mounted) {
        context.pushReplacement('/life/chat/$id');
      } else {
        await _load();
      }
    } catch (e) {
      if (mounted) failSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _thread == null ? [] : apiList(_thread!['messages']);

    return Scaffold(
      appBar: AppBar(title: Text('${_thread?['subject'] ?? 'New conversation'}')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('No messages yet.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final message in messages)
                            Align(
                              alignment: (message['from_me'] ?? false) == true
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Card(
                                color: (message['from_me'] ?? false) == true
                                    ? Colors.green.shade100
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text('${message['body']}'),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (widget.threadId == null && _thread == null)
                  TextField(
                    controller: _subject,
                    decoration: const InputDecoration(labelText: 'Subject'),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        decoration: const InputDecoration(labelText: 'Message'),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _busy ? null : _send,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;
  List<Map<String, dynamic>> _mine = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(supportApiProvider).complaints();
      if (mounted) setState(() => _mine = rows);
    } catch (e) {
      if (mounted) failSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaints')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'What happened?'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await ref.read(supportApiProvider).complaint(
                            title: _title.text.trim(),
                            description: _description.text.trim(),
                          );
                      _title.clear();
                      _description.clear();
                      await _load();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Complaint filed.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) failSnack(context, e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'Filing…' : 'File complaint'),
          ),
          const SizedBox(height: 16),
          Text('My complaints', style: Theme.of(context).textTheme.titleMedium),
          for (final row in _mine)
            Card(
              child: ListTile(
                title: Text('${row['title']}'),
                trailing: Text('${row['status']}'),
              ),
            ),
        ],
      ),
    );
  }
}

class SosRaiseScreen extends ConsumerStatefulWidget {
  const SosRaiseScreen({super.key});

  @override
  ConsumerState<SosRaiseScreen> createState() => _SosRaiseScreenState();
}

class _SosRaiseScreenState extends ConsumerState<SosRaiseScreen> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Sends your location to DDE-Mart safety staff.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.my_location_outlined),
            label: const Text('Use my location'),
            onPressed: _busy
                ? null
                : () async {
                    var permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                    }
                    if (permission == LocationPermission.denied ||
                        permission == LocationPermission.deniedForever) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location permission denied — enter manually.'),
                          ),
                        );
                      }
                      return;
                    }
                    try {
                      final position = await Geolocator.getCurrentPosition();
                      _lat.text = '${position.latitude}';
                      _lng.text = '${position.longitude}';
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not fix location.')),
                        );
                      }
                    }
                  },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Latitude'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lng,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(labelText: 'Longitude'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _busy
                ? null
                : () async {
                    final lat = double.tryParse(_lat.text.trim());
                    final lng = double.tryParse(_lng.text.trim());
                    if (lat == null || lng == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter valid coordinates.')),
                      );
                      return;
                    }
                    setState(() => _busy = true);
                    try {
                      await ref.read(supportApiProvider).sos(latitude: lat, longitude: lng);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('SOS sent. Help is on the way.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) failSnack(context, e);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? 'Sending…' : 'SEND SOS'),
          ),
          TextButton(
            onPressed: () => context.push('/life/complaints'),
            child: const Text('File a complaint instead'),
          ),
        ],
      ),
    );
  }
}

/// Safety hub: SOS + complaints entry points.
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.sos_outlined, color: Colors.red),
              title: const Text('Emergency SOS'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/life/safety/sos'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Complaints'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/life/complaints'),
            ),
          ),
        ],
      ),
    );
  }
}
