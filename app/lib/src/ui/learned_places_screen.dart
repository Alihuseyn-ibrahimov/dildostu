import 'package:flutter/material.dart';

import '../models/place_summary.dart';

/// "AI nəyi öyrənib" — serverdəki rutin aqreqatını göstərir. `loader` summary-ni
/// gətirir (main.dart-da RoutineClient-ə bağlanır; testdə fake).
class LearnedPlacesScreen extends StatefulWidget {
  const LearnedPlacesScreen({
    super.key,
    required this.loader,
    this.labelFor,
  });

  final Future<List<PlaceSummary>> Function() loader;

  /// place_type/pack_id → görünən AZ ad (məs. 'cafe' → 'Kafe'). Yoxdursa xam id.
  final String Function(String id)? labelFor;

  @override
  State<LearnedPlacesScreen> createState() => _LearnedPlacesScreenState();
}

class _LearnedPlacesScreenState extends State<LearnedPlacesScreen> {
  late Future<List<PlaceSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  String _label(PlaceSummary p) {
    final id = p.packId ?? p.placeType;
    return widget.labelFor?.call(id) ?? p.placeType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI nəyi öyrənib')),
      body: FutureBuilder<List<PlaceSummary>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final places = snap.data!;
          if (places.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'AI hələ heç nə öyrənməyib. Bir az gəz — tez-tez getdiyin '
                  'yerləri öyrənəcək və orada sənə söz öyrədəcək 🙂',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: places.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final p = places[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.place)),
                  title: Text(_label(p)),
                  subtitle: Text('${p.count} dəfə'),
                  trailing: Text(
                    _shortDate(p.lastSeen),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ISO tarixdən yalnız "YYYY-MM-DD" hissəsi (sadə, lokallaşdırmasız).
  String _shortDate(String iso) {
    final t = iso.indexOf('T');
    return t > 0 ? iso.substring(0, t) : iso;
  }
}
