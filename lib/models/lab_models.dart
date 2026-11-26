class Equipo {
  final int? id;
  final String codigoQr;
  final String serie;
  final String categoria;
  final String marca;
  final String modelo;
  final String estado;
  final bool isActive;
  final String? motivoBaja;

  Equipo({
    this.id,
    required this.codigoQr,
    required this.serie,
    required this.categoria,
    required this.marca,
    required this.modelo,
    this.estado = 'DISPONIBLE',
    this.isActive = true,
    this.motivoBaja,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo_qr': codigoQr,
      'serie': serie,
      'categoria': categoria,
      'marca': marca,
      'modelo': modelo,
      'estado': estado,
      'is_active': isActive ? 1 : 0,
      'motivo_baja': motivoBaja,
    };
  }

  factory Equipo.fromMap(Map<String, dynamic> map) {
    return Equipo(
      id: map['id'],
      codigoQr: map['codigo_qr'],
      serie: map['serie'],
      categoria: map['categoria'],
      marca: map['marca'],
      modelo: map['modelo'],
      estado: map['estado'],
      isActive: map['is_active'] == 1,
      motivoBaja: map['motivo_baja'],
    );
  }
}

class PrestamoDetalle {
  final int? id;
  final String folio;
  final String equipoQr;
  final String solicitanteId;
  final String destino;
  final String fechaSalida;
  final String fechaVencimientoOriginal;
  final String fechaVencimientoActual;
  final String? fechaDevolucion;
  final String fotoEntregaPath;
  final String? fotoDevolucionPath;
  final double? latitud;
  final double? longitud;
  final String gpsEstado;
  final String estadoEntrega;
  final int syncStatus;

  PrestamoDetalle({
    this.id,
    required this.folio,
    required this.equipoQr,
    required this.solicitanteId,
    required this.destino,
    required this.fechaSalida,
    required this.fechaVencimientoOriginal,
    required this.fechaVencimientoActual,
    this.fechaDevolucion,
    required this.fotoEntregaPath,
    this.fotoDevolucionPath,
    this.latitud,
    this.longitud,
    this.gpsEstado = 'OK',
    this.estadoEntrega = 'ENTREGADO',
    this.syncStatus = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folio': folio,
      'equipo_qr': equipoQr,
      'solicitante_id': solicitanteId,
      'destino': destino,
      'fecha_salida': fechaSalida,
      'fecha_vencimiento_original': fechaVencimientoOriginal,
      'fecha_vencimiento_actual': fechaVencimientoActual,
      'fecha_devolucion': fechaDevolucion,
      'foto_entrega_path': fotoEntregaPath,
      'foto_devolucion_path': fotoDevolucionPath,
      'latitud': latitud,
      'longitud': longitud,
      'gps_estado': gpsEstado,
      'estado_entrega': estadoEntrega,
      'sync_status': syncStatus,
    };
  }

  factory PrestamoDetalle.fromMap(Map<String, dynamic> map) {
    return PrestamoDetalle(
      id: map['id'],
      folio: map['folio'],
      equipoQr: map['equipo_qr'],
      solicitanteId: map['solicitante_id'],
      destino: map['destino'],
      fechaSalida: map['fecha_salida'],
      fechaVencimientoOriginal: map['fecha_vencimiento_original'],
      fechaVencimientoActual: map['fecha_vencimiento_actual'],
      fechaDevolucion: map['fecha_devolucion'],
      fotoEntregaPath: map['foto_entrega_path'],
      fotoDevolucionPath: map['foto_devolucion_path'],
      latitud: map['latitud'],
      longitud: map['longitud'],
      gpsEstado: map['gps_estado'] ?? 'OK',
      estadoEntrega: map['estado_entrega'],
      syncStatus: map['sync_status'] ?? 0,
    );
  }
}