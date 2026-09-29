// DDE-Mart customer app — shared vertical helpers (original).

import 'package:flutter/material.dart';

import '../../core/api_client.dart';

/// Single decoded JSON object.
Map<String, dynamic> apiItem(Map e) => Map<String, dynamic>.from(e);

/// Decoded `data` list (paginated or plain).
List<Map<String, dynamic>> apiList(Object? data) =>
    ((data as List?) ?? []).map((e) => apiItem(e as Map)).toList();

/// Tolerant id read for API-fed dropdowns: JSON numbers decode as int,
/// but string ids or nulls must degrade to null instead of throwing.
int? idAsInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

/// Error snackbar with the backend's message.
void failSnack(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(apiMessage(e))),
  );
}

/// Map without null/blank values (query params and POST bodies).
Map<String, Object> cleanMap(Map<String, Object?> values) {
  values.removeWhere((key, value) => value == null || value == '');
  return values.cast<String, Object>();
}

/// Human age of an ISO timestamp ("just now", "4 min ago", …).
String agoText(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final at = DateTime.tryParse(iso);
  if (at == null) return '—';
  final minutes = DateTime.now().difference(at).inMinutes;
  if (minutes < 1) return 'just now';
  if (minutes < 60) return '$minutes min ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours h ago';
  return '${hours ~/ 24} d ago';
}

/// Assigned-driver card with live position (null-safe: hides when unassigned).
class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.driver});

  final Map<String, dynamic>? driver;

  @override
  Widget build(BuildContext context) {
    final d = driver;
    if (d == null) return const SizedBox.shrink();

    final lat = (d['latitude'] as num?)?.toDouble();
    final lng = (d['longitude'] as num?)?.toDouble();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.delivery_dining_outlined),
        title: Text('Driver: ${d['name'] ?? '—'}'),
        subtitle: Text(
          lat == null || lng == null
              ? 'On the way (position pending)'
              : '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} · ${agoText(d['position_at'] as String?)}',
        ),
      ),
    );
  }
}
