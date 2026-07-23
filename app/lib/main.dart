import 'package:flutter/material.dart';

import 'src/config.dart';
import 'src/data/chat_client.dart';
import 'src/data/device_id_repository.dart';
import 'src/data/live_content_client.dart';
import 'src/data/manual_context_repository.dart';
import 'src/data/pack_repository.dart';
import 'src/data/review_repository.dart';
import 'src/data/routine_client.dart';
import 'src/data/settings_repository.dart';
import 'src/data/user_profile_repository.dart';
import 'src/engine/context_engine.dart';
import 'src/models/user_profile.dart';
import 'src/services/location_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/routine_sampler.dart';
import 'src/services/speaker.dart';
import 'src/ui/chat_screen.dart';
import 'src/ui/home_screen.dart';
import 'src/ui/learned_places_screen.dart';
import 'src/ui/live_card_screen.dart';
import 'src/ui/onboarding_screen.dart';
import 'src/ui/routine_permission_screen.dart';

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
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
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
  late final LiveContentClient _live;
  final ChatClient _chat = ChatClient(baseUrl: AppConfig.serverBaseUrl);
  final RoutineClient _routine = RoutineClient(baseUrl: AppConfig.serverBaseUrl);

  @override
  void initState() {
    super.initState();
    _future = _bootstrap();
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

    return _AppData(
        packs, reviews, settings, manualContext, profileRepo, deviceId);
  }

  /// Bildiriş/paket tıklamasında canlı AI kartını açır (profil varsa).
  void _openLive(String? packId) {
    if (packId == null) return;
    _future.then((data) {
      final profile = data.profileRepo.current;
      final pack = data.packs.byId(packId);
      if (profile == null || pack == null) return;
      navigatorKey.currentState?.push(_liveRoute(pack.packId, pack.titleAz, profile));
    });
  }

  MaterialPageRoute _liveRoute(String packId, String title, UserProfile profile) {
    return MaterialPageRoute(
      builder: (_) => LiveCardScreen(
        title: title,
        speaker: _speaker,
        fetch: (mode) => _live.generate(
          packId: packId,
          hour: DateTime.now().hour,
          profile: profile,
          mode: mode,
        ),
        onAskQuestion: () => _openChat(
          profile,
          packId: packId,
          greeting: '"$title" haqda nə soruşmaq istəyirsən? 🤖',
        ),
      ),
    );
  }

  /// "AI nəyi öyrənib" ekranını açır (serverdəki rutin aqreqatı).
  void _openLearnedPlaces(_AppData data) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => LearnedPlacesScreen(
        loader: () => _routine.fetchSummary(data.deviceId),
        labelFor: (id) => data.packs.byId(id)?.titleAz ?? id,
        onOpenPermission: _openRoutinePermission,
      ),
    ));
  }

  /// Arxa fon icazə ekranını açır; icazə verilsə periodik toplamanı qeyd edir.
  void _openRoutinePermission() {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => RoutinePermissionScreen(
        requestAlways: _location.ensureBackgroundPermission,
        openSettings: _location.openSettings,
        onGranted: () {
          // Xəta app-ı bloklamamalı — səssiz udulur.
          RoutineSampler.registerPeriodic().catchError((_) {});
        },
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

        return HomeScreen(
          repository: data.packs,
          speaker: _speaker,
          reviewRepository: data.reviews,
          manualContextRepository: data.manualContext,
          settingsRepository: data.settings,
          notificationService: _notifications,
          profile: data.profileRepo.current!,
          openLive: (packId, title, profile) => navigatorKey.currentState
              ?.push(_liveRoute(packId, title, profile)),
          onOpenChat: () => _openChat(data.profileRepo.current!),
          onOpenLearned: () => _openLearnedPlaces(data),
        );
      },
    );
  }
}
