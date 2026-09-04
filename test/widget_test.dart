import 'package:flutter_test/flutter_test.dart';
import 'package:peto_user/main.dart';

void main() {
  testWidgets('PetoUserApp builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const PetoUserApp());
    expect(find.byType(PetoUserApp), findsOneWidget);
  });
}
