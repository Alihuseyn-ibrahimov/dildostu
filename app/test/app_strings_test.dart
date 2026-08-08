import 'package:dildostu/src/l10n/app_strings.dart';
import 'package:dildostu/src/models/ui_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('greetingForHour az', () {
    final s = AppStrings(UiLanguage.az);
    expect(s.greetingForHour(3), 'Gecən xeyrə');
    expect(s.greetingForHour(9), 'Sabahın xeyir');
    expect(s.greetingForHour(14), 'Günortan xeyir');
    expect(s.greetingForHour(21), 'Axşamın xeyir');
  });

  test('greetingForHour en', () {
    final s = AppStrings(UiLanguage.en);
    expect(s.greetingForHour(9), 'Good morning');
  });
}
