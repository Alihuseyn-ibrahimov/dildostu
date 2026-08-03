import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'src/config.dart';
import 'src/data/app_update_client.dart';
import 'src/data/chat_client.dart';
import 'src/data/device_id_repository.dart';
import 'src/data/geofence_cooldown_repository.dart';
import 'src/data/live_content_client.dart';
import 'src/data/manual_context_repository.dart';
import 'src/data/pack_repository.dart';
import 'src/data/review_repository.dart';
import 'src/data/routine_client.dart';
import 'src/data/settings_repository.dart';
import 'src/data/user_profile_repository.dart';
import 'src/engine/context_engine.dart';
import 'src/engine/geofence_logic.dart';
import 'src/engine/pack_titles.dart';
import 'src/engine/update_logic.dart';
import 'src/models/app_version_info.dart';
import 'src/models/user_profile.dart';
import 'src/services/battery_optimization_service.dart';
import 'src/services/location_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/routine_sampler.dart';
import 'src/services/speaker.dart';
import 'src/ui/chat_screen.dart';
import 'src/ui/home_tab.dart';
import 'src/ui/learned_places_screen.dart';
import 'src/ui/word_detail_screen.dart';
import 'src/ui/word_list_screen.dart';
import 'src/ui/main_shell.dart';
import 'src/ui/manual_mode_screen.dart';
import 'src/ui/onboarding_screen.dart';
import 'src/ui/profile_tab.dart';
import 'src/ui/progress_tab.dart';
import 'src/ui/routine_permission_screen.dart';
import 'src/ui/settings_screen.dart';
import 'src/ui/theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Arxa fon rutin toplama plugin-i (periodik iş üçün). Xəta app-ı bloklamamalı.
  try {
    await RoutineSampler.initialize();
  } catch (_) {}
  runApp(const DilDostuApp());
}

class DilDostuApp extends StatelessWidget {
  const DilDostuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DilDostu',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _Bootstrap(),
    );
  }
}

class _AppData {
  const _AppData(
    this.packs,
    this.reviews,
    this.settings,
    this.manualContext,
    this.profileRepo,
    this.deviceId,
  );
  final PackRepository packs;
  final ReviewRepository reviews;
  final SettingsRepository settings;
  final ManualContextRepository manualContext;
  final UserProfileRepository profileRepo;
  final String deviceId;
}

