/// Contiene los modelos de datos para el grafo de navegación.
import 'package:latlong2/latlong.dart';

/// Define los tipos de caminos que pueden existir en el grafo.
enum PathType {
  walkway, // Pasillo normal
  stairs,  // Escaleras
  elevator // Ascensor (para futuras implementaciones)
}

/// Representa un punto en el grafo (una intersección, una puerta, etc.).
class Node {
  final int id;
  final LatLng position;
  final int floor; // <-- AÑADIDO: El piso donde se encuentra el nodo.
  final bool isSafePoint;

  Node({
    required this.id,
    required this.position,
    required this.floor,
    this.isSafePoint = false,
  });
}

/// Representa una conexión (un camino) entre dos nodos.
class Edge {
  final int from;
  final int to;
  final double baseCost;
  double currentCost;
  final double distance;
  final PathType type; // <-- AÑADIDO: Para identificar si es una escalera.

  Edge({
    required this.from,
    required this.to,
    required this.baseCost,
    required this.distance,
    this.type = PathType.walkway,
  }) : currentCost = baseCost;
}
