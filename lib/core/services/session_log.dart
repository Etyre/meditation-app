import 'dart:convert';

import '../hrv/hrv_analysis.dart';
import '../models/session.dart';

/// Everything the app records about one finished session, flattened into the
/// payload that gets appended to the Google Sheet.
class SessionLogEntry {
  final SessionOutcome outcome;
  final bool includeOvertime;

  /// Question → answer, in the order the questions were asked.
  final Map<String, String> answers;

  final HrvSummary? hrv;

  /// Raw RR intervals (ms) for the whole session — the beat-to-beat data
  /// that HRV is computed from.
  final List<double> rrIntervalsMs;

  /// Per-notification heart rate readings as (secondsIntoSession, bpm).
  final List<List<num>> hrSeries;

  const SessionLogEntry({
    required this.outcome,
    required this.includeOvertime,
    required this.answers,
    this.hrv,
    this.rrIntervalsMs = const [],
    this.hrSeries = const [],
  });

  /// The JSON body POSTed to the Google Apps Script webhook.
  Map<String, dynamic> toSheetsPayload() {
    final o = outcome;
    return {
      'startedAt': o.startedAt.toIso8601String(),
      'endedAt': o.endedAt.toIso8601String(),
      'plannedMinutes': _minutes(o.planned),
      'meditatedMinutes':
          _minutes(o.meditatedDuration(includeOvertime: includeOvertime)),
      'overtimeMinutes': _minutes(o.overtime),
      'includedOvertime': includeOvertime,
      'aborted': o.aborted,
      'openEnded': o.openEnded,
      'answers': answers,
      'meanHr': hrv?.meanHr,
      'minHr': hrv?.minHr,
      'maxHr': hrv?.maxHr,
      'meanRrMs': hrv?.meanRrMs,
      'sdnnMs': hrv?.sdnnMs,
      'rmssdMs': hrv?.rmssdMs,
      'lnRmssd': hrv?.lnRmssd,
      'hrvScore': hrv?.score,
      'rrCount': rrIntervalsMs.length,
      'rrIntervalsMs':
          rrIntervalsMs.isEmpty ? '' : jsonEncode(_rounded(rrIntervalsMs)),
      'hrSeries': hrSeries.isEmpty ? '' : jsonEncode(hrSeries),
    };
  }

  static double _minutes(Duration d) =>
      double.parse((d.inMilliseconds / 60000).toStringAsFixed(2));

  static List<num> _rounded(List<double> values) => values
      .map((v) => v == v.roundToDouble() ? v.round() : double.parse(v.toStringAsFixed(1)))
      .toList();
}
