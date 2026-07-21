import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../engine/notification_scheduler.dart';
import '../engine/time_context_rule.dart';
import '../models/settings.dart';

const _channelId = 'dildostu_words';
const _channelName = 'Söz bildirişləri';
const _channelDescription = 'DilDostu-nun gündəlik söz bildirişləri';

/// Cihazın yerli bildiriş sistemi ilə işləyir: icazə istəyir, bugünkü
/// bildiriş vaxtlarını (notification_scheduler.dart) planlaşdırır.
///
/// Bildirişin payload-u seçilmiş pack_id-dir — toxunanda həmin paket açılır
/// (main.dart-da onNotificationTap ilə idarə olunur).
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _tzInitialized = false;

  Future<void> init({void Function(String? payload)? onTap}) async {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
      _tzInitialized = true;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) =>
          onTap?.call(response.payload),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  /// Bugünkü qalan bildirişləri ləğv edib yenidən planlaşdırır. `packIds`
  /// mövcud paketlərin siyahısıdır (time_context_rule.dart üçün);
  /// `titleFor` hər pack_id-nin göstəriləcək adını qaytarır. `firstSlotOverride`
  /// verilibsə (manual/məkan konteksti aktivdirsə), yalnız ən yaxın bildiriş
  /// üçün vaxt qaydası əvəzinə bu pack_id işlədilir (spec §3.2 prioritet).
  Future<void> scheduleToday(
    Settings settings,
    List<String> packIds,
    String Function(String packId) titleFor, {
    String? firstSlotOverride,
  }) async {
    await _plugin.cancelAll();
    if (packIds.isEmpty) return;

    final now = DateTime.now();
    final allTimes = computeNotificationTimes(now, settings);
    final future = allTimes.where((t) => t.isAfter(now)).toList();

    for (var i = 0; i < future.length; i++) {
      final slotIndex = allTimes.indexOf(future[i]);
      final packId = (i == 0 && firstSlotOverride != null)
          ? firstSlotOverride
          : pickPackForSlot(slotIndex, allTimes.length, packIds);
      await _plugin.zonedSchedule(
        id: i,
        title: 'DilDostu',
        body: '${titleFor(packId)} — yeni sözlərə baxın',
        scheduledDate: tz.TZDateTime.from(future[i], tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: packId,
      );
    }
  }
}
