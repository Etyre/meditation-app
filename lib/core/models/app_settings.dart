import 'metronome_config.dart';

/// All user-configurable settings, persisted as JSON.
class AppSettings {
  final int defaultTimerMinutes;
  final MetronomeConfig metronome;

  /// Google Apps Script "web app" URL that appends a row to the sheet.
  final String sheetsWebhookUrl;

  /// Toggl Track API token (from https://track.toggl.com/profile).
  final String togglApiToken;

  /// Optional explicit workspace id; when 0 the default workspace from
  /// the Toggl /me endpoint is used.
  final int togglWorkspaceId;
  final String togglDescription;

  /// Toggl project to file time entries under; 0 = no project.
  final int togglProjectId;

  /// Display name of the chosen project (the id is what's sent to Toggl).
  final String togglProjectName;

  /// Questions asked after each session; answers are logged to the sheet.
  final List<String> questions;

  /// Remembered heart rate monitor so the app can reconnect quickly.
  final String lastHrDeviceId;
  final String lastHrDeviceName;

  const AppSettings({
    this.defaultTimerMinutes = 20,
    this.metronome = MetronomeConfig.defaults,
    this.sheetsWebhookUrl = '',
    this.togglApiToken = '',
    this.togglWorkspaceId = 0,
    this.togglDescription = 'Meditation',
    this.togglProjectId = 0,
    this.togglProjectName = '',
    this.questions = defaultQuestions,
    this.lastHrDeviceId = '',
    this.lastHrDeviceName = '',
  });

  static const List<String> defaultQuestions = [
    'How was your focus? (1-5)',
    'How calm do you feel? (1-5)',
    'Notes',
  ];

  AppSettings copyWith({
    int? defaultTimerMinutes,
    MetronomeConfig? metronome,
    String? sheetsWebhookUrl,
    String? togglApiToken,
    int? togglWorkspaceId,
    String? togglDescription,
    int? togglProjectId,
    String? togglProjectName,
    List<String>? questions,
    String? lastHrDeviceId,
    String? lastHrDeviceName,
  }) =>
      AppSettings(
        defaultTimerMinutes: defaultTimerMinutes ?? this.defaultTimerMinutes,
        metronome: metronome ?? this.metronome,
        sheetsWebhookUrl: sheetsWebhookUrl ?? this.sheetsWebhookUrl,
        togglApiToken: togglApiToken ?? this.togglApiToken,
        togglWorkspaceId: togglWorkspaceId ?? this.togglWorkspaceId,
        togglDescription: togglDescription ?? this.togglDescription,
        togglProjectId: togglProjectId ?? this.togglProjectId,
        togglProjectName: togglProjectName ?? this.togglProjectName,
        questions: questions ?? this.questions,
        lastHrDeviceId: lastHrDeviceId ?? this.lastHrDeviceId,
        lastHrDeviceName: lastHrDeviceName ?? this.lastHrDeviceName,
      );

  Map<String, dynamic> toJson() => {
        'defaultTimerMinutes': defaultTimerMinutes,
        'metronome': metronome.toJson(),
        'sheetsWebhookUrl': sheetsWebhookUrl,
        'togglApiToken': togglApiToken,
        'togglWorkspaceId': togglWorkspaceId,
        'togglDescription': togglDescription,
        'togglProjectId': togglProjectId,
        'togglProjectName': togglProjectName,
        'questions': questions,
        'lastHrDeviceId': lastHrDeviceId,
        'lastHrDeviceName': lastHrDeviceName,
      };

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppSettings();
    return AppSettings(
      defaultTimerMinutes: (json['defaultTimerMinutes'] as num?)?.toInt() ?? 20,
      metronome: MetronomeConfig.fromJson(
          (json['metronome'] as Map?)?.cast<String, dynamic>()),
      sheetsWebhookUrl: json['sheetsWebhookUrl'] as String? ?? '',
      togglApiToken: json['togglApiToken'] as String? ?? '',
      togglWorkspaceId: (json['togglWorkspaceId'] as num?)?.toInt() ?? 0,
      togglDescription: json['togglDescription'] as String? ?? 'Meditation',
      togglProjectId: (json['togglProjectId'] as num?)?.toInt() ?? 0,
      togglProjectName: json['togglProjectName'] as String? ?? '',
      questions: (json['questions'] as List?)?.cast<String>() ??
          defaultQuestions,
      lastHrDeviceId: json['lastHrDeviceId'] as String? ?? '',
      lastHrDeviceName: json['lastHrDeviceName'] as String? ?? '',
    );
  }
}
