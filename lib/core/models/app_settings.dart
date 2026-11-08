import 'gong_config.dart';
import 'metronome_config.dart';
import 'protocol.dart';
import 'question.dart';

/// Which kind of sit the home screen is set up for.
enum SessionMode {
  /// One practice for a set time (or open-ended).
  single,

  /// A saved protocol: a sequence of practices with signals between them.
  structured;

  static SessionMode fromName(String? name) => SessionMode.values
      .firstWhere((m) => m.name == name, orElse: () => SessionMode.single);
}

/// All user-configurable settings, persisted as JSON.
class AppSettings {
  final int defaultTimerMinutes;

  /// Pre-timer countdown length in seconds; 0 disables it. While it runs,
  /// heart rate is sampled as the pre-meditation baseline; at zero the gong
  /// rings and the timer starts.
  final int countdownSeconds;

  /// Which sounds the start/end gongs use, plus any extra gongs during the sit.
  final GongConfig gongs;
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

  /// The practices offered on the home screen (user-editable; a written-in
  /// practice is added here when the sit starts).
  final List<String> practices;

  /// Saved structured sessions.
  final List<Protocol> protocols;

  /// What the home screen last had selected, so it opens the same way.
  final SessionMode lastMode;
  final String lastPractice;
  final String lastProtocolId;

  /// Remembered heart rate monitor so the app can reconnect quickly.
  final String lastHrDeviceId;
  final String lastHrDeviceName;

  const AppSettings({
    this.defaultTimerMinutes = 20,
    this.countdownSeconds = 0,
    this.gongs = GongConfig.defaults,
    this.metronome = MetronomeConfig.defaults,
    this.sheetsWebhookUrl = '',
    this.sheetsSecret = '',
    this.togglApiToken = '',
    this.togglWorkspaceId = 0,
    this.togglDescription = 'Meditation',
    this.togglProjectId = 0,
    this.togglProjectName = '',
    this.questions = defaultQuestions,
    this.practices = PracticeDefaults.practices,
    this.protocols = PracticeDefaults.protocols,
    this.lastMode = SessionMode.single,
    this.lastPractice = '',
    this.lastProtocolId = '',
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
    GongConfig? gongs,
    MetronomeConfig? metronome,
    String? sheetsWebhookUrl,
    String? sheetsSecret,
    String? togglApiToken,
    int? togglWorkspaceId,
    String? togglDescription,
    int? togglProjectId,
    String? togglProjectName,
    List<Question>? questions,
    List<String>? practices,
    List<Protocol>? protocols,
    SessionMode? lastMode,
    String? lastPractice,
    String? lastProtocolId,
    String? lastHrDeviceId,
    String? lastHrDeviceName,
  }) =>
      AppSettings(
        defaultTimerMinutes: defaultTimerMinutes ?? this.defaultTimerMinutes,
        countdownSeconds: countdownSeconds ?? this.countdownSeconds,
        gongs: gongs ?? this.gongs,
        metronome: metronome ?? this.metronome,
        sheetsWebhookUrl: sheetsWebhookUrl ?? this.sheetsWebhookUrl,
        sheetsSecret: sheetsSecret ?? this.sheetsSecret,
        togglApiToken: togglApiToken ?? this.togglApiToken,
        togglWorkspaceId: togglWorkspaceId ?? this.togglWorkspaceId,
        togglDescription: togglDescription ?? this.togglDescription,
        togglProjectId: togglProjectId ?? this.togglProjectId,
        togglProjectName: togglProjectName ?? this.togglProjectName,
        questions: questions ?? this.questions,
        practices: practices ?? this.practices,
        protocols: protocols ?? this.protocols,
        lastMode: lastMode ?? this.lastMode,
        lastPractice: lastPractice ?? this.lastPractice,
        lastProtocolId: lastProtocolId ?? this.lastProtocolId,
        lastHrDeviceId: lastHrDeviceId ?? this.lastHrDeviceId,
        lastHrDeviceName: lastHrDeviceName ?? this.lastHrDeviceName,
      );

  Map<String, dynamic> toJson() => {
        'defaultTimerMinutes': defaultTimerMinutes,
        'countdownSeconds': countdownSeconds,
        'gongs': gongs.toJson(),
        'metronome': metronome.toJson(),
        'sheetsWebhookUrl': sheetsWebhookUrl,
        'sheetsSecret': sheetsSecret,
        'togglApiToken': togglApiToken,
        'togglWorkspaceId': togglWorkspaceId,
        'togglDescription': togglDescription,
        'togglProjectId': togglProjectId,
        'togglProjectName': togglProjectName,
        'questions': [for (final q in questions) q.toJson()],
        'practices': practices,
        'protocols': [for (final p in protocols) p.toJson()],
        'lastMode': lastMode.name,
        'lastPractice': lastPractice,
        'lastProtocolId': lastProtocolId,
        'lastHrDeviceId': lastHrDeviceId,
        'lastHrDeviceName': lastHrDeviceName,
      };

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppSettings();
    return AppSettings(
      defaultTimerMinutes: (json['defaultTimerMinutes'] as num?)?.toInt() ?? 20,
      countdownSeconds: (json['countdownSeconds'] as num?)?.toInt() ?? 0,
      gongs: GongConfig.fromJson(
          (json['gongs'] as Map?)?.cast<String, dynamic>()),
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
      practices: (json['practices'] as List?)?.cast<String>() ??
          PracticeDefaults.practices,
      protocols: (json['protocols'] as List?)
              ?.map((p) => Protocol.fromJson(Map<String, dynamic>.from(p as Map)))
              .toList() ??
          PracticeDefaults.protocols,
      lastMode: SessionMode.fromName(json['lastMode'] as String?),
      lastPractice: json['lastPractice'] as String? ?? '',
      lastProtocolId: json['lastProtocolId'] as String? ?? '',
      lastHrDeviceId: json['lastHrDeviceId'] as String? ?? '',
      lastHrDeviceName: json['lastHrDeviceName'] as String? ?? '',
    );
  }
}
