import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/records.dart';
import '../services/app_services.dart';
import '../services/links.dart';
import '../services/location_service.dart';
import '../utils.dart';
import '../widgets/common.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _s = AppServices.current;
  final _note = TextEditingController();
  static const _statuses = <String, IconData>{
    'I\'m safe': Icons.verified_user_outlined,
    'Arrived': Icons.flag_outlined,
    'Home safe': Icons.home_outlined,
    'At work': Icons.work_outline,
    'Running late': Icons.schedule,
    'Need a pickup': Icons.directions_car_outlined,
  };
  String _status = 'I\'m safe';
  late final Set<String> _recipients = {for (final m in _s.family.items) m.id};
  bool _busy = false;
  HistoryEntry? _last;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    try {
      final p = _s.share.position ?? await LocationService.current();
      final address = _s.share.address.isNotEmpty
          ? _s.share.address
          : await LocationService.addressFor(p.latitude, p.longitude);
      final note = _note.text.trim();
      final label = note.isEmpty ? _status : '$_status \u2013 $note';
      await _s.logEvent(p.latitude, p.longitude, address, 'checkin', note: label);
      if (!mounted) return;
      setState(() {
        _last = _s.history.items.first;
        _busy = false;
      });

      final msg = 'Check-in: $label\n'
          '${address == 'Address unavailable' ? '' : '$address\n'}'
          '${mapsLink(p.latitude, p.longitude)}';
      final phones = [
        for (final m in _s.family.items)
          if (_recipients.contains(m.id)) m.phone
      ];
      if (phones.isNotEmpty) {
        await composeSms(context, phones, msg);
      } else {
        await Share.share(msg);
      }
    } on AppException catch (e) {
      toast(context, e.message);
    } catch (_) {
      toast(context, 'Could not check in. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Check in')),
      body: ListView(
        padding: listPadding(context),
        children: [
          Text('Let people know you\'re okay and where you are.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _statuses.entries)
                ChoiceChip(
                  avatar: Icon(e.value, size: 18),
                  label: Text(e.key),
                  selected: _status == e.key,
                  onSelected: (_) => setState(() => _status = e.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLength: 120,
            decoration: const InputDecoration(
                labelText: 'Add a note (optional)', prefixIcon: Icon(Icons.notes_outlined)),
          ),
          const SizedBox(height: 8),
          Text('Send to', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: _s.family,
            builder: (context, _) {
              final people = _s.family.items;
              if (people.isEmpty) {
                return Text(
                    'No contacts yet. Add people in Family & friends, or just share the check-in with any app.',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant));
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in people)
                    FilterChip(
                      label: Text(m.name),
                      selected: _recipients.contains(m.id),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _recipients.add(m.id);
                        } else {
                          _recipients.remove(m.id);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _checkIn,
            icon: _busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: const Text('Check in now'),
          ),
          if (_last != null) ...[
            const SizedBox(height: 16),
            SoftCard(
              color: scheme.primaryContainer,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Checked in at ${clockLabel(_last!.time)}',
                        style: TextStyle(
                            color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Recent check-ins', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: _s.history,
            builder: (context, _) {
              final recent = _s.history.items.where((h) => h.type == 'checkin').take(6).toList();
              if (recent.isEmpty) {
                return Text('Nothing yet.',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant));
              }
              return Column(
                children: [
                  for (final h in recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: scheme.secondaryContainer,
                        child: Icon(Icons.check, color: scheme.onSecondaryContainer),
                      ),
                      title: Text(h.note, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${dayLabel(h.time)}, ${clockLabel(h.time)}'
                          '${h.address.isEmpty ? '' : ' \u00b7 ${h.address}'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
