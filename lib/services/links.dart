import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

String mapsLink(double lat, double lng) =>
    'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

Uri directionsUri(double lat, double lng) => Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}');

void toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> openUri(BuildContext context, Uri uri, {String failMessage = 'Could not open that.'}) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) toast(context, failMessage);
    return ok;
  } catch (_) {
    toast(context, failMessage);
    return false;
  }
}

/// Opens the messaging app with the text filled in. The user still taps Send.
Future<bool> composeSms(BuildContext context, List<String> phones, String body) {
  final nums = phones.where((p) => p.trim().isNotEmpty).map((p) => p.trim()).join(',');
  final uri = Uri.parse('sms:$nums?body=${Uri.encodeComponent(body)}');
  return openUri(context, uri, failMessage: 'Could not open the messaging app.');
}

Future<bool> dial(BuildContext context, String number) =>
    openUri(context, Uri(scheme: 'tel', path: number), failMessage: 'Could not open the dialer.');
