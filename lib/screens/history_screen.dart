import 'package:flutter/material.dart';

import '../models/place_info.dart';
import '../models/records.dart';
import '../services/app_services.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'place_map_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static IconData _icon(String type) {
    switch (type) {
      case 'checkin':
        return Icons.check_circle_outline;
      case 'sos':
        return Icons.sos_rounded;
      case 'trip':
        return Icons.route_outlined;
      case 'arrival':
        return Icons.flag_outlined;
      default:
        return Icons.my_location;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppServices.current;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location history'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v != 'clear') return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear history?'),
                  content: const Text('This removes all saved location history from this phone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true) await s.history.clear();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Clear history'))],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.history, s.settings]),
        builder: (context, _) {
          final items = s.history.items;
          final children = <Widget>[
            SoftCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Record location history'),
                subtitle: const Text(
                    'Saved on this phone only, while Kapin is open. Check-ins, SOS and trips are always logged.'),
                value: s.settings.recordHistory,
                onChanged: s.settings.setRecordHistory,
              ),
            ),
            const SizedBox(height: 12),
          ];

          if (items.isEmpty) {
            children.add(const SizedBox(height: 40));
            children.add(const EmptyState(
              icon: Icons.history_rounded,
              title: 'No history yet',
              message: 'Places you visit while Kapin is open will appear here.',
            ));
          } else {
            String? lastDay;
            for (final h in items) {
              final d = dayLabel(h.time);
              if (d != lastDay) {
                lastDay = d;
                children.add(Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                  child: Text(d,
                      style: text.titleSmall?.copyWith(
                          color: scheme.primary, fontWeight: FontWeight.w800)),
                ));
              }
              children.add(_tile(context, h, scheme));
            }
          }

          return ListView(padding: listPadding(context), children: children);
        },
      ),
    );
  }

  Widget _tile(BuildContext context, HistoryEntry h, ColorScheme scheme) {
    final special = h.type != 'location';
    final title = h.note.isNotEmpty
        ? h.note
        : (h.address.isNotEmpty ? h.address : '${h.lat.toStringAsFixed(4)}, ${h.lng.toStringAsFixed(4)}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlaceMapScreen(
                place: PlaceInfo(
                    name: title,
                    address: h.address,
                    lat: h.lat,
                    lng: h.lng),
              ),
            ),
          ),
          leading: CircleAvatar(
            backgroundColor: h.type == 'sos'
                ? scheme.errorContainer
                : (special ? scheme.tertiaryContainer : scheme.primaryContainer),
            child: Icon(_icon(h.type),
                color: h.type == 'sos'
                    ? scheme.onErrorContainer
                    : (special ? scheme.onTertiaryContainer : scheme.onPrimaryContainer)),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${clockLabel(h.time)}${special && h.address.isNotEmpty ? ' \u00b7 ${h.address}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
