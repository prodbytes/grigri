import 'package:flutter_test/flutter_test.dart';

import 'package:grigri_app/main.dart';

void main() {
  testWidgets('the home screen shows the app name and tagline', (tester) async {
    await tester.pumpWidget(const GrigriApp());

    expect(find.text('Grigri'), findsOneWidget);
    expect(find.text('Find a partner to climb with'), findsOneWidget);
  });
}
