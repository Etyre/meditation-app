import 'metronome_config.dart';
import 'question.dart';

/// All user-configurable settings, persisted as JSON.
class AppSettings {
  final int defaultTimerMinutes;

  /// Pre-timer countdown length in seconds; 0 disables it. While it runs,
  /// heart rate is sampled as the pre-meditation baseline; at zero the gong
  /// rings and the timer starts.
  final int countdownSeconds;
  final MetronomeConfig metronome;

  /// Google Apps Script "web app" URL that appends a row to the sheet.
  final String sheetsWebhookUrl;

  /// Shared secret sent with every upload; the Apps Script rejects posts
  /// that don't carry the same value (its SECRET script property). Empty
  /// means the URL alone is the credential.
  final String sheetsSecret;

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
  final List<Question> questions;

  /// Remembered heart rate monitor so the app can reconnect quickly.
  final String lastHrDeviceId;
  final String lastHrDeviceName;

  const AppSettings({
    this.defaultTimerMinutes = 20,
    this.countdownSeconds = 0,
    this.metronome = MetronomeConfig.defaults,
    this.sheetsWebhookUrl = '',
    this.sheetsSecret = '',
    this.togglApiToken = '',
    this.togglWorkspaceId = 0,
    this.togglDescription = 'Meditation',
    this.togglProjectId = 0,
    this.togglProjectName = '',
    this.questions = defaultQuestions,
    this.lastHrDeviceId = '',
    this.lastHrDeviceName = '',
  });

  static const List<Question> defaultQuestions = [
    Question(
      text: 'How was your focus? (1-5)',
      type: QuestionType.multipleChoice,
      options: ['1', '2', '3', '4', '5'],
    ),
    Question(
      text: 'How calm do you feel? (1-5)',
      type: QuestionType.multipleChoice,
      options: ['1', '2', '3', '4', '5'],
    ),
    Question.freeText('Notes'),
  ];

  AppSettings copyWith({
    int? defaultTimerMinutes,
    int? countdownSeconds,
    MetronomeConfig? metronome,
    String? sheetsWebhookUrl,
    String? sheetsSecret,
    String? togglApiToken,
    int? togglWorkspaceId,
    String? togglDescription,
    int? togglProjectId,
    String? togglProjectName,
    List<Question>? questions,
    String? lastHrDeviceId,
    String? lastHrDeviceName,
  }) =>
      AppSettings(
        defaultTimerMinutes: defaultTimerMinutes ?? this.defaultTimerMinutes,
        countdownSeconds: countdownSeconds ?? this.countdownSeconds,
        metronome: metronome ?? this.metronome,
        sheetsWebhookUrl: sheetsWebhookUrl ?? this.sheetsWebhookUrl,
        sheetsSecret: sheetsSecret ?? this.sheetsSecret,
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
        'countdownSeconds': countdownSeconds,
        'metronome': metronome.toJson(),
        'sheetsWebhookUrl': sheetsWebhookUrl,
        'sheetsSecret': sheetsSecret,
        'togglApiToken': togglApiToken,
        'togglWorkspaceId': togglWorkspaceId,
        'togglDescription': togglDescription,
        'togglProjectId': togglProjectId,
        'togglProjectName': togglProjectName,
        'questions': [for (final q in questions) q.toJson()],
        'lastHrDeviceId': lastHrDeviceId,
        'lastHrDeviceName': lastHrDeviceName,
      };

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppSettings();
    return AppSettings(
      defaultTimerMinutes: (json['defaultTimerMinutes'] as num?)?.toInt() ?? 20,
      countdownSeconds: (json['countdownSeconds'] as num?)?.toInt() ?? 0,
      metronome: MetronomeConfig.fromJson(
          (json['metronome'] as Map?)?.cast<String, dynamic>()),
      sheetsWebhookUrl: json['sheetsWebhookUrl'] as String? ?? '',
      sheetsSecret: json['sheetsSecret'] as String? ?? '',
      togglApiToken: json['togglApiToken'] as String? ?? '',
      togglWorkspaceId: (json['togglWorkspaceId'] as num?)?.toInt() ?? 0,
      togglDescription: json['togglDescription'] as String? ?? 'Meditation',
      togglProjectId: (json['togglProjectId'] as num?)?.toInt() ?? 0,
      togglProjectName: json['togglProjectName'] as String? ?? '',
      questions: (json['questions'] as List?)
              ?.map(Question.fromJson)
              .toList() ??
          defaultQuestions,
      lastHrDeviceId: json['lastHrDeviceId'] as String? ?? '',
      lastHrDeviceName: json['lastHrDeviceName'] as String? ?? '',
    );
  }
}
