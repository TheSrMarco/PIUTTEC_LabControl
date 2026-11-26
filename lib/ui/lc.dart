import 'package:flutter/material.dart';

// ── Paleta y tokens de diseño ────────────────────────────────────────────────
const kInk = Color(0xFF1F2326);
const kMut = Color(0xFF6E757C);
const kLinea = Color(0xFFE1E4E8);
const kBordeInput = Color(0xFFC9CED4);
const kDark = Color(0xFF24292E);
const kBarra = Color(0xFFF6F8FA);
const kFondo = Color(0xFFF4F5F7);
const kNav = Color(0xFFFAFAFB);

const _kRadio = 6.0;

/// Pantalla base: barra "LabControl", título, contenido y botón inferior.
/// En tableta (≥ 700 px) muestra el menú lateral fijo; en celular, un Drawer.
class LcScaffold extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> children;
  final String? boton;
  final VoidCallback? onBotonPressed;
  final bool cargando;
  final bool conMenu;
  final String? activo;
  final double ancho;
  final List<Widget>? acciones;

  const LcScaffold({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.children,
    this.boton,
    this.onBotonPressed,
    this.cargando = false,
    this.conMenu = false,
    this.activo,
    this.ancho = 660,
    this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esTableta = constraints.maxWidth >= 700;
        final menu = conMenu ? LcMenu(activo: activo, enDrawer: !esTableta) : null;

        final cuerpo = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ancho),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: kInk,
                        ),
                      ),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitulo!,
                          style: const TextStyle(fontSize: 12, color: kMut),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ...children,
                    ],
                  ),
                ),
                if (boton != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: kLinea)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: LcBoton(
                        boton!,
                        onPressed: onBotonPressed,
                        cargando: cargando,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        return Scaffold(
          backgroundColor: kFondo,
          appBar: AppBar(
            backgroundColor: kBarra,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: kInk, size: 20),
            shape: const Border(bottom: BorderSide(color: kLinea)),
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science_outlined, size: 16, color: kInk),
                SizedBox(width: 6),
                Text(
                  'LabControl',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: kInk,
                  ),
                ),
              ],
            ),
            actions: acciones,
          ),
          drawer: menu != null && !esTableta
              ? Drawer(
            backgroundColor: kNav,
            shape: const RoundedRectangleBorder(),
            child: SafeArea(child: menu),
          )
              : null,
          body: Row(
            children: [
              if (menu != null && esTableta)
                Container(
                  width: 175,
                  decoration: const BoxDecoration(
                    color: kNav,
                    border: Border(right: BorderSide(color: kLinea)),
                  ),
                  child: menu,
                ),
              Expanded(child: ColoredBox(color: Colors.white, child: cuerpo)),
            ],
          ),
        );
      },
    );
  }
}

/// Menú lateral con las secciones de LabControl.
class LcMenu extends StatelessWidget {
  final String? activo;
  final bool enDrawer;

  const LcMenu({super.key, this.activo, this.enDrawer = false});

  static const _items = <(String, String, IconData)>[
    ('Panel', '/panel', Icons.dashboard_outlined),
    ('Inventario', '/inventario', Icons.inventory_2_outlined),
    ('Préstamos', '/preparar', Icons.swap_horiz_rounded),
    ('Historial', '/historial', Icons.history_rounded),
    ('Incidencias', '/danos', Icons.report_problem_outlined),
    ('Cuentas', '/cuentas', Icons.people_outline_rounded),
    ('Respaldos', '/respaldo', Icons.backup_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      children: [
        if (enDrawer) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: Text(
              'NAVEGACIÓN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: kMut,
              ),
            ),
          ),
        ],
        for (final (texto, ruta, icono) in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(_kRadio),
              onTap: () {
                if (enDrawer) Navigator.of(context).pop();
                if (ruta != activo) {
                  Navigator.of(context).pushReplacementNamed(ruta);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: ruta == activo ? const Color(0xFFE6E9EC) : null,
                  borderRadius: BorderRadius.circular(_kRadio),
                ),
                child: Row(
                  children: [
                    Icon(
                      icono,
                      size: 16,
                      color: ruta == activo ? kInk : kMut,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        texto,
                        style: TextStyle(
                          fontSize: 12,
                          color: ruta == activo ? kInk : const Color(0xFF495057),
                          fontWeight:
                          ruta == activo ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Botón principal de acción.
class LcBoton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final bool secundario;

  const LcBoton(
      this.texto, {
        super.key,
        this.onPressed,
        this.cargando = false,
        this.secundario = false,
      });

  @override
  Widget build(BuildContext context) {
    final estilo = secundario
        ? OutlinedButton.styleFrom(
      foregroundColor: kInk,
      side: const BorderSide(color: kBordeInput),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kRadio),
      ),
    )
        : FilledButton.styleFrom(
      backgroundColor: kDark,
      foregroundColor: Colors.white,
      disabledBackgroundColor: kMut,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kRadio),
      ),
    );

    final contenido = cargando
        ? const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white,
      ),
    )
        : Text(
      texto,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: secundario
          ? OutlinedButton(
        style: estilo,
        onPressed: cargando ? null : (onPressed ?? () {}),
        child: contenido,
      )
          : FilledButton(
        style: estilo,
        onPressed: cargando ? null : (onPressed ?? () {}),
        child: contenido,
      ),
    );
  }
}

