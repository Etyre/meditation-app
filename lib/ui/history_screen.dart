import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/session_record.dart';
import '../infra/storage/session_history_store.dart';

/// The device-local session log: every saved session, newest first, with
/// its sync status and a manual "sync now" action.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SessionHistoryStore>();
    final records = history.records.reversed.toList();
    final pending = history.pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (pending > 0)
            TextButton.icon(
              icon: const Icon(Icons.sync),
              label: Text('Sync $pending'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final n = await history.syncPending();
                messenger.showSnackBar(SnackBar(
                    content: Text(n > 0
                        ? 'Synced $n session${n == 1 ? '' : 's'}'
                        : 'Could not reach the logging services')));
              },
            ),
        ],
      ),
      body: records.isEmpty
          ? const Center(child: Text('No sessions recorded yet'))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, i) => _RecordTile(record: records[i]),
            ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final SessionRecord record;
  const _RecordTile({required this.record});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _when(DateTime d) {
    final local = d.toLocal();
    final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour < 12 ? 'am' : 'pm';
    final min = local.minute.toString().padLeft(2, '0');
    return '${_months[local.month - 1]} ${local.day}, $h12:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final history = context.read<SessionHistoryStore>();
    final wantsSheets = history.isSheetsConfigured();
    final wantsToggl = history.isTogglConfigured();
    final fullySynced = (!wantsSheets || record.sheetsSynced) &&
        (!wantsToggl || record.togglSynced);
    final mins = record.meditatedMinutes;
    final minsLabel =
        mins == mins.roundToDouble() ? '${mins.round()}' : mins.toStringAsFixed(1);

    return ListTile(
      leading: Icon(
        record.openEnded ? Icons.all_inclusive : Icons.timer_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text('$minsLabel min${record.aborted ? ' · stopped early' : ''}'),
      subtitle: Text(_when(record.startedAt)),
      trailing: (wantsSheets || wantsToggl)
          ? Tooltip(
              message: fullySynced ? 'Synced' : 'Waiting to sync',
              child: Icon(
                fullySynced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                size: 20,
                color: fullySynced
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            )
          : null,
    );
  }
}
