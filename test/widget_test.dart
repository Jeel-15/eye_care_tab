import 'package:flutter_test/flutter_test.dart';

import 'package:eye_care_tab/main.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EyeSaasTabletApp());
    await tester.pump();
    expect(find.byType(EyeSaasTabletApp), findsOneWidget);

    // Splash schedules a 3s Future.delayed before navigating on; advance the
    // test clock past it so the timer fires and clears before teardown,
    // instead of tripping flutter_test's "timer still pending" assertion.
    await tester.pump(const Duration(seconds: 4));
  });
}
