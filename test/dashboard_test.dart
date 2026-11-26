import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:piuttec_labcontrol/features/auth/data/auth_store.dart';
import 'package:piuttec_labcontrol/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const inventory = MethodChannel('mx.edu.uttec.labcontrol/inventory');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(inventory, (call) async {
          if (call.method == 'list' || call.method == 'listLoans') return [];
          return null;
        });
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
        .setMockMethodCallHandler(inventory, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AuthStore.channel, null);
  });
  testWidgets('Muestra los módulos del piloto', (tester) async {
    await tester.pumpWidget(const LabControlApp());
    await tester.pumpAndSettle();

    expect(find.text('PIUTTEC LabControl'), findsOneWidget);
    expect(find.text('Panel del laboratorio'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Inventario'), 200);
    expect(find.text('Inventario'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Préstamos'), 200);
    expect(find.text('Préstamos'), findsOneWidget);
  });
}
