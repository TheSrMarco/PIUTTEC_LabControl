import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/auth/data/auth_store.dart';
import 'package:piuttec_labcontrol/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AuthStore.channel, (call) async {
      if (call.method == 'getState') {
        return <String, Object?>{
          'needsSetup': false,
          'username': 'tester',
          'role': 'admin',
        };
      }
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AuthStore.channel, null);
  });
  const channel = MethodChannel('mx.edu.uttec.labcontrol/inventory');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listLoans') {
        return [
          {
            'id': 17,
            'code': 'DTIC-17',
            'name': 'Laptop Dell',
            'borrower': 'Ana',
            'destination': 'Laboratorio 2',
            'lentAt': 1000,
            'returnedAt': 2000,
          },
        ];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('El panel abre el historial y filtra movimientos', (tester) async {
    await tester.pumpWidget(const LabControlApp());
    await tester.pumpAndSettle();

    expect(find.text('Panel del laboratorio'), findsOneWidget);
    await tester.ensureVisible(find.text('Historial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();

    expect(find.text('Préstamo registrado'), findsOneWidget);
    expect(find.text('Devolución registrada'), findsOneWidget);

    await tester.tap(find.text('Devoluciones'));
    await tester.pumpAndSettle();
    expect(find.text('Préstamo registrado'), findsNothing);
    expect(find.text('Devolución registrada'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pump();
    expect(
      find.text('No se encontraron movimientos con esos filtros.'),
      findsOneWidget,
    );
  });
}
