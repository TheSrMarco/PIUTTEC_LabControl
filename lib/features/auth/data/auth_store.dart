import 'package:flutter/services.dart';

enum LabRole {
  admin,
  operator,
  viewer;

  String get label => switch (this) {
    LabRole.admin => 'Administrador',
    LabRole.operator => 'Operador',
    LabRole.viewer => 'Consulta',
  };

  bool get canManageInventory => this == LabRole.admin;
  bool get canOperateLoans => this != LabRole.viewer;
  bool get canManageUsers => this == LabRole.admin;
}

class AuthState {
  const AuthState({
    required this.needsSetup,
    required this.username,
    required this.role,
  });

  factory AuthState.fromMap(Map<Object?, Object?> row) {
    final name = row['username'] as String?;
    final roleName = row['role'] as String?;
    return AuthState(
      needsSetup: row['needsSetup'] == true,
      username: name,
      role: switch (roleName) {
        'admin' => LabRole.admin,
        'operator' => LabRole.operator,
        'viewer' => LabRole.viewer,
        _ => null,
      },
    );
  }

  final bool needsSetup;
  final String? username;
  final LabRole? role;
  bool get authenticated => username != null && role != null;
}

class LabUser {
  const LabUser({
    required this.id,
    required this.username,
    required this.role,
    required this.active,
  });

  factory LabUser.fromMap(Map<Object?, Object?> row) => LabUser(
    id: row['id'] as int,
    username: row['username'] as String,
    role: switch (row['role']) {
      'admin' => LabRole.admin,
      'operator' => LabRole.operator,
      _ => LabRole.viewer,
    },
    active: row['active'] == true,
  );

  final int id;
  final String username;
  final LabRole role;
  final bool active;
}

class AuthStore {
  const AuthStore();

  static const channel = MethodChannel('mx.edu.uttec.labcontrol/auth');

  Future<AuthState> state() async {
    final row = await channel.invokeMapMethod<Object?, Object?>('getState');
    if (row == null) throw StateError('No se pudo consultar la sesión');
    return AuthState.fromMap(row);
  }

  Future<AuthState> bootstrap(String username, String password) async {
    final row = await channel.invokeMapMethod<Object?, Object?>(
      'bootstrapAdmin',
      {'username': username, 'password': password},
    );
    if (row == null) throw StateError('No se recibió la sesión');
    return AuthState.fromMap(row);
  }

  Future<AuthState> login(String username, String password) async {
    final row = await channel.invokeMapMethod<Object?, Object?>(
      'login',
      {'username': username, 'password': password},
    );
    if (row == null) throw StateError('No se recibió la sesión');
    return AuthState.fromMap(row);
  }

  Future<void> logout() => channel.invokeMethod<void>('logout');

  Future<List<LabUser>> listUsers() async {
    final rows = await channel.invokeListMethod<Map<Object?, Object?>>(
      'listUsers',
    );
    return [
      for (final row in rows ?? const <Map<Object?, Object?>>[])
        LabUser.fromMap(row),
    ];
  }

  Future<void> createUser(String username, String password, LabRole role) =>
      channel.invokeMethod<void>('createUser', {
        'username': username,
        'password': password,
        'role': role.name,
      });

  Future<void> deactivate(int id) =>
      channel.invokeMethod<void>('deactivateUser', {'id': id});

  Future<void> changePassword(String oldPassword, String newPassword) =>
      channel.invokeMethod<void>('changePassword', {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });
}