/// Repository-ləri yükləyir, profil yoxdursa onboarding göstərir, bildirişləri
/// planlaşdırır. Paket/bildiriş tıklaması canlı AI kartı açır (offline fallback).
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<_AppData> _future;
  final Speaker _speaker = TtsSpeaker();
  final NotificationService _notifications = NotificationService();
  final LocationService _location = LocationService();
  final BatteryOptimizationService _battery = BatteryOptimizationService();
  late final LiveContentClient _live;
  final ChatClient _chat = ChatClient(baseUrl: AppConfig.serverBaseUrl);
  final RoutineClient _routine = RoutineClient(baseUrl: AppConfig.serverBaseUrl);
  final AppUpdateClient _updateClient =
      AppUpdateClient(baseUrl: AppConfig.serverBaseUrl);
  AppVersionInfo? _availableUpdate;
  String? _updateApkPath;
  String? _buildLabel;

  @override
  void initState() {
    super.initState();
    _future = _bootstrap();
    _checkForUpdate(); // fire-and-forget — açılışı bloklamır
  }

  /// Serverdə yeni versiya varsa arxa planda yükləyir; nəticə HomeScreen-də
  /// "Yenilə" zolağı kimi göstərilir (təsdiq üçün toxunuş tələb olunur).
  Future<void> _checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);
      if (mounted) {
        setState(() =>
            _buildLabel = '${packageInfo.version}+${packageInfo.buildNumber}');
      }
      final destPath =
          '${Directory.systemTemp.path}/dildostu-update.apk';
      final result = await checkForUpdate(
        currentVersionCode: currentVersionCode,
        fetchVersion: _updateClient.fetchVersionInfo,
        downloadApk: () => _updateClient.downloadApk(destPath),
      );
      if (result == null || !mounted) return;
      setState(() {
        _availableUpdate = result.versionInfo;
        _updateApkPath = result.apkPath;
      });
    } catch (_) {
      // Yeniləmə yoxlaması istifadəçini bloklamamalı.
    }
  }

  Future<void> _installUpdate() async {
    if (_updateApkPath == null) return;
    // APK-nı explicit .apk MIME ilə aç (bəzi cihazlarda ümumi tip quraşdırıcını
    // açmır); xəta olsa istifadəçiyə göstər ki, diaqnoz mümkün olsun.
    final result = await OpenFilex.open(
      _updateApkPath!,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Quraşdırma açılmadı: ${result.message}')),
        );
      }
    }
  }

  Future<_AppData> _bootstrap() async {
    final packs = await PackRepository.loadFromAssets();
    _live = LiveContentClient(
      baseUrl: AppConfig.serverBaseUrl,
      fallbackRepo: packs,
    );
    final reviews = await ReviewRepository.load();
    final settings = await SettingsRepository.load();
    final manualContext = await ManualContextRepository.load();
    final profileRepo = await UserProfileRepository.load();
    final deviceId = (await DeviceIdRepository.load()).deviceId;

    await _notifications.init(onTap: _openLive);

    final now = DateTime.now();
    final manualSignal = manualContext.currentSignal(now: now);
    String? contextOverride = manualSignal?.packId;
    if (contextOverride == null) {
      final nearbyPackId = await _location.resolveNearbyPackId();
      if (nearbyPackId != null && packs.byId(nearbyPackId) != null) {
        contextOverride = resolveContextPack(
          now: now,
          timeBasedPackId: nearbyPackId,
          manualSignal: null,
          locationSignal: LocationSignal(packId: nearbyPackId, resolvedAt: now),
        );
      }
    }

    await _notifications.scheduleToday(
      settings.current,
      packs.packIds,
      (packId) => packs.byId(packId)?.titleAz ?? packId,
      firstSlotOverride: contextOverride,
    );

    final launchPackId = await _notifications.initialLaunchPayload();
    if (launchPackId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openLive(launchPackId));
    }

    // İcazə varsa: periodik tapşırığı yenidən qeyd et (app yeniləməsindən sonra
    // itə bilər) + dərhal ön-plan nümunəsi götür (WorkManager-ə güvənmə).
    _startRoutineSampling(deviceId, packs);

    return _AppData(
        packs, reviews, settings, manualContext, profileRepo, deviceId);
  }

  /// App açılışda rutin toplamanı təmin edir: icazə varsa periodik tapşırığı
  /// yenidən qeyd edir, dərhal bir ön-plan nümunəsi göndərir və eyni koordinatla
  /// geofence yoxlaması edir (tez-tez gedilən yerdəsənsə dərhal bildiriş).
  /// Səssiz keçir.
  Future<void> _startRoutineSampling(
      String deviceId, PackRepository packs) async {
    try {
      if (!await _location.hasBackgroundPermission()) return;
      await RoutineSampler.registerPeriodic();
      final sample = await _location.resolveNearbySample();
      if (sample == null) return;
      await _routine.postSample(
        deviceId: deviceId,
        lat: sample.lat,
        lng: sample.lng,
        placeType: sample.packId,
        packId: sample.packId,
      );
      final cooldown = await GeofenceCooldownRepository.load();
      await checkGeofenceArrival(
        lat: sample.lat,
        lng: sample.lng,
        fetchGeofences: () => _routine.fetchGeofences(deviceId),
        getLastNotified: cooldown.lastNotifiedAt,
        markNotified: cooldown.markNotified,
        notify: (packId, label) =>
            _notifications.showArrival(packId, packTitleAz(label)),
      );
    } catch (_) {
      // Fon işi — istifadəçini bloklamamalı.
    }
  }

  /// "İndi yoxla" — nümunə tapılsa göndərir; tapılmasa detallı diaqnostika
  /// göstərir (koordinat + server/OSM nəticəsi) ki, problem harada olduğu görünsün.
  Future<String> _sampleNow(_AppData data) async {
    final sample = await _location.resolveNearbySample();
    if (sample == null) {
      return _location.diagnose();
    }
    await _routine.postSample(
      deviceId: data.deviceId,
      lat: sample.lat,
      lng: sample.lng,
      placeType: sample.packId,
      packId: sample.packId,
    );
    final label = data.packs.byId(sample.packId)?.titleAz ?? sample.packId;
    final where = sample.place.isNotEmpty ? '${sample.place} → ' : '';
    return 'Tapıldı: $where$label — serverə göndərildi ✅';
  }

  /// Ana səhifədəki canlı məkan kartı üçün: GPS→server ilə cari yeri tapır,
  /// paket başlığı ilə birlikdə qaytarır və ön-plan nümunəsini serverə göndərir.
  /// Tapılmasa `null` (kart manual rejimə keçir).
  Future<({String packId, String title, String placeName})?> _resolveLivePlace(
      _AppData data) async {
    final sample = await _location.resolveNearbySample();
    if (sample == null) return null;
    final title = data.packs.byId(sample.packId)?.titleAz ?? sample.packId;
    // Ön-plan nümunəsini rutin datasına da yaz (fon icazəsi olmasa belə).
    _routine.postSample(
      deviceId: data.deviceId,
      lat: sample.lat,
      lng: sample.lng,
      placeType: sample.packId,
      packId: sample.packId,
    );
    return (packId: sample.packId, title: title, placeName: sample.place);
  }

  /// Bildiriş/geofence tıklamasında həmin paketin söz siyahısını açır.
  void _openLive(String? packId) {
    if (packId == null) return;
    _future.then((data) {
      final profile = data.profileRepo.current;
      final pack = data.packs.byId(packId);
      if (profile == null || pack == null) return;
      navigatorKey.currentState
          ?.push(_wordListRoute(pack.packId, pack.titleAz, profile));
    });
  }

  /// Paket → söz siyahısı ekranı. Siyahıdan sözə toxunanda ətraflı ekran açılır
  /// (indeks ötürülür ki, orada "Əvvəlki/Növbəti" işləsin).
  MaterialPageRoute _wordListRoute(
      String packId, String title, UserProfile profile) {
    return MaterialPageRoute(
      builder: (_) => WordListScreen(
        title: title,
        loader: () => _live.packWords(packId: packId, profile: profile),
        onOpenWord: (words, index) =>
            navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => WordDetailScreen(
            title: title,
            words: words,
            initialIndex: index,
            speaker: _speaker,
            onAskQuestion: () => _openChat(
              profile,
              packId: packId,
              greeting: '"$title" haqda nə soruşmaq istəyirsən? 🤖',
            ),
          ),
        )),
      ),
    );
  }

  /// "AI nəyi öyrənib" ekranını açır (serverdəki rutin aqreqatı).
  void _openLearnedPlaces(_AppData data) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => LearnedPlacesScreen(
        loader: () => _routine.fetchSummary(data.deviceId),
        labelFor: (id) => data.packs.byId(id)?.titleAz ?? id,
        onOpenPermission: () => _openRoutinePermission(data),
      ),
    ));
  }

  /// Arxa fon icazə ekranını açır; icazə verilsə periodik toplamanı qeyd edir.
  void _openRoutinePermission(_AppData data) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => RoutinePermissionScreen(
        requestAlways: _location.ensureBackgroundPermission,
        openSettings: _location.openSettings,
        onGranted: () {
          // Xəta app-ı bloklamamalı — səssiz udulur.
          RoutineSampler.registerPeriodic().catchError((_) {});
        },
        onSampleNow: () => _sampleNow(data),
        checkBatteryOptimization: _battery.isIgnoringOptimizations,
        openBatterySettings: _battery.openSettings,
      ),
    ));
  }

  /// AI söhbət ekranını açır (home-dan ümumi, kartdan kontekstli).
  void _openChat(UserProfile profile, {String? packId, String? greeting}) {
    final hour = DateTime.now().hour;
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        greeting: greeting,
        sender: (history) => _chat.send(
          profile: profile,
          history: history,
          packId: packId,
          hour: packId != null ? hour : null,
        ),
      ),
    ));
  }

  /// "İndi haradayam?" — manual məkan/kontekst ekranı.
  void _openManualPlace(_AppData data) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => ManualModeScreen(
        packRepository: data.packs,
        reviewRepository: data.reviews,
        manualContextRepository: data.manualContext,
        speaker: _speaker,
      ),
    ));
  }

  /// Ana səhifədəki çətinlik seçicisi — profilə saxlanır və dərhal tətbiq
  /// olunur (növbəti AI sorğusu yeni səviyyə ilə gedir, spec §1).
  Future<void> _changeLevel(_AppData data, ProficiencyLevel level) async {
    final current = data.profileRepo.current;
    if (current == null || current.level == level) return;
    await data.profileRepo.save(current.copyWith(level: level));
    if (mounted) setState(() {});
  }

  void _openSettings(_AppData data) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) =>
          SettingsScreen(repository: data.settings, buildLabel: _buildLabel),
    ));
  }

  /// Demo: dərhal "kafe" bildirişi göstərir (bildiriş→toxunma→kart axını).
  Future<void> _testNotification(_AppData data) async {
    const demoPack = 'cafe';
    final title = data.packs.byId(demoPack)?.titleAz ?? demoPack;
    await _notifications.showNow(demoPack, title);
  }

  @override
  void dispose() {
    _speaker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Yüklənmə xətası:\n${snapshot.error}'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!;

        // Profil yoxdursa onboarding göstər.
        if (!data.profileRepo.isOnboarded) {
          return OnboardingScreen(
            onComplete: (profile) async {
              await data.profileRepo.save(profile);
              if (mounted) setState(() {});
            },
          );
        }

        final profile = data.profileRepo.current!;
        return MainShell(
          home: HomeTab(
            repository: data.packs,
            profile: profile,
            openLive: (packId, title, p) =>
                navigatorKey.currentState?.push(_wordListRoute(packId, title, p)),
            onManualPlace: () => _openManualPlace(data),
            onLevelChanged: (level) => _changeLevel(data, level),
            resolveLivePlace: () => _resolveLivePlace(data),
            availableUpdate: _availableUpdate,
            onInstallUpdate: _availableUpdate == null ? null : _installUpdate,
          ),
          chat: ChatScreen(
            sender: (history) =>
                _chat.send(profile: profile, history: history),
          ),
          progress: ProgressTab(
            reviewRepository: data.reviews,
            packRepository: data.packs,
            speaker: _speaker,
          ),
          profile: ProfileTab(
            onOpenSettings: () => _openSettings(data),
            onOpenLearned: () => _openLearnedPlaces(data),
            onOpenRoutine: () => _openRoutinePermission(data),
            onTestNotification: () => _testNotification(data),
          ),
        );
      },
    );
  }
}
