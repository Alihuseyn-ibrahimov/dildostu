import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../engine/chat_nudge_payload.dart';
import '../engine/chat_nudge_scheduler.dart';
import '../engine/notification_scheduler.dart';
import '../engine/time_context_rule.dart';
import '../models/chat_nudge.dart';
import '../models/settings.dart';

const _wordChannelId = 'dildostu_words';
const _wordChannelName = 'Söz bildirişləri';
const _wordChannelDescription = 'LachinGo-nun gündəlik söz bildirişləri';

/// v2 — yüksək prioritet (köhnə kanal defolt importance qala bilər).
const _chatChannelId = 'dildostu_chat_v2';
const _chatChannelName = 'Söhbət xatırlatmaları';
const _chatChannelDescription =
    'LachinGo-nun fərdiləşdirilmiş chat xatırlatmaları';

/// Söz bildiriş ID-ləri: 0..19. Chat nudge: 1000..1009.
const _wordNotifIdBase = 0;
const _maxWordNotifs = 20;
const _chatNotifIdBase = 1000;
const _maxChatNotifs = 10;

/// Neçə gün əvvəlcədən planlaşdırılsın (bugün + sabah).
const _scheduleDaysAhead = 2;

/// Cihazın yerli bildiriş sistemi ilə işləyir: icazə istəyir, bugünkü
/// bildiriş vaxtlarını (notification_scheduler.dart) planlaşdırır.
///
/// Bildirişin payload-u:
/// - söz paketi: `pack_id` (məs. `cafe`)
/// - chat nudge: `chat|{url-encoded quick_prompt}`
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

  /// WorkManager fon izolatı üçün yüngül init — tz/icazə sorğusu YOX (bunlar
  /// əsas izolatda `init()` ilə artıq edilib). Yalnız plugin-i qeydiyyatdan
  /// keçirir ki, `showArrival` işləsin (background izolatda plugin ayrıca
  /// qeydiyyat tələb edir).
  Future<void> initBackground() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );
  }

  /// App bildirişə toxunmaqla soyuq başlanğıcdan açılıbsa, həmin bildirişin
  /// payload-unu (pack_id) qaytarır; əks halda null. main.dart bootstrap-da
  /// çağırılır ki, birbaşa uyğun paket açılsın.
  Future<String?> initialLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  /// Dərhal bir bildiriş göstərir (planlaşdırma yox) — demo/test üçün.
  Future<void> showNow(String packId, String title) async {
    await _plugin.show(
      id: 9999,
      title: 'LachinGo',
      body: '$title — yeni sözlərə baxın',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _wordChannelId,
          _wordChannelName,
          channelDescription: _wordChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: packId,
    );
  }

  Future<void> _cancelWordNotifications() async {
    for (var i = 0; i < _maxWordNotifs; i++) {
      await _plugin.cancel(id: _wordNotifIdBase + i);
    }
  }

  Future<void> _cancelChatNudges() async {
    for (var i = 0; i < _maxChatNotifs; i++) {
      await _plugin.cancel(id: _chatNotifIdBase + i);
    }
  }

  /// Geofence tetiklənməsi — istifadəçi tez-tez gəldiyi yerə çatanda (proqram
  /// bağlı olsa belə, WorkManager fon tick-indən) göstərilir. Toxunma
  /// `showNow`/`scheduleToday` ilə eyni payload konvensiyasını (pack_id)
  /// paylaşır — main.dart-da eyni `onTap` söz siyahısı ekranını açır.
  Future<void> showArrival(String packId, String title) async {
    await _plugin.show(
      id: 7777,
      title: 'LachinGo',
      body: '📍 $title-dasan! Uyğun sözlərə bax',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _wordChannelId,
          _wordChannelName,
          channelDescription: _wordChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: packId,
    );
  }

  /// Bugünkü və sabahkı söz bildirişlərini planlaşdırır.
  /// `packIds` mövcud paketlərin siyahısıdır (time_context_rule.dart üçün);
  /// `titleFor` hər pack_id-nin göstəriləcək adını qaytarır. `firstSlotOverride`
  /// verilibsə (manual/məkan konteksti aktivdirsə), yalnız ən yaxın bildiriş
  /// üçün vaxt qaydası əvəzinə bu pack_id işlədilir (spec §3.2 prioritet).
  Future<void> scheduleToday(
    Settings settings,
    List<String> packIds,
    String Function(String packId) titleFor, {
    String? firstSlotOverride,
  }) async {
    await _cancelWordNotifications();
    if (packIds.isEmpty) return;

    final now = DateTime.now();
    var notifId = 0;
    var firstScheduled = false;

    for (var dayOffset = 0; dayOffset < _scheduleDaysAhead; dayOffset++) {
      final day = DateTime(now.year, now.month, now.day)
          .add(Duration(days: dayOffset));
      final allTimes = computeNotificationTimes(day, settings);

      for (var slotIndex = 0; slotIndex < allTimes.length; slotIndex++) {
        final when = allTimes[slotIndex];
        if (!when.isAfter(now)) continue;
        if (notifId >= _maxWordNotifs) return;

        final useOverride =
            !firstScheduled && firstSlotOverride != null && dayOffset == 0;
        final packId = useOverride
            ? firstSlotOverride
            : pickPackForSlot(slotIndex, allTimes.length, packIds);
        firstScheduled = true;

        await _plugin.zonedSchedule(
          id: _wordNotifIdBase + notifId,
          title: 'LachinGo',
          body: '${titleFor(packId)} — yeni sözlərə baxın',
          scheduledDate: tz.TZDateTime.from(when, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _wordChannelId,
              _wordChannelName,
              channelDescription: _wordChannelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: packId,
        );
        notifId++;
      }
    }
  }

  /// Gündəlik chat xatırlatmaları (08:00, 13:00, 22:00) — bugün + sabah.
  Future<void> scheduleChatNudges(List<ChatNudge> nudges) async {
    await _cancelChatNudges();
    if (nudges.isEmpty) return;

    final now = DateTime.now();
    final slots = computeUpcomingChatNudgeTimes(now, dayCount: _scheduleDaysAhead);

    for (var i = 0; i < slots.length && i < _maxChatNotifs; i++) {
      final nudge = nudges[i % nudges.length];
      await _plugin.zonedSchedule(
        id: _chatNotifIdBase + i,
        title: 'LachinGo 💬',
        body: nudge.body,
        scheduledDate: tz.TZDateTime.from(slots[i], tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _chatChannelId,
            _chatChannelName,
            channelDescription: _chatChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: encodeChatNudgePayload(nudge.quickPrompt),
      );
    }
  }
}
