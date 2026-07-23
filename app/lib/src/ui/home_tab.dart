import 'package:flutter/material.dart';

import '../data/pack_repository.dart';
import '../models/app_version_info.dart';
import '../models/user_profile.dart';
import 'update_banner.dart';

/// Bir paket üçün canlı AI kartı açan callback (main.dart-da bağlanır).
typedef OpenLive = void Function(String packId, String title, UserProfile profile);

/// Ana səhifə tabı — söz paketləri siyahısı. Toxunma canlı AI kartı açır.
/// "İndi haradayam?" (manual məkan) yuxarı düymədən açılır. Update banner varsa
/// yuxarıda göstərilir.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.repository,
    required this.profile,
    required this.openLive,
    required this.onManualPlace,
    this.availableUpdate,
    this.onInstallUpdate,
  });

  final PackRepository repository;
  final UserProfile profile;
  final OpenLive openLive;
  final VoidCallback onManualPlace;
  final AppVersionInfo? availableUpdate;
  final VoidCallback? onInstallUpdate;

  @override
  Widget build(BuildContext context) {
    final packs = repository.packs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DilDostu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.place_outlined),
            tooltip: 'İndi haradayam?',
            onPressed: onManualPlace,
          ),
        ],
      ),
      body: Column(
        children: [
          if (availableUpdate != null)
            UpdateBanner(info: availableUpdate!, onInstall: onInstallUpdate!),
          Expanded(
            child: ListView.separated(
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
          ),
        ],
      ),
    );
  }
}
