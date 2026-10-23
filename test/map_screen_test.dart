import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/screens/map_screen.dart';
import 'package:app/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Map screen shows route HUD, Log Visit, and Stop Tracking', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(
          user: AuthUser(driverId: 'D001', name: 'Test Driver'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Log Visit'), findsOneWidget);
    expect(find.text('Stop Tracking'), findsOneWidget);
    expect(find.textContaining('km'), findsWidgets);
  });
}
