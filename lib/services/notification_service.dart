import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tordo/models/medication.dart';
import 'package:rxdart/subjects.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();
  factory NotificationService() {
    return _notificationService;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final BehaviorSubject<String?> onNotificationClick = BehaviorSubject();
  final FlutterTts flutterTts = FlutterTts();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (
        NotificationResponse notificationResponse,
      ) {
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          onNotificationClick.add(payload);
        }
      },
    );
  }

  Future<void> scheduleAlarms(Medication medication) async {
    // Cancel previous alarms for this medication
    if (medication.id != null) {
      await cancelAlarms(medication.id!);
    }

    // Only schedule if medication is active
    if (!medication.isActive) return;

    for (int i = 0; i < medication.alarmTimes.length; i++) {
      final String alarmTime = medication.alarmTimes[i];
      final List<String> parts = alarmTime.split(':');
      final int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);

      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If time has passed for today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      final int notificationId = medication.id! * 100 + i;

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Hora de tomar ${medication.name}',
        medication.description,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_channel',
            'Esqueci',
            channelDescription: 'Notificações para lembretes de medicamentos',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: medication.id.toString(),
      );
    }
  }

  Future<void> cancelAlarms(int medicationId) async {
    // We assume a maximum of 10 alarms per medication
    for (int i = 0; i < 10; i++) {
      final int notificationId = medicationId * 100 + i;
      await flutterLocalNotificationsPlugin.cancel(notificationId);
    }
  }

  Future<void> speakInstructions(Medication medication) async {
    await flutterTts.setLanguage("pt-BR");
    await flutterTts.speak(
      "Hora de tomar ${medication.name}. ${medication.description}",
    );
  }
}