class LcEtiqueta extends StatelessWidget {
  final String texto;
  const LcEtiqueta(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 5),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: kMut,
      ),
    ),
  );
}

class LcSeccion extends StatelessWidget {
  final String texto;
  const LcSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: kInk,
      ),
    ),
  );
}

class LcNota extends StatelessWidget {
  final String texto;
  const LcNota(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, height: 1.35, color: kMut),
    ),
  );
}

class LcEnlace extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;

  const LcEnlace(this.texto, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kInk,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    ),
  );
}

InputDecoration _decoracionInput({String? hintText, Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: kMut, fontSize: 13),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kRadio),
      borderSide: const BorderSide(color: kBordeInput),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kRadio),
      borderSide: const BorderSide(color: kDark, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kRadio),
      borderSide: const BorderSide(color: Color(0xFFB42318)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kRadio),
      borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.4),
    ),
  );
}

/// Campo de captura con borde limpio y soporte opcional de controlador/validación.
class LcCampo extends StatelessWidget {
  final String etiqueta;
  final String? valor;
  final String? pista;
  final bool clave;
  final int maxLineas;
  final TextInputType? tipoTeclado;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const LcCampo(
      this.etiqueta, {
        super.key,
        this.valor,
        this.pista,
        this.clave = false,
        this.maxLineas = 1,
        this.tipoTeclado,
        this.controller,
        this.onChanged,
        this.validator,
      });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LcEtiqueta(etiqueta),
      TextFormField(
        controller: controller,
        initialValue: controller == null ? valor : null,
        obscureText: clave,
        maxLines: clave ? 1 : maxLineas,
        keyboardType: tipoTeclado,
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(fontSize: 13, color: kInk),
        decoration: _decoracionInput(hintText: pista),
      ),
    ],
  );
}

/// Lista desplegable estilizada.
class LcSelect extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final List<String> opciones;
  final ValueChanged<String?>? onChanged;

  const LcSelect(
      this.etiqueta, {
        super.key,
        required this.valor,
        required this.opciones,
        this.onChanged,
      });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LcEtiqueta(etiqueta),
      DropdownButtonFormField<String>(
        initialValue: opciones.contains(valor) ? valor : null,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kMut),
        style: const TextStyle(fontSize: 13, color: kInk),
        decoration: _decoracionInput(),
        items: [
          for (final o in opciones)
            DropdownMenuItem(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged ?? (_) {},
      ),
    ],
  );
}

/// Dato de solo lectura con borde suave.
class LcDato extends StatelessWidget {
  final String texto;
  final String? etiqueta;

  const LcDato(this.texto, {super.key, this.etiqueta});

  @override
  Widget build(BuildContext context) {
    final caja = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kFondo,
        borderRadius: BorderRadius.circular(_kRadio),
        border: Border.all(color: kLinea),
      ),
      child: Text(texto, style: const TextStyle(fontSize: 13, color: kInk)),
    );

    if (etiqueta == null) return caja;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [LcEtiqueta(etiqueta!), caja],
    );
  }
}

/// Renglón de lista con separador inferior, acción táctil y elemento final opcional.
class LcFila extends StatelessWidget {
  final String titulo;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;

  const LcFila({
    super.key,
    required this.titulo,
    this.sub,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kLinea)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: kInk,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: const TextStyle(fontSize: 11, color: kMut),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (onTap != null)
            const Icon(Icons.chevron_right_rounded, size: 18, color: kMut),
        ],
      ),
    ),
  );
}

/// Área de captura o previsualización de fotografía.
class LcFoto extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback? onTap;

  const LcFoto(
      this.texto, {
        super.key,
        this.icono = Icons.photo_camera_outlined,
        this.onTap,
      });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_kRadio),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: kFondo,
          borderRadius: BorderRadius.circular(_kRadio),
          border: Border.all(color: kBordeInput),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 24, color: kMut),
            const SizedBox(height: 6),
            Text(
              texto,
              style: const TextStyle(
                color: kMut,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Indicador numérico del panel.
class LcKpi extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color? acento;

  const LcKpi(this.titulo, this.valor, {super.key, this.acento});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kNav,
      borderRadius: BorderRadius.circular(_kRadio),
      border: Border.all(color: kLinea),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: kMut,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: acento ?? kInk,
          ),
        ),
      ],
    ),
  );
}