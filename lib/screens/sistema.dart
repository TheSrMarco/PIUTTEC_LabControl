import 'package:flutter/material.dart';
import '../ui/lc.dart';

class CuentasScreen extends StatelessWidget {
  const CuentasScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Cuentas por turno',
    conMenu: true,
    activo: '/cuentas',
    boton: 'Agregar laboratorista',
    children: [
      const LcSeccion('Laboratoristas'),
      const LcFila(titulo: 'Gabriel', sub: 'Matutino · Activa'),
      const LcFila(titulo: 'Marco', sub: 'Vespertino · Activa'),
      const LcFila(titulo: 'Yeshiro', sub: 'Mixto · Activa'),
      const LcSeccion('Acceso y recuperación'),
      const LcFila(titulo: 'PIN individual', sub: 'Bloqueo por inactividad'),
      const LcFila(titulo: 'Recuperar acceso', sub: 'Registrar en auditoría'),
    ],
  );
}

class RespaldoScreen extends StatelessWidget {
  const RespaldoScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Respaldo y conexión',
    conMenu: true,
    activo: '/respaldo',
    boton: 'Revisar pendientes',
    children: [
      const LcSeccion('Red del laboratorio'),
      const LcFila(titulo: 'Tableta principal', sub: 'Wi-Fi local disponible'),
      const LcFila(titulo: 'Operaciones pendientes', sub: '2 por sincronizar'),
      const LcFila(titulo: 'Copias de seguridad', sub: 'SQLite y fotografías'),
      const LcFila(titulo: 'Exportación externa', sub: 'Semanal'),
      const LcFila(titulo: 'Último respaldo', sub: 'Verificar integridad'),
    ],
  );
}

class RestaurarScreen extends StatelessWidget {
  const RestaurarScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Restaurar respaldo',
    conMenu: true,
    activo: '/respaldo',
    boton: 'Seleccionar respaldo',
    children: [
      const LcCampo('Última copia verificada', valor: 'Hoy · 07:00'),
      const LcCampo('Contenido', valor: 'Base SQLite y fotografías'),
      const LcSeccion('Recuperación'),
      const LcFila(titulo: 'Exportar copia', sub: 'Guardar en medio externo'),
      const LcFila(titulo: 'Restaurar copia', sub: 'Seleccionar archivo verificado'),
      const LcFila(titulo: 'Después de restaurar', sub: 'Conciliar operaciones pendientes'),
    ],
  );
}

class ColaScreen extends StatelessWidget {
  const ColaScreen({super.key});

  @override
  Widget build(BuildContext context) => LcScaffold(
    titulo: 'Cola de operaciones',
    boton: 'Sincronizar ahora',
    children: [
      const LcSeccion('Red local'),
      const LcFila(titulo: 'Tableta principal', sub: 'Disponible'),
      const LcSeccion('Pendientes'),
      const LcFila(titulo: 'Registro de devolución', sub: 'Esperando confirmación'),
      const LcFila(titulo: 'Fotografía final', sub: 'Pendiente de subir'),
      const LcSeccion('Último intento'),
      const LcFila(titulo: 'Último intento', sub: '11:42'),
    ],
  );
}