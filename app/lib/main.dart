import 'package:flutter/material.dart';

import 'src/data/manual_context_repository.dart';
import 'src/data/pack_repository.dart';
import 'src/data/review_repository.dart';
import 'src/data/settings_repository.dart';
import 'src/engine/context_engine.dart';
import 'src/services/location_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/speaker.dart';
import 'src/ui/card_session_screen.dart';
import 'src/ui/home_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const DilDostuApp());
}

class DilDostuApp extends StatelessWidget {
  const DilDostuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DilDostu',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const _Bootstrap(),
    );
  }
}

class _AppData {
  const _AppData(this.packs, this.reviews, this.settings, this.manualContext);
  final PackRepository packs;
  final ReviewRepository reviews;
  final SettingsRepository settings;
  final ManualContextRepository manualContext;
}

/// Repository-ləri yükləyir, bildiriş icazəsini alıb bugünkü bildirişləri
/// planlaşdırır; yüklənənə qədər spinner, xəta olarsa mesaj göstərir.
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

  @override
  void initState() {
    super.initState();
    _future = _bootstrap();
  }

  Future<_AppData> _bootstrap() async {
    final packs = await PackRepository.loadFromAssets();
    final reviews = await ReviewRepository.load();
    final settings = await SettingsRepository.load();
    final manualContext = await ManualContextRepository.load();

    await _notifications.init(onTap: _openPack);

    // Spec §3.2: manual seçim məkandan, məkan isə vaxt qaydasından üstündür.
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

    return _AppData(packs, reviews, settings, manualContext);
  }

  void _openPack(String? packId) {
    if (packId == null) return;
    _future.then((appData) {
      final pack = appData.packs.byId(packId);
      if (pack == null) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CardSessionScreen(
            title: pack.titleAz,
            entries: [
              for (final word in pack.words)
                SessionEntry(wordKey: '${pack.packId}:${word.word}', word: word),
            ],
            speaker: _speaker,
            reviewRepository: appData.reviews,
          ),
        ),
      );
    });
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        return HomeScreen(
          repository: data.packs,
          speaker: _speaker,
          reviewRepository: data.reviews,
          manualContextRepository: data.manualContext,
          settingsRepository: data.settings,
        );
      },
    );
  }
}
