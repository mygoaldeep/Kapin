import 'package:flutter/material.dart';

import '../models/records.dart';
import '../services/app_services.dart';
import '../services/links.dart';
import '../widgets/common.dart';

/// Builds the "follow me" text for a live share.
String liveShareMessage(String code, {String? lead}) =>
    '${lead ?? 'I\'m sharing my live location with you on Kapin.'}\n'
    'Open Kapin > Track and enter this code: $code';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _s = AppServices.current;

  Future<void> _edit([FamilyMember? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    var relation = existing?.relation ?? 'family';
    var emergency = existing?.isEmergency ?? false;
    final formKey = GlobalKey<FormState>();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom + 20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'Add person' : 'Edit person',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) => (v == null || v.trim().length < 5) ? 'Enter a phone number' : null,
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'family', label: Text('Family'), icon: Icon(Icons.family_restroom)),
                    ButtonSegment(value: 'friend', label: Text('Friend'), icon: Icon(Icons.people_outline)),
                  ],
                  selected: {relation},
                  onSelectionChanged: (s) => setSheet(() => relation = s.first),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Emergency contact'),
                  subtitle: const Text('Gets your SOS message'),
                  value: emergency,
                  onChanged: (v) => setSheet(() => emergency = v),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true) return;
    final m = FamilyMember(
      id: existing?.id ?? newId(),
      name: name.text.trim(),
      phone: phone.text.trim(),
      relation: relation,
      isEmergency: emergency,
    );
    if (existing == null) {
      await _s.family.add(m);
    } else {
      await _s.family.replaceWhere((x) => x.id == existing.id, m);
    }
  }

  Future<void> _shareLive(FamilyMember m) async {
    toast(context, 'Getting your location\u2026');
    final session = await _s.share.ensureSharing(const Duration(hours: 1));
    if (!mounted) return;
    if (session == null) {
      toast(context, _s.share.error ?? 'Could not get your location.');
      return;
    }
    await composeSms(context, [m.phone], liveShareMessage(session.id));
  }

  void _actions(FamilyMember m) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_location),
              title: Text('Share my live location with ${m.name}'),
              subtitle: const Text('Sends a Kapin code by text message for 1 hour'),
              onTap: () {
                Navigator.pop(ctx);
                _shareLive(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Call'),
              onTap: () {
                Navigator.pop(ctx);
                dial(context, m.phone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Message'),
              onTap: () {
                Navigator.pop(ctx);
                composeSms(context, [m.phone], '');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _edit(m);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              title: Text('Remove', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _s.family.removeWhere((x) => x.id == m.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Family & friends')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add person'),
      ),
      body: ListenableBuilder(
        listenable: _s.family,
        builder: (context, _) {
          final items = _s.family.items;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.family_restroom_rounded,
              title: 'Add your people',
              message:
                  'Add family and friends to send them your live location, check-ins and SOS messages. Contacts are stored on this phone.',
            );
          }
          return ListView.separated(
            padding: listPadding(context).copyWith(bottom: MediaQuery.paddingOf(context).bottom + 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = items[i];
              return Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  onTap: () => _actions(m),
                  leading: CircleAvatar(
                    backgroundColor: m.relation == 'family'
                        ? scheme.primaryContainer
                        : scheme.tertiaryContainer,
                    child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${m.relation == 'family' ? 'Family' : 'Friend'} \u00b7 ${m.phone}'),
                  trailing: m.isEmergency
                      ? Tooltip(
                          message: 'Emergency contact',
                          child: Icon(Icons.emergency_share_outlined, color: scheme.error),
                        )
                      : const Icon(Icons.more_horiz),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
