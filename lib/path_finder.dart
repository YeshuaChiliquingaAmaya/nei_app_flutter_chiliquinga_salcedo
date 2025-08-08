import 'dart:collection';
import 'package:latlong2/latlong.dart';
import 'dart:math';

// Clase para representar un Nodo en nuestro grafo.
class Node {
  final int id;
  final LatLng position;
  final bool isSafePoint;

  Node({required this.id, required this.position, this.isSafePoint = false});
}

// Clase para representar una Arista (un camino) en nuestro grafo.
class Edge {
  final int from;
  final int to;
  double cost;

  Edge({required this.from, required this.to, required this.cost});
}

// La clase principal que contendrá toda la lógica de pathfinding.
class PathFinder {
  final Map<int, Node> _nodes = {};
  final Map<int, List<Edge>> _adjacencyList = {};

  PathFinder(List<dynamic> features) {
    _buildGraph(features);
  }

  void _buildGraph(List<dynamic> features) {
    for (var feature in features) {
      if (feature['geometry']['type'] == 'Point') {
        final properties = feature['properties'];
        final coordinates = feature['geometry']['coordinates'];
        final id = properties['id_osm'];
        final node = Node(
          id: id,
          position: LatLng(coordinates[1], coordinates[0]),
          isSafePoint: properties['es_punto_seguro'] ?? false,
        );
        _nodes[id] = node;
        _adjacencyList[id] = [];
      }
    }

    for (var feature in features) {
      if (feature['geometry']['type'] == 'LineString') {
        final coordinates = feature['geometry']['coordinates'];
        if (coordinates.length < 2) continue;

        final startPoint = LatLng(coordinates[0][1], coordinates[0][0]);
        final endPoint = LatLng(coordinates[1][1], coordinates[1][0]);

        final startNode = _findNearestNode(startPoint, maxDistance: 1.0);
        final endNode = _findNearestNode(endPoint, maxDistance: 1.0);

        if (startNode != null && endNode != null && startNode.id != endNode.id) {
          final cost = feature['properties']['costo_calculado'] as double;
          _adjacencyList[startNode.id]?.add(Edge(from: startNode.id, to: endNode.id, cost: cost));
          _adjacencyList[endNode.id]?.add(Edge(from: endNode.id, to: startNode.id, cost: cost));
        }
      }
    }
  }

  Node? _findNearestNode(LatLng point, {double maxDistance = 100.0}) {
    Node? nearestNode;
    double minDistance = double.infinity;
    final distance = Distance();

    for (var node in _nodes.values) {
      final d = distance.as(LengthUnit.Meter, point, node.position);
      if (d < minDistance) {
        minDistance = d;
        nearestNode = node;
      }
    }
    return minDistance < maxDistance ? nearestNode : null;
  }

  List<Node> get allNodes => _nodes.values.toList();
  List<Node> get safePoints => _nodes.values.where((n) => n.isSafePoint).toList();

  // ***** MÉTODO AÑADIDO *****
  /// Encuentra el punto seguro más cercano a una coordenada dada.
  Node? findClosestSafePoint(LatLng userPosition) {
    Node? closestPoint;
    double minDistance = double.infinity;
    final distance = Distance();

    for (var safePoint in safePoints) {
      final d = distance.as(LengthUnit.Meter, userPosition, safePoint.position);
      if (d < minDistance) {
        minDistance = d;
        closestPoint = safePoint;
      }
    }
    return closestPoint;
  }


  // Implementación de Dijkstra
  List<LatLng> findShortestPath(LatLng startPoint, LatLng endPoint) {
    final startNode = _findNearestNode(startPoint);
    final endNode = _findNearestNode(endPoint);

    if (startNode == null || endNode == null) {
      print("No se pudo encontrar un nodo de inicio o fin en el grafo.");
      return [];
    }

    final costs = <int, double>{};
    final previousNodes = <int, int>{};
    final priorityQueue = PriorityQueue<Pair>((a, b) => a.cost.compareTo(b.cost));

    for (var id in _nodes.keys) {
      costs[id] = double.infinity;
    }
    costs[startNode.id] = 0;
    priorityQueue.add(Pair(startNode.id, 0));

    while (priorityQueue.isNotEmpty) {
      final current = priorityQueue.removeFirst();
      final currentNodeId = current.nodeId;

      if (currentNodeId == endNode.id) break;
      if (current.cost > (costs[currentNodeId] ?? double.infinity)) continue;

      for (var edge in _adjacencyList[currentNodeId]!) {
        final newCost = (costs[currentNodeId] ?? double.infinity) + edge.cost;
        if (newCost < (costs[edge.to] ?? double.infinity)) {
          costs[edge.to] = newCost;
          previousNodes[edge.to] = currentNodeId;
          priorityQueue.add(Pair(edge.to, newCost));
        }
      }
    }

    final path = <LatLng>[];
    int? currentId = endNode.id;
    if (previousNodes[currentId] != null || currentId == startNode.id) {
      while (currentId != null) {
        path.add(_nodes[currentId]!.position);
        currentId = previousNodes[currentId];
      }
    }

    return path.reversed.toList();
  }
}

// Clases de ayuda para Dijkstra
class Pair {
  final int nodeId;
  final double cost;
  Pair(this.nodeId, this.cost);
}

class PriorityQueue<T> {
  final List<T> _elements = [];
  final Comparator<T> _comparator;

  PriorityQueue(this._comparator);

  bool get isNotEmpty => _elements.isNotEmpty;

  void add(T element) {
    _elements.add(element);
    _elements.sort(_comparator);
  }

  T removeFirst() {
    return _elements.removeAt(0);
  }
}
