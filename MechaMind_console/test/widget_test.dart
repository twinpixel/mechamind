import 'package:flutter_test/flutter_test.dart';
import 'package:mechamind_console/main.dart';

void main() {
  testWidgets('Console app loads', (tester) async {
    await tester.pumpWidget(const MechaMindConsoleApp());
    expect(find.text('MechaMind Console'), findsOneWidget);
    expect(find.text('Server MechaMind'), findsOneWidget);
  });
}
