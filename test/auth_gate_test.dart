import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/app.dart';
import 'package:piuttec_labcontrol/features/auth/data/auth_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const inventory = MethodChannel('mx.edu.uttec.labcontrol/inventory');
  bool initialized = false;
  String? username;
  String? role;
  final methods = <String>[];

  setUp(() {
    initialized = false;
    username = null;
    role = null;
    methods.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AuthStore.channel, (call) async {
      methods.add(call.method);
      if (call.method == 'getState') {
        return {
          'needsSetup': !initialized,
          'username': username,
          'role': role,
        };
      }
      if (call.method == 'bootstrapAdmin') {
        final args = call.arguments as Map;
        initialized = true;
        username = args['username'] as String;
        role = 'admin';
        return {
          'needsSetup': false,
          'username': username,
          'role': role,
        };
      }
      if (call.method == 'logout') {
        username = null;
        role = null;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(inventory, (call) async {
      if (call.method == 'list' || call.method == 'listLoans') return [];
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AuthStore.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(inventory, null);
  });

  testWidgets('Primer arranque exige crear administrador local', (tester) async {
    await tester.pumpWidget(const LabControlApp());
    await tester.pumpAndSettle();

    expect(find.text('Crear administrador local'), findsOneWidget);
    expect(find.text('Panel del laboratorio'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'responsable');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave-larga-123');
    await tester.enterText(find.byType(TextFormField).at(2), 'clave-larga-123');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Crear administrador'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear administrador'));
    await tester.pumpAndSettle();

    expect(methods, contains('bootstrapAdmin'));
    expect(find.text('Panel del laboratorio'), findsOneWidget);
  });

  testWidgets('Consulta no puede modificar préstamos ni abrir administración',
      (tester) async {
    initialized = true;
    username = 'consulta';
    role = 'viewer';
    await tester.pumpWidget(const LabControlApp());
    await tester.pumpAndSettle();

    expect(find.text('Respaldos'), findsNothing);
    expect(find.text('Usuarios'), findsNothing);
    await tester.scrollUntilVisible(find.text('Préstamos'), 160);
    await tester.tap(find.text('Préstamos'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo préstamo'), findsNothing);
    expect(find.text('Aún no hay préstamos registrados.'), findsOneWidget);
  });

  testWidgets('Cerrar sesión vuelve a pedir credenciales', (tester) async {
    initialized = true;
    username = 'administrador';
    role = 'admin';
    await tester.pumpWidget(const LabControlApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(methods, contains('logout'));
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Panel del laboratorio'), findsNothing);
  });
}
