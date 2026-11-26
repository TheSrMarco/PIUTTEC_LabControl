import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/dashboard/presentation/operational_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mx.edu.uttec.labcontrol/inventory');
  var availableCount = 2;

  setUp(() {
    availableCount = 2;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'list') {
        return [
          for (var i = 0; i < availableCount; i++)
            <String, String>{
              'code': 'DTIC-$i',
              'name': 'Laptop $i',
              'serial': '',
              'category': '',
              'brand': '',
              'model': '',
              'status': 'available',
              'onLoan': 'false',
            },
          <String, String>{
            'code': 'DTIC-M',
            'name': 'Impresora',
            'serial': '',
            'category': '',
            'brand': '',
            'model': '',
            'status': 'maintenance',
            'onLoan': 'false',
          },
        ];
      }
      if (call.method == 'listLoans') {
        return <Map<String, Object?>>[];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Muestra estadísticas de SQLite, no valores ficticios', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: OperationalSummary()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Resumen operativo'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary-total'))).data,
      '3',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary-available'))).data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary-maintenance'))).data,
      '1',
    );
  });

  testWidgets('Actualizar consulta otra vez la base local', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: OperationalSummary()),
      ),
    ));
    await tester.pumpAndSettle();
    availableCount = 1;

    await tester.tap(find.byTooltip('Actualizar indicadores'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary-available'))).data,
      '1',
    );
  });

  testWidgets('Muestra error con opción de reintentar', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'database_error');
    });

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: OperationalSummary()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar los indicadores'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
