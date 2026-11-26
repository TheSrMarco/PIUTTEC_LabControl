import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/inventory/data/inventory_store.dart';
import 'package:piuttec_labcontrol/features/loans/data/loan_store.dart';
import 'package:piuttec_labcontrol/features/loans/presentation/loan_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mx.edu.uttec.labcontrol/inventory');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'lendMany') return 77;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Equipment makeEquipment(String code) => Equipment(
    code: code,
    name: 'Equipo $code',
    serial: '',
    status: EquipmentStatus.available,
    onLoan: false,
  );

  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => LoanForm(
                    store: const LoanStore(),
                    equipment: [
                      makeEquipment('DTIC-01'),
                      makeEquipment('DTIC-02'),
                    ],
                  ),
                ),
              ),
              child: const Text('Abrir formulario'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
  }

  testWidgets('Exige seleccionar al menos un equipo', (tester) async {
    await openForm(tester);
    await tester.ensureVisible(find.text('Registrar préstamo'));
    await tester.tap(find.text('Registrar préstamo'));
    await tester.pumpAndSettle();

    expect(find.text('Selecciona entre 1 y 25 equipos.'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('Envía dos equipos en una sola operación', (tester) async {
    await openForm(tester);
    await tester.tap(find.byKey(const ValueKey('select-DTIC-01')));
    await tester.tap(find.byKey(const ValueKey('select-DTIC-02')));
    await tester.enterText(find.byType(TextFormField).first, 'Solicitante de prueba');
    await tester.ensureVisible(find.text('Registrar préstamo'));
    await tester.tap(find.text('Registrar préstamo'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'lendMany');
    expect((calls.single.arguments as Map)['codes'], ['DTIC-01', 'DTIC-02']);
  });
}
