import 'package:flutter/material.dart';

import 'src/data/pack_repository.dart';
import 'src/services/speaker.dart';
import 'src/ui/home_screen.dart';

void main() {
  runApp(const DilDostuApp());
}

class DilDostuApp extends StatelessWidget {
  const DilDostuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DilDostu',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const _Bootstrap(),
    );
  }
}

/// Paketləri asset-dən yükləyir; yüklənənə qədər spinner, xəta olarsa mesaj.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<PackRepository> _future;
  final Speaker _speaker = TtsSpeaker();

  @override
  void initState() {
    super.initState();
    _future = PackRepository.loadFromAssets();
  }

  @override
  void dispose() {
    _speaker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackRepository>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Paketlər yüklənmədi:\n${snapshot.error}'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return HomeScreen(repository: snapshot.data!, speaker: _speaker);
      },
    );
  }
}
