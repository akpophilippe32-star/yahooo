import 'package:flutter_test/flutter_test.dart';

import 'package:mealora/main.dart';

void main() {
  testWidgets(
    'Mealora démarre correctement',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MealoraApp(),
      );

      expect(
        find.byType(MealoraApp),
        findsOneWidget,
      );
    },
  );
}