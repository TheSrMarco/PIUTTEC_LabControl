import 'package:flutter/material.dart';
import '../ui/lc.dart';

class PanelScreen extends StatelessWidget {
  const PanelScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Panel de control',
    conMenu: true,
    activo: '/panel',
    boton: 'Ver historial',
    children: [
      const LcSeccion('Estado del inventario'),
      Row(children: [
        Expanded(child: LcKpi('Disponibles', '78')),
        const SizedBox(width: 8),
        Expanded(child: LcKpi('Prestados', '16')),
        const SizedBox(width: 8),
        Expanded(child: LcKpi('Vendidos', '3')),
      ]),
      const LcSeccion('Requieren atención'),
      const LcFila(titulo: 'Entrega sin confirmar', sub: 'Folio 00473 · Revisar'),
      const LcFila(titulo: 'Devolución vencida', sub: 'Folio 00468 · Consultar'),
      const LcSeccion('Movimientos recientes'),
      const LcFila(titulo: 'DTIC-S-008', sub: 'Entrega registrada'),
    ],
  );
}

class InventarioScreen extends StatelessWidget {
  const InventarioScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Inventario y ficha',
    conMenu: true,
    activo: '/inventario',
    boton: 'Registrar equipo',
    children: [
      const LcCampo('Buscar', pista: 'Código, modelo o serie'),
      const LcFila(titulo: 'DTIC-R-014 · Router Cisco 1941', sub: 'Disponible'),
      const LcFila(titulo: 'DTIC-S-008 · Switch Cisco 2960', sub: 'Prestado'),
      const LcSeccion('Ficha de DTIC-R-014'),
      const LcCampo('Serie física', valor: 'FCZ12345567'),
      const LcSeccion('QR digital estable'),
      Container(
        width: 120,
        height: 120,
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kLinea),
        ),
        child: const Icon(Icons.qr_code, size: 96, color: kInk),
      ),
      const LcNota('Mostrar QR · Ver historial'),
    ],
  );
}

class RegistroScreen extends StatelessWidget {
  const RegistroScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Registro individual',
    conMenu: true,
    activo: '/inventario',
    boton: 'Guardar equipo',
    children: [
      const LcCampo('Código único', valor: 'DTIC-R-014'),
      const LcCampo('Categoría', valor: 'Router'),
      const LcCampo('Marca · modelo', valor: 'Cisco · 1941'),
      const LcCampo('Serie o placa física', valor: 'FCZ12345567'),
      LcSelect('Estado',
          valor: 'Disponible',
          opciones: const ['Disponible', 'Reservado', 'Prestado', 'Baja']),
      const LcSeccion('QR del equipo'),
      const LcNota('Se genera al guardar'),
    ],
  );
}

class QrScreen extends StatelessWidget {
  const QrScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Lectura QR',
    boton: 'Confirmar equipo',
    children: [
      const LcFoto('Encuadrar QR digital', icono: Icons.qr_code_scanner),
      const LcSeccion('Equipo identificado'),
      const LcFila(titulo: 'DTIC-R-014', sub: 'Router Cisco 1941'),
      const LcCampo('Serie registrada', valor: 'FCZ12345567'),
      const LcFila(titulo: '[x] Serie física cotejada'),
    ],
  );
}

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Historial auditado',
    conMenu: true,
    activo: '/historial',
    boton: 'Abrir movimiento',
    children: [
      const LcCampo('Buscar', pista: 'Persona, folio, equipo o serie'),
      const LcCampo('Fecha · destino · estado', valor: 'Hoy · Todos · Todos'),
      const LcSeccion('Movimientos registrados'),
      const LcFila(titulo: '09:12  Entrega', sub: 'PR 00473 · DTIC-R-014'),
      const LcFila(titulo: '10:35  Devolución', sub: 'PR 00468 · DTIC-L-019'),
      const LcFila(titulo: '11:10  Prórroga', sub: 'PR 00473 · DTIC-S-008'),
    ],
  );
}

class DanosScreen extends StatelessWidget {
  const DanosScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Daños y extravíos',
    conMenu: true,
    activo: '/danos',
    boton: 'Registrar incidencia',
    children: [
      const LcCampo('Equipo', valor: 'DTIC-R-014 · Router'),
      LcSelect('Tipo de incidencia',
          valor: 'Daño físico',
          opciones: const ['Daño físico', 'Daño funcional', 'Extravío']),
      const LcCampo('Observación', valor: 'Conector de alimentación dañado'),
      const LcFoto('Fotografía del daño'),
      const LcCampo('Estado resultante', valor: 'En revisión'),
    ],
  );
}