/// Servicio para determinar el piso actual del usuario basado en la altitud.
class FloorService {
  // Define los rangos de altitud para cada piso.
  // ¡DEBES AJUSTAR ESTOS VALORES CON TUS DATOS REALES DE GPX/KML!
  // La clave es el número del piso, y el valor es un mapa con la altitud mínima y máxima.
  final Map<int, Map<String, double>> floorAltitudeRanges = {
    0: {'min': 2528.0, 'max': 2531.0}, // Ejemplo para Planta Baja
    1: {'min': 2531.1, 'max': 2534.0}, // Ejemplo para Primer Piso
    2: {'min': 2534.1, 'max': 2537.0}, // Ejemplo para Segundo Piso
    // Añade más pisos según sea necesario.
  };

  /// Determina el piso más probable basado en la altitud del GPS.
  /// Compara la altitud actual con el centro de cada rango definido
  /// y devuelve el piso cuya diferencia sea menor.
  int getFloorFromAltitude(double altitude) {
    int closestFloor = 0;
    double minDifference = double.infinity;

    floorAltitudeRanges.forEach((floor, range) {
      final double min = range['min']!;
      final double max = range['max']!;
      // Calcula el punto medio del rango de altitud del piso.
      final double center = (min + max) / 2;
      // Calcula qué tan lejos está la altitud actual del centro de este rango.
      final double difference = (altitude - center).abs();

      // Si esta es la diferencia más pequeña que hemos encontrado, este es el piso más probable.
      if (difference < minDifference) {
        minDifference = difference;
        closestFloor = floor;
      }
    });

    // Opcional: Una comprobación de seguridad. Si la altitud está muy lejos
    // de cualquier rango conocido, podría ser una lectura errónea del GPS.
    // Imprime un aviso pero aun así devuelve el piso más cercano.
    if (minDifference > 5.0) { // Umbral de 5 metros de diferencia con el centro del rango.
      print("Advertencia: La altitud ($altitude) está fuera de los rangos esperados. Asumiendo piso $closestFloor, pero con baja confianza.");
    }

    print("Altitud detectada: $altitude -> Piso calculado: $closestFloor");
    return closestFloor;
  }
}
