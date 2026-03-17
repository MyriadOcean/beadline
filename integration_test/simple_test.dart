import 'package:beadline/main.dart';
import 'package:beadline/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());
  testWidgets('Can call rust function', (WidgetTester tester) async {
    await tester.pumpWidget(const BeadlineApp());
    await tester.pumpAndSettle();
    // Basic smoke test - app should render without crashing
    expect(find.byType(BeadlineApp), findsOneWidget);
  });
}
