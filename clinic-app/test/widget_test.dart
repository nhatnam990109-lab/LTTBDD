import 'package:cliniccare/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logo phòng khám hiển thị tên ClinicCare', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Logo())));
    expect(find.text('ClinicCare'), findsOneWidget);
    expect(find.text('PHÒNG KHÁM VÌ DÂN'), findsOneWidget);
  });
}
