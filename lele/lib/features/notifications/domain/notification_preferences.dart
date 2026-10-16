class NotificationPreferences {
  const NotificationPreferences({
    this.dailyReminder = true,
    this.achievement = true,
    this.weeklyReport = true,
    this.subscription = true,
    this.preferredTime = '18:00',
    this.timezone = 'America/Sao_Paulo',
  });

  final bool dailyReminder;
  final bool achievement;
  final bool weeklyReport;
  final bool subscription;
  final String preferredTime;
  final String timezone;

  factory NotificationPreferences.fromMap(Map<String, dynamic> data) =>
      NotificationPreferences(
        dailyReminder: data['dailyReminder'] == true,
        achievement: data['achievement'] == true,
        weeklyReport: data['weeklyReport'] == true,
        subscription: data['subscription'] == true,
        preferredTime: data['preferredTime'] as String? ?? '18:00',
        timezone: data['timezone'] as String? ?? 'America/Sao_Paulo',
      );

  Map<String, dynamic> toMap() => {
    'dailyReminder': dailyReminder,
    'achievement': achievement,
    'weeklyReport': weeklyReport,
    'subscription': subscription,
    // Marketing is not part of this permission request or this demo.
    'marketing': false,
    'preferredTime': preferredTime,
    'timezone': timezone,
  };

  NotificationPreferences copyWith({
    bool? dailyReminder,
    bool? achievement,
    bool? weeklyReport,
    bool? subscription,
    String? preferredTime,
    String? timezone,
  }) => NotificationPreferences(
    dailyReminder: dailyReminder ?? this.dailyReminder,
    achievement: achievement ?? this.achievement,
    weeklyReport: weeklyReport ?? this.weeklyReport,
    subscription: subscription ?? this.subscription,
    preferredTime: preferredTime ?? this.preferredTime,
    timezone: timezone ?? this.timezone,
  );
}
