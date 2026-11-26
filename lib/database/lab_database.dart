import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/lab_models.dart';

class LabDatabase {
  static final LabDatabase instance = LabDatabase._init();
  static Database? _database;

  LabDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('piuttec_labcontrol.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE equipos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo_qr TEXT UNIQUE NOT NULL,
        serie TEXT NOT NULL,
        categoria TEXT NOT NULL,
        marca TEXT NOT NULL,
        modelo TEXT NOT NULL,
        estado TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        motivo_baja TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE prestamos_detalle (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folio TEXT NOT NULL,
        equipo_qr TEXT NOT NULL,
        solicitante_id TEXT NOT NULL,
        destino TEXT NOT NULL,
        fecha_salida TEXT NOT NULL,
        fecha_vencimiento_original TEXT NOT NULL,
        fecha_vencimiento_actual TEXT NOT NULL,
        fecha_devolucion TEXT,
        foto_entrega_path TEXT NOT NULL,
        foto_devolucion_path TEXT,
        latitud REAL,
        longitud REAL,
        gps_estado TEXT NOT NULL,
        estado_entrega TEXT NOT NULL,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE trazabilidad (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        accion TEXT NOT NULL,
        folio TEXT,
        equipo_qr TEXT,
        usuario TEXT NOT NULL,
        detalle TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE incidencias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        equipo_qr TEXT,
        folio TEXT,
        tipo TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        evidencia_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE prorrogas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_registro TEXT NOT NULL,
        folio TEXT NOT NULL,
        equipo_qr TEXT NOT NULL,
        vencimiento_anterior TEXT NOT NULL,
        nuevo_vencimiento TEXT NOT NULL,
        motivo TEXT NOT NULL,
        autorizado_por TEXT NOT NULL
      )
    ''');

    await db.insert('equipos', {
      'codigo_qr': 'UTTEC-OSC-001',
      'serie': 'SN-994821A',
      'categoria': 'Osciloscopio',
      'marca': 'Tektronix',
      'modelo': 'TBS1052C',
      'estado': 'DISPONIBLE',
      'is_active': 1,
    });
    await db.insert('equipos', {
      'codigo_qr': 'UTTEC-MUL-014',
      'serie': 'SN-773120B',
      'categoria': 'Multímetro',
      'marca': 'Fluke',
      'modelo': '117 True-RMS',
      'estado': 'DISPONIBLE',
      'is_active': 1,
    });
  }

  Future<Equipo?> consultarPorQr(String qr) async {
    final db = await instance.database;
    final res = await db.query('equipos', where: 'codigo_qr = ?', whereArgs: [qr]);
    if (res.isNotEmpty) return Equipo.fromMap(res.first);
    return null;
  }

  Future<List<Equipo>> listarEquipos({bool incluirBajas = false}) async {
    final db = await instance.database;
    final res = await db.query(
      'equipos',
      where: incluirBajas ? null : 'is_active = 1',
      orderBy: 'id DESC',
    );
    return res.map((e) => Equipo.fromMap(e)).toList();
  }

  Future<void> registrarEquipo(Equipo eq, String usuario) async {
    final db = await instance.database;
    await db.insert('equipos', eq.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await registrarAuditoria('ALTA_EQUIPO', null, eq.codigoQr, usuario, 'Alta de ${eq.marca} ${eq.modelo} (Serie: ${eq.serie})');
  }

  Future<void> bajaLogicaEquipo(String qr, String motivo, String usuario) async {
    final db = await instance.database;
    await db.update(
      'equipos',
      {'is_active': 0, 'estado': 'BAJA', 'motivo_baja': motivo},
      where: 'codigo_qr = ?',
      whereArgs: [qr],
    );
    await registrarAuditoria('BAJA_LOGICA', null, qr, usuario, 'Baja lógica aplicada. Motivo: $motivo');
  }

  Future<void> registrarEntregaEquipo(PrestamoDetalle item, String laboratista) async {
    final db = await instance.database;
    await db.insert('prestamos_detalle', item.toMap());
    await db.update('equipos', {'estado': 'PRESTADO'}, where: 'codigo_qr = ?', whereArgs: [item.equipoQr]);
    await registrarAuditoria(
      'ENTREGA_EQUIPO',
      item.folio,
      item.equipoQr,
      laboratista,
      'Entregado a ${item.solicitanteId} en ${item.destino}. GPS: ${item.gpsEstado}',
    );
  }

  Future<void> registrarDevolucionIndividual({
    required int detalleId,
    required String folio,
    required String equipoQr,
    required String fotoDevolucionPath,
    required bool conDano,
    String? descripcionDano,
    required String laboratista,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'prestamos_detalle',
      {
        'estado_entrega': 'DEVUELTO',
        'fecha_devolucion': now,
        'foto_devolucion_path': fotoDevolucionPath,
      },
      where: 'id = ?',
      whereArgs: [detalleId],
    );

    final nuevoEstadoEquipo = conDano ? 'EN_REVISION' : 'DISPONIBLE';
    await db.update('equipos', {'estado': nuevoEstadoEquipo}, where: 'codigo_qr = ?', whereArgs: [equipoQr]);

    if (conDano) {
      await registrarIncidencia(
        equipoQr: equipoQr,
        folio: folio,
        tipo: 'DAÑO_EN_DEVOLUCION',
        descripcion: descripcionDano ?? 'Daño físico detectado al devolver',
        evidenciaPath: fotoDevolucionPath,
        usuario: laboratista,
      );
    }

    await registrarAuditoria(
      'DEVOLUCION_EQUIPO',
      folio,
      equipoQr,
      laboratista,
      conDano ? 'Devuelto con daño -> Estado EN_REVISION' : 'Devuelto en buen estado -> DISPONIBLE',
    );
  }

  Future<void> registrarProrroga({
    required int detalleId,
    required String folio,
    required String equipoQr,
    required String vencimientoAnterior,
    required String nuevoVencimiento,
    required String motivo,
    required String laboratista,
  }) async {
    final db = await instance.database;
    await db.insert('prorrogas', {
      'fecha_registro': DateTime.now().toIso8601String(),
      'folio': folio,
      'equipo_qr': equipoQr,
      'vencimiento_anterior': vencimientoAnterior,
      'nuevo_vencimiento': nuevoVencimiento,
      'motivo': motivo,
      'autorizado_por': laboratista,
    });

    await db.update(
      'prestamos_detalle',
      {'fecha_vencimiento_actual': nuevoVencimiento},
      where: 'id = ?',
      whereArgs: [detalleId],
    );

    await registrarAuditoria(
      'PRORROGA',
      folio,
      equipoQr,
      laboratista,
      'Prórroga hasta $nuevoVencimiento (Original preservado). Motivo: $motivo',
    );
  }

  Future<void> registrarIncidencia({
    String? equipoQr,
    String? folio,
    required String tipo,
    required String descripcion,
    String? evidenciaPath,
    required String usuario,
  }) async {
    final db = await instance.database;
    await db.insert('incidencias', {
      'fecha': DateTime.now().toIso8601String(),
      'equipo_qr': equipoQr,
      'folio': folio,
      'tipo': tipo,
      'descripcion': descripcion,
      'evidencia_path': evidenciaPath,
    });
    await registrarAuditoria('INCIDENCIA', folio, equipoQr, usuario, '[$tipo] $descripcion');
  }

  Future<void> registrarAuditoria(String accion, String? folio, String? qr, String usuario, String detalle) async {
    final db = await instance.database;
    await db.insert('trazabilidad', {
      'fecha': DateTime.now().toIso8601String(),
      'accion': accion,
      'folio': folio,
      'equipo_qr': qr,
      'usuario': usuario,
      'detalle': detalle,
    });
  }

  Future<String> exportarRespaldoSQLite() async {
    final dbPath = await getDatabasesPath();
    final sourceFile = File(join(dbPath, 'piuttec_labcontrol.db'));
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = join(dbPath, 'respaldo_piuttec_$timestamp.db');
    await sourceFile.copy(backupPath);
    return backupPath;
  }

  Future<void> restaurarRespaldoSQLite(String backupFilePath) async {
    final dbPath = await getDatabasesPath();
    final targetPath = join(dbPath, 'piuttec_labcontrol.db');
    await _database?.close();
    _database = null;
    await File(backupFilePath).copy(targetPath);
    await database;
  }
}