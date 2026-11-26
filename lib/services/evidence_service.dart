import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class EvidenciaResultado {
  final String? fotoPath;
  final double? lat;
  final double? lng;
  final String gpsEstado;

  EvidenciaResultado({this.fotoPath, this.lat, this.lng, required this.gpsEstado});
}

class EvidenceService {
  static final ImagePicker _picker = ImagePicker();

  static Future<EvidenciaResultado> capturarFotoYGps() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );

    if (photo == null) {
      throw Exception('La fotografía de evidencia es obligatoria.');
    }

    double? lat;
    double? lng;
    String gpsEstado = 'OK';

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        gpsEstado = 'FALLO_GPS_INCIDENCIA';
      } else {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      gpsEstado = 'FALLO_GPS_INCIDENCIA';
    }

    return EvidenciaResultado(
      fotoPath: photo.path,
      lat: lat,
      lng: lng,
      gpsEstado: gpsEstado,
    );
  }
}