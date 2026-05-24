import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mechamind_gui/main.dart';
import 'package:mechamind_gui/providers/game_controller.dart';

void main() {
  testWidgets('App loads setup screen', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameController(),
        child: const MechaMindApp(),
      ),
    );
    expect(find.text('MechaMind Pilot'), findsWidgets);
  });
}
