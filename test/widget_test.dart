import 'package:flutter_test/flutter_test.dart';
import 'package:shelf_scanner_app/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShelfVisionApp());
    expect(find.byType(ShelfVisionApp), findsOneWidget);
  });
}
