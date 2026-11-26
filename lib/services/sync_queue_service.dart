import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../database/lab_database.dart';
import '../models/lab_models.dart';

class SyncQueueService {
  static HttpServer? _server;

  static Future<String> iniciarServidorTableta() async {
    if (_server != null) return 'Activo en puerto 8085';

    final router = Router();

    router.get('/status', (Request req) {
      return Response.ok(jsonEncode({'ok': true, 'app': 'PIUTTEC_LabControl'}));
    });

    router.post('/api/sync-movimiento', (Request req) async {
      final data = jsonDecode(await req.readAsString());
      final dbPath = await getDatabasesPath();

      String rutaFotoLocal = '';
      if (data['foto_b64'] != null && data['foto_b64'].toString().isNotEmpty) {
        final bytes = base64Decode(data['foto_b64']);
        final archivo = File(p.join(dbPath, 'ev_${DateTime.now().millisecondsSinceEpoch}.jpg'));
        await archivo.writeAsBytes(bytes);
        rutaFotoLocal = archivo.path;
      }

      final detalle = PrestamoDetalle(
        folio: data['folio'],
        equipoQr: data['equipo_qr'],
        solicitanteId: data['solicitante_id'],
        destino: data['destino'],
        fechaSalida: data['fecha_salida'],
        fechaVencimientoOriginal: data['fecha_vencimiento_original'],
        fechaVencimientoActual: data['fecha_vencimiento_actual'],
        fotoEntregaPath: rutaFotoLocal,
        latitud: data['latitud'],
        longitud: data['longitud'],
        gpsEstado: data['gps_estado'],
        estadoEntrega: 'ENTREGADO',
        syncStatus: 1,
      );

      await LabDatabase.instance.registrarEntregaEquipo(detalle, data['laboratorista'] ?? 'SyncMovil');
      return Response.ok(jsonEncode({'ack': true, 'folio': detalle.folio}));
    });

    _server = await shelf_io.serve(router.call, InternetAddress.anyIPv4, 8085);
    return 'IP Local: ${_server!.address.address}:8085';
  }

  static Future<int> enviarColaATableta(String tabletIp, String laboratorista) async {
    final db = await LabDatabase.instance.database;
    final pendientes = await db.query('prestamos_detalle', where: 'sync_status = 0');
    int enviados = 0;

    for (final item in pendientes) {
      String fotoB64 = '';
      final path = item['foto_entrega_path']?.toString() ?? '';
      if (path.isNotEmpty && File(path).existsSync()) {
        fotoB64 = base64Encode(await File(path).readAsBytes());
      }

      final payload = Map<String, dynamic>.from(item);
      payload['foto_b64'] = fotoB64;
      payload['laboratorista'] = laboratorista;

      final resp = await http.post(
        Uri.parse('http://$tabletIp:8085/api/sync-movimiento'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        await db.update('prestamos_detalle', {'sync_status': 1}, where: 'id = ?', whereArgs: [item['id']]);
        enviados++;
      }
    }
    return enviados;
  }
}