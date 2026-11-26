import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piuttec_labcontrol/features/auth/data/auth_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AuthStore.channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getState' => <Object?, Object?>{
            'needsSetup': false,
            'username': 'responsable',
            'role': 'admin',
          },
        'listUsers' => [
            <Object?, Object?>{
              'id': 1,
              'username': 'responsable',
              'role': 'admin',
              'active': true,
            },
            <Object?, Object?>{
              'id': 2,
              'username': 'consulta',
              'role': 'viewer',
              'active': false,
            },
          ],
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AuthStore.channel, null);
  });

  test('Traduce roles y permisos de las sesiones', () async {
    final state = await const AuthStore().state();
    expect(state.username, 'responsable');
    expect(state.role, LabRole.admin);
    expect(LabRole.admin.canManageInventory, true);
    expect(LabRole.operator.canManageInventory, false);
    expect(LabRole.operator.canOperateLoans, true);
    expect(LabRole.viewer.canOperateLoans, false);
    expect(LabRole.viewer.canManageUsers, false);
  });

  test('Administración nunca envía contraseñas en una consulta de usuarios',
      () async {
    const store = AuthStore();
    final users = await store.listUsers();
    expect(users, hasLength(2));
    expect(users.first.role, LabRole.admin);
    expect(users.last.active, false);
    expect(calls.single.method, 'listUsers');
    expect(calls.single.arguments, isNull);
  });

  test('Alta y desactivación utilizan las operaciones nativas autorizadas',
      () async {
    const store = AuthStore();
    await store.createUser('operador1', 'clave-de-prueba', LabRole.operator);
    await store.deactivate(3);
    await store.changePassword('anterior', 'nueva-clave-segura');
    expect(calls.map((call) => call.method), [
      'createUser', 'deactivateUser', 'changePassword',
    ]);
    expect((calls[0].arguments as Map)['role'], 'operator');
    expect((calls[1].arguments as Map)['id'], 3);
    expect((calls[2].arguments as Map)['oldPassword'], 'anterior');
  });
}
