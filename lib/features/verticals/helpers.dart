// DDE-Mart customer app — shared vertical helpers (original).

import 'package:flutter/material.dart';

import '../../core/api_client.dart';

/// Single decoded JSON object.
Map<String, dynamic> apiItem(Map e) => Map<String, dynamic>.from(e);

/// Decoded `data` list (paginated or plain).
List<Map<String, dynamic>> apiList(Object? data) =>
    ((data as List?) ?? []).map((e) => apiItem(e as Map)).toList();

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
