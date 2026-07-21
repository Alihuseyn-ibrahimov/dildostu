import 'package:flutter/material.dart';

import 'src/data/pack_repository.dart';
import 'src/data/review_repository.dart';
import 'src/data/settings_repository.dart';
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
  const _AppData(this.packs, this.reviews, this.settings);
  final PackRepository packs;
  final ReviewRepository reviews;
  final SettingsRepository settings;
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

  @override
  void initState() {
    super.initState();
    _future = _bootstrap();
  }

  Future<_AppData> _bootstrap() async {
    final packs = await PackRepository.loadFromAssets();
    final reviews = await ReviewRepository.load();
    final settings = await SettingsRepository.load();

    await _notifications.init(onTap: _openPack);
    await _notifications.scheduleToday(
      settings.current,
      packs.packIds,
      (packId) => packs.byId(packId)?.titleAz ?? packId,
    );

    return _AppData(packs, reviews, settings);
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
        );
      },
    );
  }
}
