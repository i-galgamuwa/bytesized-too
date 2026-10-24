import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login screen is shown when no session is saved', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(GpsTrackerApp());
    await tester.pump();

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
