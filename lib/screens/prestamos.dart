import 'package:flutter/material.dart';
import '../ui/lc.dart';

class TurnoScreen extends StatelessWidget {
  const TurnoScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Inicio de turno',
    boton: 'Iniciar turno',
    ancho: 420,
    children: [
      const LcCampo('Laboratorista', valor: 'Seleccionar cuenta'),
      const LcCampo('PIN personal', valor: '••••', clave: true),
      const LcSeccion('Tableta principal'),
      const LcFila(titulo: 'Vínculo del celular', sub: 'Pendiente'),
      const LcEnlace('+ Escanear QR temporal'),
    ],
  );
}

class IdentificarScreen extends StatelessWidget {
  const IdentificarScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Identificar solicitante',
    boton: 'Guardar solicitante',
    children: [
      LcSelect('Tipo de solicitante',
          valor: 'Estudiante', opciones: const ['Estudiante', 'Docente', 'Externo']),
      const LcCampo('Matrícula', valor: '20261024'),
      const LcCampo('Nombre', valor: 'Andrea López'),
      const LcSeccion('Verificación presencial'),
      const LcFila(titulo: '[x] Credencial verificada'),
      const LcSeccion('Primer registro'),
      const LcNota('Guardar datos del solicitante'),
    ],
  );
}

class PrepararScreen extends StatelessWidget {
  const PrepararScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Preparar préstamo',
    boton: 'Continuar a evidencia',
    children: [
      const LcCampo('Destino', valor: 'Laboratorio de Redes'),
      const LcCampo('Duración', valor: '2 horas'),
      const LcSeccion('Equipos del folio'),
      const LcFila(titulo: 'Router Cisco 1941', sub: 'DTIC-R-014'),
      const LcFila(titulo: 'Switch Cisco 2960', sub: 'DTIC-S-008'),
      const LcEnlace('+ Agregar equipo'),
    ],
  );
}

class EvidenciaScreen extends StatelessWidget {
  const EvidenciaScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Evidencia de entrega',
    boton: 'Guardar evidencia',
    children: [
      const LcCampo('Equipo', valor: 'DTIC-R-014 · Router'),
      const LcFoto('Fotografía inicial'),
      LcSelect('Estado físico',
          valor: 'Sin daños visibles',
          opciones: const ['Sin daños visibles', 'Con daños']),
      const LcCampo('GPS del movimiento', valor: 'Ubicación registrada'),
      const LcEnlace('+ Registrar incidencia GPS'),
    ],
  );
}

class EntregaScreen extends StatelessWidget {
  const EntregaScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Confirmar entrega',
    boton: 'Entregar todos',
    children: [
      const LcCampo('Folio', valor: 'PR-2026-00473'),
      const LcSeccion('Autorización'),
      const LcNota('Confirmada por la tableta'),
      const LcSeccion('Entrega física'),
      const LcFila(titulo: 'Router Cisco 1941', sub: 'Entregar equipo'),
      const LcFila(titulo: 'Switch Cisco 2960', sub: 'Entregar equipo'),
    ],
  );
}

class RecibirScreen extends StatelessWidget {
  const RecibirScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Recibir por equipo',
    boton: 'Confirmar recepción',
    children: [
      const LcCampo('Folio', valor: 'PR-2026-00473'),
      const LcCampo('Solicitante', valor: 'Matrícula verificada'),
      const LcCampo('Equipo', valor: 'Router Cisco 1941'),
      const LcFoto('Foto del estado final'),
      LcSelect('Condición',
          valor: 'Sin daños',
          opciones: const ['Sin daños', 'Daño físico', 'Daño funcional', 'Extravío']),
      const LcCampo('GPS', valor: 'Ubicación registrada'),
    ],
  );
}

class ProrrogaScreen extends StatelessWidget {
  const ProrrogaScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Prórroga por equipo',
    boton: 'Guardar prórroga',
    children: [
      const LcCampo('Folio', valor: 'PR-2026-00473'),
      const LcCampo('Equipo', valor: 'DTIC-S-008 · Switch'),
      const LcCampo('Vencimiento original', valor: 'Hoy · 12:00'),
      const LcCampo('Nuevo vencimiento', valor: 'Hoy · 14:00'),
      const LcCampo('Motivo', valor: 'Práctica de redes en curso'),
    ],
  );
}