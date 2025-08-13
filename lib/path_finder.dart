import 'dart:collection';
import 'package:latlong2/latlong.dart';
import 'risk_predictor_service.dart';
import 'data_models.dart';

class PathFinder {
  // CORREGIDO: Se quitaron los guiones bajos para hacerlos públicos.
  final Map<int, Node> nodes = {};
  final Map<int, List<Edge>> adjacencyList = {};
  final RiskPredictorService _predictor;

  PathFinder(List<dynamic> features, this._predictor);

  Future<void> buildGraph(List<dynamic> features) async {
    nodes.clear();
    adjacencyList.clear();

    for (var feature in features) {
      if (feature['geometry']['type'] == 'Point') {
        final properties = feature['properties'];
        final coordinates = feature['geometry']['coordinates'];
        final id = properties['id_osm'];
        final floor = properties['piso'] ?? 0;

        final node = Node(
          id: id,
          position: LatLng(coordinates[1], coordinates[0]),
          isSafePoint: properties['es_punto_seguro'] ?? false,
          floor: floor,
        );
        nodes[id] = node;
        adjacencyList[id] = [];
      }
    }

    for (var feature in features) {
      if (feature['geometry']['type'] == 'LineString') {
        final coordinates = feature['geometry']['coordinates'];
        if (coordinates.length < 2) continue;

        final startPoint = LatLng(coordinates[0][1], coordinates[0][0]);
        final endPoint = LatLng(coordinates[1][1], coordinates[1][0]);

        final startNode = findNearestNode(startPoint, maxDistance: 2.0);
        final endNode = findNearestNode(endPoint, maxDistance: 2.0);

        if (startNode != null && endNode != null && startNode.id != endNode.id) {
          final properties = feature['properties'];
          final distance = properties['distancia_metros'] as double;
          PathType type = (properties['tipo'] == 'escalera') ? PathType.stairs : PathType.walkway;
          final riskFactor = await _predictor.predictRisk(distance, type == PathType.stairs, false, 2);
          final cost = distance * riskFactor;

          adjacencyList[startNode.id]?.add(Edge(from: startNode.id, to: endNode.id, baseCost: cost, distance: distance, type: type));
          adjacencyList[endNode.id]?.add(Edge(from: endNode.id, to: startNode.id, baseCost: cost, distance: distance, type: type));
        }
      }
    }
    print("✅ Grafo 3D construido con ${allNodes.length} nodos y conexiones.");
  }

  void addBlockageOnSegment(LatLng segmentStart, LatLng segmentEnd) {
    final startNode = findNearestNode(segmentStart, maxDistance: 2.0);
    final endNode = findNearestNode(segmentEnd, maxDistance: 2.0);
    if (startNode == null || endNode == null) return;

    final double penalty = 99999.0;

    for (var edge in adjacencyList[startNode.id] ?? []) {
      if (edge.to == endNode.id) edge.currentCost += penalty;
    }
    for (var edge in adjacencyList[endNode.id] ?? []) {
      if (edge.to == startNode.id) edge.currentCost += penalty;
    }
    print("Bloqueo añadido en el segmento entre nodos ${startNode.id} y ${endNode.id}");
  }

  void resetCosts() {
    for (var edgeList in adjacencyList.values) {
      for (var edge in edgeList) {
        edge.currentCost = edge.baseCost;
      }
    }
    print("Costos del grafo reseteados a sus valores base.");
  }

  List<LatLng> findShortestPath(LatLng startPoint, LatLng endPoint, int startFloor) {
    final startNode = findNearestNode(startPoint, floor: startFloor);
    final endNode = findNearestNode(endPoint, floor: 0);

    if (startNode == null || endNode == null) {
      print("❌ No se pudo encontrar un nodo de inicio o fin cercano.");
      return [];
    }

    final costs = <int, double>{};
    final previousNodes = <int, int>{};
    final priorityQueue = PriorityQueue<Pair>((a, b) => a.cost.compareTo(b.cost));

    for (var id in nodes.keys) {
      costs[id] = double.infinity;
    }
    costs[startNode.id] = 0;
    priorityQueue.add(Pair(startNode.id, 0));

    while (priorityQueue.isNotEmpty) {
      final current = priorityQueue.removeFirst();
      final currentNodeId = current.nodeId;

      if (currentNodeId == endNode.id) break;
      if (current.cost > (costs[currentNodeId] ?? double.infinity)) continue;

      for (var edge in adjacencyList[currentNodeId]!) {
        final newCost = (costs[currentNodeId] ?? double.infinity) + edge.currentCost;
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
        path.add(nodes[currentId]!.position);
        currentId = previousNodes[currentId];
      }
    }

    return path.reversed.toList();
  }

  // CORREGIDO: El método ahora es público.
  Node? findNearestNode(LatLng point, {int? floor, double maxDistance = 100.0}) {
    Node? nearestNode;
    double minDistance = double.infinity;
    final distance = Distance();

    Iterable<Node> nodesToSearch = floor != null
        ? nodes.values.where((n) => n.floor == floor)
        : nodes.values;

    for (var node in nodesToSearch) {
      final d = distance.as(LengthUnit.Meter, point, node.position);
      if (d < minDistance) {
        minDistance = d;
        nearestNode = node;
      }
    }

    if (nearestNode == null && floor != null) {
      return findNearestNode(point, maxDistance: maxDistance);
    }

    return minDistance < maxDistance ? nearestNode : null;
  }

  List<Node> get allNodes => nodes.values.toList();
  List<Node> get safePoints => nodes.values.where((n) => n.isSafePoint).toList();

  Node? findClosestSafePoint(LatLng userPosition) {
    Node? closestPoint;
    double minDistance = double.infinity;
    final distance = Distance();

    for (var safePoint in safePoints.where((p) => p.floor == 0)) {
      final d = distance.as(LengthUnit.Meter, userPosition, safePoint.position);
      if (d < minDistance) {
        minDistance = d;
        closestPoint = safePoint;
      }
    }
    return closestPoint;
  }
}

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
