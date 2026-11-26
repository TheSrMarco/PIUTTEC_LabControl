import 'package:flutter/services.dart';

class EquipmentQr {
  const EquipmentQr();

  static const _channel = MethodChannel('mx.edu.uttec.labcontrol/equipment_qr');
  static const _prefix = 'PIUTTEC-LABCONTROL:1:';
  static final _payloadPattern = RegExp(
    '^$_prefix([A-Z0-9][A-Z0-9_-]{0,31})\$',
  );

  static String? readCode(String payload) =>
      _payloadPattern.firstMatch(payload)?.group(1);

  Future<Uint8List> render(String code) async {
    final bytes = await _channel.invokeMethod<Uint8List>(
      'render',
      '$_prefix$code',
    );
    if (bytes == null) throw PlatformException(code: 'qr_render_failed');
    return bytes;
  }

  Future<String?> scan() => _channel.invokeMethod<String>('scan');
}
