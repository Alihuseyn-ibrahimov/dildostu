import 'package:flutter/material.dart';

import '../data/manual_context_repository.dart';
import '../data/pack_repository.dart';
import '../data/review_repository.dart';
import '../data/settings_repository.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/speaker.dart';
import 'evening_quiz_screen.dart';
import 'manual_mode_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// Bir paket üçün canlı AI kartı açan callback (main.dart-da bağlanır).
typedef OpenLive = void Function(String packId, String title, UserProfile profile);

/// Paket siyahısı — hər birinə toxunanda canlı AI kartı açılır.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.speaker,
    required this.reviewRepository,
    required this.manualContextRepository,
    required this.settingsRepository,
    required this.notificationService,
    required this.profile,
    required this.openLive,
    required this.onOpenChat,
  });

  final PackRepository repository;
  final Speaker speaker;
  final ReviewRepository reviewRepository;
  final ManualContextRepository manualContextRepository;
  final SettingsRepository settingsRepository;
  final NotificationService notificationService;
  final UserProfile profile;
  final OpenLive openLive;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final packs = repository.packs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DilDostu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'AI ilə söhbət',
            onPressed: onOpenChat,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Test bildirişi',
            onPressed: () async {
              // Demo: dərhal "kafe" konteksti üçün bildiriş göstərir ki,
              // bildiriş→toxunma→kart axını sınaqdan keçirilə bilsin.
              const demoPack = 'cafe';
              final title = repository.byId(demoPack)?.titleAz ?? demoPack;
              await notificationService.showNow(demoPack, title);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test bildirişi göndərildi')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ayarlar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(repository: settingsRepository),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistika',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StatsScreen(reviewRepository: reviewRepository),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.place_outlined),
            tooltip: 'İndi haradayam?',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ManualModeScreen(
                  packRepository: repository,
                  reviewRepository: reviewRepository,
                  manualContextRepository: manualContextRepository,
                  speaker: speaker,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.nightlight_round),
            tooltip: 'Axşam təkrarı',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EveningQuizScreen(
                  packRepository: repository,
                  reviewRepository: reviewRepository,
                  speaker: speaker,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: packs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, i) {
          final pack = packs[i];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.translate)),
              title: Text(pack.titleAz),
              subtitle: Text('${pack.words.length} söz'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openLive(pack.packId, pack.titleAz, profile),
            ),
          );
        },
      ),
    );
  }
}
