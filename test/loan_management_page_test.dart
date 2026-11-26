import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/loans/data/loan_store.dart';
import 'package:piuttec_labcontrol/features/loans/presentation/loan_management_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mx.edu.uttec.labcontrol/inventory');
  final recorded = <String>[];

  setUp(() {
    recorded.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listLoanEvents') {
        if (recorded.isEmpty) return <Map<String, Object?>>[];
        return [
          <String, Object?>{
            'id': 9,
            'type': 'incident',
            'detail': recorded.last,
            'createdAt': 4000,
            'oldDueAt': null,
            'newDueAt': null,
          },
        ];
      }
      if (call.method == 'addLoanIncident') {
        recorded.add((call.arguments as Map)['detail'] as String);
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Loan loan({int? returnedAt}) => Loan.fromMap({
    'id': 17,
    'code': 'DTIC-17',
    'name': 'Laptop Dell',
    'borrower': 'Ana',
    'destination': 'Laboratorio 2',
    'lentAt': 1000,
    'returnedAt': returnedAt,
    'dueAt': null,
  });

  testWidgets('Permite registrar y consultar incidencias del folio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoanManagementPage(loan: loan())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Establecer fecha límite'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Cable roto');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guardar incidencia'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar incidencia'));
    await tester.pumpAndSettle();

    expect(recorded, ['Cable roto']);
    expect(find.text('Incidencia'), findsOneWidget);
    expect(find.textContaining('Cable roto'), findsOneWidget);
  });

  testWidgets('Un folio devuelto no ofrece prórroga', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoanManagementPage(loan: loan(returnedAt: 2000))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guardar nueva fecha'), findsNothing);
    expect(find.text('Registrar incidencia'), findsOneWidget);
  });
}
