import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dashboard/dashboard_page.dart';
import '../data/auth_store.dart';

/// El panel solo se monta cuando el canal nativo confirma la sesión.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.store = const AuthStore()});

  final AuthStore store;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<AuthState> _state = widget.store.state();

  void _authenticated(AuthState state) {
    setState(() {
      _state = Future.value(state);
    });
  }

  Future<void> _logout() async {
    await widget.store.logout();
    if (mounted) {
      setState(() {
        _state = widget.store.state();
      });
    }
  }

  void _retry() {
    setState(() {
      _state = widget.store.state();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AuthState>(
    future: _state,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('PIUTTEC LabControl')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo verificar el acceso local.'),
                TextButton(onPressed: _retry, child: const Text('Reintentar')),
              ],
            ),
          ),
        );
      }
      final auth = snapshot.requireData;
      if (!auth.authenticated) {
        return AuthLoginPage(
          needsSetup: auth.needsSetup,
          store: widget.store,
          onAuthenticated: _authenticated,
        );
      }
      return DashboardPage(
        session: auth,
        onLogout: _logout,
      );
    },
  );
}

class AuthLoginPage extends StatefulWidget {
  const AuthLoginPage({
    super.key,
    required this.needsSetup,
    required this.store,
    required this.onAuthenticated,
  });

  final bool needsSetup;
  final AuthStore store;
  final ValueChanged<AuthState> onAuthenticated;

  @override
  State<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends State<AuthLoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = widget.needsSetup
          ? await widget.store.bootstrap(
              _username.text.trim(),
              _password.text,
            )
          : await widget.store.login(
              _username.text.trim(),
              _password.text,
            );
      if (mounted) widget.onAuthenticated(state);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'invalid_login' => 'Usuario o contraseña incorrectos.',
          'too_many_attempts' =>
            'Demasiados intentos. Inténtalo después de un minuto.',
          'already_initialized' =>
            'Ya existe un administrador. Inicia sesión.',
          'duplicate_username' => 'Ese usuario ya existe.',
          'invalid_user' =>
            'Revisa el nombre de usuario y la contraseña.',
          _ => 'No se pudo completar el inicio de sesión.',
        };
      });
    } on MissingPluginException {
      if (mounted) setState(() {
        _error = 'La autenticación requiere ejecutar la app Android.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PIUTTEC LabControl')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _form,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.shield_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  widget.needsSetup
                      ? 'Crear administrador local'
                      : 'Iniciar sesión',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.needsSetup
                      ? 'Esta instalación todavía no tiene usuarios. '
                        'Crea la primera cuenta de administrador y conserva '
                        'su contraseña en un lugar seguro.'
                      : 'Accede con una cuenta registrada en este dispositivo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _username,
                  enabled: !_busy,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    hintText: 'ej. responsable_laboratorio',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!RegExp(r'^[a-z0-9][a-z0-9_.-]{2,31}$')
                        .hasMatch((value ?? '').trim().toLowerCase())) {
                      return 'Usa entre 3 y 32 caracteres: a-z, 0-9, _, . o -.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _hidePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _hidePassword = !_hidePassword,
                      ),
                      icon: Icon(_hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (value) => widget.needsSetup &&
                          ((value?.length ?? 0) < 10 || (value?.length ?? 0) > 128)
                      ? 'La contraseña debe tener entre 10 y 128 caracteres.'
                      : (value ?? '').isEmpty ? 'Ingresa la contraseña.' : null,
                ),
                if (widget.needsSetup) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: _hidePassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value != _password.text
                        ? 'Las contraseñas no coinciden.'
                        : null,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.login),
                  label: Text(_busy
                      ? 'Comprobando...'
                      : widget.needsSetup
                          ? 'Crear administrador'
                          : 'Entrar'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Las cuentas son locales; no se sincronizan entre dispositivos.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
