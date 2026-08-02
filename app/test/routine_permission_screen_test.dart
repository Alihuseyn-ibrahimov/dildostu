import 'package:dildostu/src/ui/routine_permission_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('icazə verilsə uğur mesajı + onGranted çağırılır', (tester) async {
    var granted = false;
    await tester.pumpWidget(MaterialApp(
      home: RoutinePermissionScreen(
        requestAlways: () async => true,
        openSettings: () async {},
        onGranted: () => granted = true,
      ),
    ));
    await tester.tap(find.text('İcazə ver'));
    await tester.pumpAndSettle();
    expect(granted, isTrue);
    expect(find.textContaining('İcazə verildi'), findsOneWidget);
  });

  testWidgets('icazə verilməsə "Ayarları aç" görünür', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoutinePermissionScreen(
        requestAlways: () async => false,
        openSettings: () async {},
        onGranted: () {},
      ),
    ));
    await tester.tap(find.text('İcazə ver'));
    await tester.pumpAndSettle();
    expect(find.text('Ayarları aç'), findsOneWidget);
  });

  testWidgets('batareya optimallaşdırması aktivdirsə xəbərdarlıq göstərir',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoutinePermissionScreen(
        requestAlways: () async => true,
        openSettings: () async {},
        onGranted: () {},
        checkBatteryOptimization: () async => false,
        openBatterySettings: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Batareya optimallaşdırması aktivdir'),
        findsOneWidget);
    expect(find.text('İstisna et'), findsOneWidget);
  });

  testWidgets('istisna edilibsə uğur mesajı göstərir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoutinePermissionScreen(
        requestAlways: () async => true,
        openSettings: () async {},
        onGranted: () {},
        checkBatteryOptimization: () async => true,
        openBatterySettings: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('istisna edilib'), findsOneWidget);
  });

  testWidgets('"İstisna et" toxunulanda openBatterySettings çağırılır',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: RoutinePermissionScreen(
        requestAlways: () async => true,
        openSettings: () async {},
        onGranted: () {},
        checkBatteryOptimization: () async => false,
        openBatterySettings: () async => opened = true,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İstisna et'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });

  testWidgets('checkBatteryOptimization verilməyibsə bölmə göstərilmir',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoutinePermissionScreen(
        requestAlways: () async => true,
        openSettings: () async {},
        onGranted: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Batareya'), findsNothing);
  });
}
