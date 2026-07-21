import 'package:flutter/material.dart';

import '../data/pack_repository.dart';
import '../services/speaker.dart';
import 'card_session_screen.dart';

/// Paket siyahısı — hər birinə toxunanda kart sessiyası açılır.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.speaker,
  });

  final PackRepository repository;
  final Speaker speaker;

  @override
  Widget build(BuildContext context) {
    final packs = repository.packs;
    return Scaffold(
      appBar: AppBar(title: const Text('DilDostu')),
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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CardSessionScreen(pack: pack, speaker: speaker),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
