/// A locally persisted session: the full Sheets payload (which contains
/// everything the app records about a session) plus per-integration sync
/// flags. Records are kept forever on the device; Sheets/Toggl are mirrors.
class SessionRecord {
  final Map<String, dynamic> payload;

  /// Toggl description captured at save time, so later syncs use the
  /// description that was configured when the session happened.
  final String togglDescription;

  bool sheetsSynced;
  bool togglSynced;

  SessionRecord({
    required this.payload,
    required this.togglDescription,
    this.sheetsSynced = false,
    this.togglSynced = false,
  });

  DateTime get startedAt => DateTime.parse(payload['startedAt'] as String);
  DateTime get endedAt => DateTime.parse(payload['endedAt'] as String);
  double get meditatedMinutes =>
      (payload['meditatedMinutes'] as num?)?.toDouble() ?? 0;
  bool get openEnded => payload['openEnded'] as bool? ?? false;
  bool get aborted => payload['aborted'] as bool? ?? false;

  Map<String, dynamic> toJson() => {
        'payload': payload,
        'togglDescription': togglDescription,
        'sheetsSynced': sheetsSynced,
        'togglSynced': togglSynced,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        togglDescription: json['togglDescription'] as String? ?? '',
        sheetsSynced: json['sheetsSynced'] as bool? ?? false,
        togglSynced: json['togglSynced'] as bool? ?? false,
      );
}
