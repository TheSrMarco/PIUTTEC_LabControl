import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/auth_store.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, this.store = const AuthStore()});
  final AuthStore store;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<List<LabUser>> _users = widget.store.listUsers();

  void _refresh() {
    final pending = widget.store.listUsers();
    setState(() { _users = pending; });
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CreateUserDialog(store: widget.store),
    );
    if (mounted && saved == true) {
      _refresh();
      _message('Usuario registrado.');
    }
  }

  Future<void> _disable(LabUser user) async {
    if (!user.active) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text('Desactivar a ' + user.username + '? No podrá iniciar sesión.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await widget.store.deactivate(user.id);
      if (!mounted) return;
      _refresh();
      _message('Usuario desactivado.');
    } on PlatformException catch (error) {
      if (!mounted) return;
      _message(switch (error.code) {
        'access_denied' => 'No puedes desactivar tu propia cuenta.',
        'last_admin' => 'Se requiere un administrador activo.',
        _ => 'No se pudo desactivar al usuario.',
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Usuarios locales'),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Actualizar usuarios',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Crear usuario'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: FutureBuilder<List<LabUser>>(
            future: _users,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: _refresh,
                    child: const Text('No se pudieron cargar usuarios. Reintentar'),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  const Text('Las cuentas y sus permisos solo existen en este dispositivo.'),
                  const SizedBox(height: 16),
                  for (final user in snapshot.requireData)
                    Card.outlined(
                      child: ListTile(
                        leading: Icon(user.active
                            ? Icons.account_circle_outlined
                            : Icons.person_off_outlined),
                        title: Text(user.username),
                        subtitle: Text(user.role.label + ' · ' +
                            (user.active ? 'Activo' : 'Desactivado')),
                        trailing: user.active
                            ? IconButton(
                                onPressed: () => _disable(user),
                                icon: const Icon(Icons.person_off_outlined),
                                tooltip: 'Desactivar usuario',
                              )
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key, required this.store});
  final AuthStore store;

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  LabRole _role = LabRole.operator;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.createUser(_username.text.trim(), _password.text, _role);
      if (mounted) Navigator.of(context).pop(true);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'duplicate_username' => 'Ese usuario ya existe.',
          'access_denied' => 'No tienes permiso para crear cuentas.',
          _ => 'No se pudo registrar la cuenta.',
        };
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Crear usuario'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _username,
                enabled: !_saving,
                maxLength: 32,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Nombre de usuario'),
                validator: (value) =>
                    RegExp(r'^[a-z0-9][a-z0-9_.-]{2,31}$')
                        .hasMatch((value ?? '').trim().toLowerCase())
                        ? null
                        : 'Usa de 3 a 32 caracteres válidos.',
              ),
              DropdownButtonFormField<LabRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: [
                  for (final role in LabRole.values)
                    DropdownMenuItem(value: role, child: Text(role.label)),
                ],
                onChanged: _saving ? null : (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                enabled: !_saving,
                obscureText: true,
                maxLength: 128,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                validator: (value) => (value?.length ?? 0) < 10
                    ? 'Se requieren al menos 10 caracteres.'
                    : null,
              ),
              TextFormField(
                controller: _confirm,
                enabled: !_saving,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                validator: (value) =>
                    value == _password.text ? null : 'Las claves no coinciden.',
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando...' : 'Crear cuenta'),
      ),
    ],
  );
}
