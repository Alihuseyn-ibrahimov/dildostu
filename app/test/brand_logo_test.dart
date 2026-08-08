import 'package:dildostu/src/ui/bootstrap_loading_screen.dart';
import 'package:dildostu/src/ui/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BrandLogo wordmark asset-i göstərir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandLogo(height: 48))),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('LachinGo'), findsOneWidget);
  });

  testWidgets('BrandLogo icon variantı göstərir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BrandLogo(
            height: 48,
            variant: BrandLogoVariant.icon,
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('BrandTitle LachinGo mətnini göstərir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandTitle())),
    );
    expect(find.byType(BrandTitle), findsOneWidget);
    expect(find.byType(RichText), findsOneWidget);
  });

  testWidgets('BootstrapLoadingScreen brend elementlərini göstərir',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BootstrapLoadingScreen()),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.textContaining('Lachin'), findsOneWidget);
    expect(find.textContaining('hazırlanır'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
