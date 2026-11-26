import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/auth_store.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.store = const AuthStore()});
  final AuthStore store;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.changePassword(_old.text, _next.text);
      if (mounted) Navigator.of(context).pop(true);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'invalid_login'
            ? 'La contraseña actual no es correcta.'
            : 'No fue posible cambiar la contraseña.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cambiar contraseña')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('La contraseña se actualiza solo en este dispositivo.'),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _old,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña actual',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Escribe la contraseña actual.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _next,
                  enabled: !_busy,
                  obscureText: true,
                  maxLength: 128,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value?.length ?? 0) < 10 || (value?.length ?? 0) > 128
                          ? 'Usa de 10 a 128 caracteres.'
                          : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _repeat,
                  enabled: !_busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value != _next.text
                      ? 'Las contraseñas no coinciden.'
                      : null,
                ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.password_outlined),
                  label: const Text('Actualizar contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
