import 'package:dildostu/src/models/place_summary.dart';
import 'package:dildostu/src/ui/learned_places_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('məkanları say ilə göstərir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LearnedPlacesScreen(
        loader: () async => const [
          PlaceSummary(
              placeType: 'cafe', count: 12, lastSeen: '2026-07-23T09:00:00+00:00', packId: 'cafe'),
          PlaceSummary(
              placeType: 'market', count: 3, lastSeen: '2026-07-22T18:00:00+00:00', packId: 'market'),
        ],
        labelFor: (id) => id == 'cafe' ? 'Kafe' : 'Market',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Kafe'), findsOneWidget);
    expect(find.textContaining('12'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);
  });

  testWidgets('boş halda izahedici mesaj göstərir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LearnedPlacesScreen(loader: () async => const []),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('hələ'), findsOneWidget);
  });
}
