import 'package:flutter_test/flutter_test.dart';

import 'package:eye_care_tab/main.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EyeSaasTabletApp());
    await tester.pump();
    expect(find.byType(EyeSaasTabletApp), findsOneWidget);
  });
}
