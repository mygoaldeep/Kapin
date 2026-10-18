import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_services.dart';
import '../services/links.dart';
import '../widgets/common.dart';
import 'family_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  final _s = AppServices.current;
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
        ..addStatusListener((st) {
          if (st == AnimationStatus.completed) _activate();
        });
  late final TextEditingController _number =
      TextEditingController(text: _s.settings.emergencyNumber);

  bool _active = false;
  bool _busy = false;
  bool _noLocation = false;
  String? _code;

  @override
  void dispose() {
    _hold.dispose();
    _number.dispose();
    super.dispose();
  }

  List<String> get _emergencyPhones =>
      [for (final m in _s.family.items) if (m.isEmergency) m.phone];

  String _message() {
    final p = _s.share.position;
    final b = StringBuffer('SOS! I need help.');
    if (p != null) {
      final a = _s.share.address;
      if (a.isNotEmpty && a != 'Address unavailable') b.write('\n$a');
      b.write('\n${mapsLink(p.latitude, p.longitude)}');
    }
    if (_code != null) b.write('\nLive location: Kapin > Track, code $_code');
    return b.toString();
  }

  Future<void> _sendMessage() async {
    final phones = _emergencyPhones;
    if (phones.isEmpty) {
      await Share.share(_message());
    } else {
      await composeSms(context, phones, _message());
    }
  }

  Future<void> _activate() async {
    if (_active || _busy) return;
    HapticFeedback.heavyImpact();
    setState(() => _busy = true);
    final session = await _s.share.ensureSharing(const Duration(hours: 8));
    final p = _s.share.position;
    if (p != null) {
      await _s.logEvent(p.latitude, p.longitude, _s.share.address, 'sos', note: 'SOS activated');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _active = true;
      _code = session?.id;
      _noLocation = p == null;
    });
    await _sendMessage();
  }

  Future<void> _imSafe() async {
    final p = _s.share.position;
    if (p != null) {
      await _s.logEvent(p.latitude, p.longitude, _s.share.address, 'checkin',
          note: 'SOS cancelled \u2013 I\'m safe');
    }
    await _s.share.stopSharing();
    if (!mounted) return;
    _hold.value = 0;
    setState(() {
      _active = false;
      _code = null;
    });
    final phones = _emergencyPhones;
    if (phones.isNotEmpty) {
      await composeSms(context, phones, 'False alarm \u2013 I\'m safe. Sorry for the scare.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    const sosRed = Color(0xFFD32F2F);

    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: ListView(
        padding: listPadding(context),
        children: [
          Text(
            _active
                ? 'SOS is active. Your live location is being shared.'
                : 'Press and hold the button for 2 seconds to alert your emergency contacts.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Center(
            child: Listener(
              onPointerDown: (_) {
                if (!_active && !_busy) {
                  HapticFeedback.mediumImpact();
                  _hold.forward(from: 0);
                }
              },
              onPointerUp: (_) {
                if (_hold.status != AnimationStatus.completed) _hold.reverse();
              },
              onPointerCancel: (_) {
                if (_hold.status != AnimationStatus.completed) _hold.reverse();
              },
              child: AnimatedBuilder(
                animation: _hold,
                builder: (context, _) {
                  return SizedBox(
                    width: 230,
                    height: 230,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: _hold.value,
                        color: sosRed,
                        track: scheme.outlineVariant,
                      ),
                      child: Center(
                        child: Container(
                          width: 184,
                          height: 184,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _active ? scheme.surfaceContainerHigh : sosRed,
                            boxShadow: [
                              BoxShadow(
                                color: sosRed.withValues(alpha: _active ? 0 : 0.35),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _busy
                                ? const CircularProgressIndicator(color: Colors.white)
                                : _active
                                    ? const Icon(Icons.check_rounded, size: 80, color: sosRed)
                                    : const Text('SOS',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 48,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_active) ...[
            SoftCard(
              color: scheme.errorContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SOS activated',
                      style: text.titleMedium?.copyWith(
                          color: scheme.onErrorContainer, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    _noLocation
                        ? 'We couldn\'t get your location. Call for help below.'
                        : 'Live location sharing is on for 8 hours. Code: ${_code ?? '-'}',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: sosRed, foregroundColor: Colors.white),
              onPressed: () => dial(context, _s.settings.emergencyNumber),
              icon: const Icon(Icons.call),
              label: Text('Call ${_s.settings.emergencyNumber}'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _sendMessage,
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Send SOS message again'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _imSafe,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('I\'m safe \u2013 stop SOS'),
            ),
          ] else ...[
            ListenableBuilder(
              listenable: _s.family,
              builder: (context, _) {
                final n = _emergencyPhones.length;
                return SoftCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const FamilyScreen())),
                    leading: Icon(Icons.emergency_share_outlined,
                        color: n == 0 ? scheme.error : scheme.primary),
                    title: Text(n == 0 ? 'No emergency contacts yet' : '$n emergency contact${n == 1 ? '' : 's'}'),
                    subtitle: Text(n == 0
                        ? 'Add people in Family & friends and mark them as emergency contacts.'
                        : 'They get your SOS message and a link to your location.'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _number,
                    keyboardType: TextInputType.phone,
                    onChanged: _s.settings.setEmergencyNumber,
                    decoration: const InputDecoration(
                      labelText: 'Local emergency number',
                      prefixIcon: Icon(Icons.local_phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Used by the Call button after SOS. Set the number for your country.',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Kapin opens your messaging app with the SOS text ready; you still tap Send. '
            'It cannot place calls or text for you in the background. In immediate danger, '
            'call your local emergency number first.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track});
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = track.withValues(alpha: 0.6);
    canvas.drawCircle(c, r, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
