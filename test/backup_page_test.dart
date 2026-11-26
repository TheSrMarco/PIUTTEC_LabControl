import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/backups/presentation/backups_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mx.edu.uttec.labcontrol/backup');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'exportBackup') return true;
      if (call.method == 'restoreBackup') {
        return <String, int>{'equipment': 2, 'loans': 3, 'events': 4};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Exporta mediante el canal de Android', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BackupsPage()),
    );

    expect(find.text('Exportar respaldo'), findsOneWidget);
    await tester.tap(find.text('Exportar respaldo'));
    await tester.pumpAndSettle();

    expect(calls, ['exportBackup']);
    expect(
      find.text('Respaldo guardado. Conserva el archivo en un lugar seguro.'),
      findsOneWidget,
    );
  });

  testWidgets('La restauración requiere confirmación', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BackupsPage()),
    );
    await tester.tap(find.text('Restaurar respaldo'));
    await tester.pumpAndSettle();

    expect(find.text('Elegir archivo'), findsOneWidget);
    expect(calls, isEmpty);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.text('Restaurar respaldo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir archivo'));
    await tester.pumpAndSettle();

    expect(calls, ['restoreBackup']);
    expect(find.text('Restaurados 2 equipos y 3 préstamos y 4 eventos de bitácora.'), findsOneWidget);
  });

  testWidgets('Muestra rechazo cuando la base tiene registros', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'device_not_empty');
    });

    await tester.pumpWidget(
      const MaterialApp(home: BackupsPage()),
    );
    await tester.tap(find.text('Restaurar respaldo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir archivo'));
    await tester.pumpAndSettle();

    expect(
      find.text('La base local contiene registros. No se modificó ningún dato.'),
      findsOneWidget,
    );
  });
}
