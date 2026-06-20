import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_modal_flutter/widgets/status_chip.dart';

void main() {
  testWidgets('status chip displays its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusChip(label: 'Connected', color: Colors.green),
        ),
      ),
    );

    expect(find.text('Connected'), findsOneWidget);
  });
}
