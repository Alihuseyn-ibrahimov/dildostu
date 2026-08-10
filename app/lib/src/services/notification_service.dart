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

/// DƏQİQ (`exactAllowWhileIdle`) YOX — `inexact` (2026-08-10-da dəyişdi):
/// 1. Android 14+-da dəqiq alarm `SCHEDULE_EXACT_ALARM` icazəsi tələb edir;
///    icazə verilməsə `zonedSchedule` istisna atır və HEÇ bir bildiriş
///    planlaşdırılmır (istifadəçi heç nə görmür — səssiz uğursuzluq).
/// 2. Google Play "Exact Alarm" siyasəti bu icazəni yalnız zəngli saat/təqvim
///    tipli tətbiqlərə verir — öyrənmə xatırlatması bu kateqoriyaya girmir,
///    Play buraxılışını bloklayırdı (bax .planning/2026-08-03-dildostu-playstore).
/// Öyrənmə xatırlatması üçün bir neçə dəqiqəlik sürüşmə tamamilə qəbul
/// ediləndir, ona görə `inexact` həm daha etibarlı, həm siyasətə uyğundur.
const _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

/// Bildiriş sisteminin real vəziyyəti — "bildiriş gəlmir" şikayətini
/// təxminlə yox, FAKTLA araşdırmaq üçün (bax dildostu/CLAUDE.md-dəki
/// "səssiz uğursuzluq" dərsi: öz-yenilənmə zolağı da aylarla belə itmişdi).
class NotificationDiagnostics {
  const NotificationDiagnostics({
    required this.pendingCount,
    required this.canScheduleExact,
    required this.lastError,
  });

  /// OS növbəsində FAKTİKİ gözləyən bildiriş sayı (kodun nə etdiyi yox,
  /// sistemin nəyi qəbul etdiyi).
  final int pendingCount;

  /// Android 14+-da "Zəngli saatlar və xatırlatmalar" icazəsi.
  final bool canScheduleExact;

  /// Sonuncu planlaşdırma/init xətası (varsa).
  final String? lastError;

  bool get hasProblem =>
      pendingCount == 0 || !canScheduleExact || lastError != null;

  String get summary {
    if (lastError != null) return 'Xəta: $lastError';
    if (!canScheduleExact) {
      return 'Dəqiq alarm icazəsi yoxdur — Ayarlar → Zəngli saatlar və '
          'xatırlatmalar açılmalıdır.';
    }
    if (pendingCount == 0) {
      return 'Növbədə bildiriş yoxdur — planlaşdırma baş tutmayıb.';
    }
    return 'Qaydasındadır: növbədə $pendingCount bildiriş var.';
  }
}

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

  /// Sonuncu init/planlaşdırma xətası — udulmur, diaqnostikada göstərilir.
  String? _lastError;

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

  /// Bildiriş sisteminin FAKTİKİ vəziyyəti (Ayarlar → diaqnostika).
  Future<NotificationDiagnostics> diagnose() async {
    var pending = 0;
    var canExact = true;
    try {
      pending = (await _plugin.pendingNotificationRequests()).length;
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      canExact = await androidPlugin?.canScheduleExactNotifications() ?? true;
    } catch (e) {
      return NotificationDiagnostics(
        pendingCount: 0,
        canScheduleExact: false,
        lastError: '$e',
      );
    }
    return NotificationDiagnostics(
      pendingCount: pending,
      canScheduleExact: canExact,
      lastError: _lastError,
    );
  }

  /// Dərhal sınaq bildirişi — planlaşdırmadan asılı olmadan bildiriş
  /// kanalının/icazənin işlədiyini yoxlamaq üçün.
  Future<void> showTestNow() async {
    await _plugin.show(
      id: 9999,
      title: 'LachinGo — sınaq',
      body: 'Bildirişlər işləyir ✅',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannelId,
          _chatChannelName,
          channelDescription: _chatChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
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

        // Bir slotun uğursuzluğu QALANLARINI dayandırmamalıdır (məs. dəqiq
        // alarm icazəsi yoxdursa) — xəta udulmur, `_lastError`-a yazılır və
        // Ayarlar → diaqnostikada görünür.
        try {
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
            androidScheduleMode: _scheduleMode,
            payload: packId,
          );
        } catch (e) {
          _lastError = '$e';
        }
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
      try {
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
          androidScheduleMode: _scheduleMode,
          payload: encodeChatNudgePayload(nudge.quickPrompt),
        );
      } catch (e) {
        _lastError = '$e';
      }
    }
  }
}
