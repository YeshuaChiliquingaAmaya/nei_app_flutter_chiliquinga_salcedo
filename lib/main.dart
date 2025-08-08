import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:vector_math/vector_math.dart' as vector;

import 'path_finder.dart'; // Asegúrate de que este archivo esté en tu proyecto

void main() {
  runApp(const NEIApp());
}

class NEIApp extends StatelessWidget {
  const NEIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navegador de Evacuación Inteligente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- Controladores y Servicios ---
  final MapController _mapController = MapController();
  final FlutterTts _flutterTts = FlutterTts();
  PathFinder? _pathFinder;
  StreamSubscription<Position>? _positionStreamSubscription;

  // --- Estado de la UI y Navegación ---
  bool isLoading = true;
  bool isNavigating = false;
  String loadingMessage = "Cargando datos del mapa...";

  // --- Elementos del Mapa ---
  List<Polyline> initialPaths = [];
  List<Polygon> riskZones = [];
  List<Marker> pointMarkers = [];
  Marker? _userLocationMarker;
  Polyline? _calculatedRoute;

  // --- Lógica de Navegación ---
  int _currentPathIndex = 0;
  final double _arrivalThreshold = 7.0;
  final double _instructionThreshold = 12.0;
  bool _instructionGivenForCurrentIndex = false;
  final double _offRouteThreshold = 15.0; // Distancia para considerar que está fuera de ruta
  DateTime? _lastRecalculationTime;


  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadMapData();
    await _setupTts();
    await _startLocationTracking();
  }

  Future<void> _setupTts() async {
    await _flutterTts.setLanguage("es-EC");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> _loadMapData() async {
    final String response = await rootBundle.loadString('assets/data/mapa_datos_app.json');
    final data = json.decode(response);
    final List features = data['features'];
    _pathFinder = PathFinder(features);

    List<Polyline> tempPaths = [];
    List<Polygon> tempRiskZones = [];
    List<Marker> tempMarkers = [];
    for (var feature in features) {
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      final type = geometry['type'];
      final coordinates = geometry['coordinates'];

      if (type == 'LineString') {
        List<LatLng> points = (coordinates as List).map((c) => LatLng(c[1], c[0])).toList();
        tempPaths.add(Polyline(points: points, color: Colors.grey.withOpacity(0.7), strokeWidth: 2.0));
      } else if (type == 'Point') {
        bool isSafe = properties['es_punto_seguro'] ?? false;
        if(isSafe){
          tempMarkers.add(
            Marker(
              width: 40.0, height: 40.0, point: LatLng(coordinates[1], coordinates[0]),
              child: Icon(Icons.shield, color: Colors.green.shade600, size: 30.0),
            ),
          );
        }
      } else if (type == 'Polygon') {
        List<LatLng> points = (coordinates[0] as List).map((c) => LatLng(c[1], c[0])).toList();
        tempRiskZones.add(Polygon(points: points, color: Colors.red.withAlpha(80), borderColor: Colors.red, borderStrokeWidth: 2));
      }
    }
    setState(() {
      initialPaths = tempPaths;
      riskZones = tempRiskZones;
      pointMarkers = tempMarkers;
    });
  }

  Future<void> _startLocationTracking() async {
    // ... (El manejo de permisos debería estar aquí)

    try {
      Position initialPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final userLatLng = LatLng(initialPosition.latitude, initialPosition.longitude);
      setState(() {
        _userLocationMarker = Marker(
          point: userLatLng,
          width: 80,
          height: 80,
          child: Transform.rotate(
            angle: vector.radians(initialPosition.heading),
            child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 40),
          ),
        );
        isLoading = false;
      });
      _mapController.move(userLatLng, 19.0);
    } catch (e) {
      setState(() { isLoading = false; });
      print("Error al obtener ubicación inicial: $e");
    }

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _userLocationMarker = Marker(
          point: userLatLng,
          width: 80,
          height: 80,
          child: Transform.rotate(
            angle: vector.radians(position.heading),
            child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 40),
          ),
        );
      });

      if (isNavigating) {
        _mapController.move(userLatLng, 19.0);
        _updateNavigation(position);
      }
    });
  }

  void _recenterMapOnUser() {
    if (_userLocationMarker != null) {
      _mapController.move(_userLocationMarker!.point, 19.0);
    }
  }

  void _calculateAndShowRoute() async {
    if (_pathFinder == null || _userLocationMarker == null) {
      _flutterTts.speak("Ubicación no disponible. Espere un momento.");
      return;
    }

    // Si no estamos en modo navegación, lo activamos.
    if (!isNavigating) {
      setState(() { isNavigating = true; });
    }

    setState(() {
      _instructionGivenForCurrentIndex = false;
    });

    final startPoint = _userLocationMarker!.point;
    Node? closestSafePoint = _pathFinder!.findClosestSafePoint(startPoint);
    if (closestSafePoint == null) {
      setState(() { isNavigating = false; });
      return;
    }

    final path = _pathFinder!.findShortestPath(startPoint, closestSafePoint.position);

    if (path.isNotEmpty) {
      setState(() {
        _calculatedRoute = Polyline(points: path, color: Colors.green, strokeWidth: 6.0);
        _currentPathIndex = 0;
      });
      _speak("Ruta de evacuación encontrada. Siga la línea verde.");
    } else {
      setState(() { isNavigating = false; });
      _speak("No se pudo calcular una ruta.");
    }
  }

  void _updateNavigation(Position currentPosition) {
    if (_calculatedRoute == null || _calculatedRoute!.points.isEmpty) return;

    final userPoint = LatLng(currentPosition.latitude, currentPosition.longitude);

    // --- NUEVO: Lógica de Recálculo si está fuera de ruta ---
    if (_isUserOffRoute(userPoint)) {
      final now = DateTime.now();
      // Solo recalcula si han pasado más de 5 segundos desde la última vez
      if (_lastRecalculationTime == null || now.difference(_lastRecalculationTime!).inSeconds > 5) {
        _lastRecalculationTime = now;
        _speak("Recalculando ruta.");
        _calculateAndShowRoute(); // Llama a la función principal de cálculo de nuevo
        return; // Sale para esperar la nueva ruta
      }
    }

    final pathPoints = _calculatedRoute!.points;

    if (_currentPathIndex >= pathPoints.length - 1) {
      final distanceToEnd = Geolocator.distanceBetween(userPoint.latitude, userPoint.longitude, pathPoints.last.latitude, pathPoints.last.longitude);
      if (distanceToEnd < _arrivalThreshold) {
        _speak("Ha llegado a la zona segura.");
        setState(() {
          isNavigating = false;
          _calculatedRoute = null;
        });
        _positionStreamSubscription?.cancel();
      }
      return;
    }

    final nextWaypoint = pathPoints[_currentPathIndex + 1];
    final distanceToNextWaypoint = Geolocator.distanceBetween(userPoint.latitude, userPoint.longitude, nextWaypoint.latitude, nextWaypoint.longitude);

    if (distanceToNextWaypoint < _arrivalThreshold) {
      setState(() {
        _currentPathIndex++;
        _instructionGivenForCurrentIndex = false;
      });
      return;
    }

    if (distanceToNextWaypoint < _instructionThreshold && !_instructionGivenForCurrentIndex) {
      if (_currentPathIndex < pathPoints.length - 2) {
        final currentWaypoint = pathPoints[_currentPathIndex];
        final upcomingWaypoint = pathPoints[_currentPathIndex + 2];

        final bearing = Geolocator.bearingBetween(
          currentWaypoint.latitude, currentWaypoint.longitude,
          nextWaypoint.latitude, nextWaypoint.longitude,
        );
        final nextBearing = Geolocator.bearingBetween(
          nextWaypoint.latitude, nextWaypoint.longitude,
          upcomingWaypoint.latitude, upcomingWaypoint.longitude,
        );

        final turn = _getTurnInstruction(bearing, nextBearing);
        int distance = distanceToNextWaypoint.round();
        _speak("En $distance metros, $turn");

        setState(() {
          _instructionGivenForCurrentIndex = true;
        });
      }
    }
  }

  // --- NUEVO: Función para detectar si el usuario está fuera de ruta ---
  bool _isUserOffRoute(LatLng userPoint) {
    if (_calculatedRoute == null) return false;

    double minDistance = double.infinity;

    // Usamos una aproximación simple: encontrar la distancia al nodo más cercano de la ruta.
    // Para rutas con muchos puntos (como las de GPS), esto es suficientemente preciso.
    for (final point in _calculatedRoute!.points) {
      final d = Geolocator.distanceBetween(
        userPoint.latitude, userPoint.longitude,
        point.latitude, point.longitude,
      );
      if (d < minDistance) {
        minDistance = d;
      }
    }

    return minDistance > _offRouteThreshold;
  }

  String _getTurnInstruction(double currentBearing, double targetBearing) {
    final angle = (targetBearing - currentBearing + 360) % 360;

    if (angle > 330 || angle < 30) {
      return "continúe recto.";
    } else if (angle >= 30 && angle < 150) {
      return "gire a la derecha.";
    } else if (angle >= 150 && angle < 210) {
      return "dé la vuelta.";
    } else {
      return "gire a la izquierda.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navegador de Evacuación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            onPressed: _recenterMapOnUser,
            tooltip: 'Centrar en mi ubicación',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 20), Text(loadingMessage)]))
          : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(-0.3135, -78.4455),
          initialZoom: 19.0,
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
          PolygonLayer(polygons: riskZones),
          PolylineLayer(polylines: initialPaths),
          if (_calculatedRoute != null) PolylineLayer(polylines: [_calculatedRoute!]),
          MarkerLayer(markers: [
            ...pointMarkers,
            if (_userLocationMarker != null) _userLocationMarker!,
          ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isNavigating ? null : _calculateAndShowRoute,
        label: Text(isNavigating ? "NAVEGANDO..." : "EVACUAR"),
        icon: const Icon(Icons.directions_run),
        backgroundColor: isNavigating ? Colors.grey : Colors.red,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
