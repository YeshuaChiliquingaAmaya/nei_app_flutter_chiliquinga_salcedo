import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:vector_math/vector_math.dart' as vector;

// --> 1. IMPORTAMOS LOS NUEVOS ARCHIVOS QUE CREAMOS
import 'path_finder.dart';
import 'risk_predictor_service.dart';
import 'data_models.dart'; // Contiene las clases Node y Edge actualizadas
import 'floor_service.dart'; // Contiene la lógica para determinar el piso

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
  final RiskPredictorService _riskPredictor = RiskPredictorService();
  PathFinder? _pathFinder;
  StreamSubscription<Position>? _positionStreamSubscription;

  final FloorService _floorService = FloorService();
  int _currentUserFloor = 0; // Por defecto, asumimos planta baja

  // --- Estado de la UI y Navegación ---
  bool isLoading = true;
  String loadingMessage = "Verificando permisos..."; // Mensaje inicial

  List<Polyline> initialPaths = [];
  List<Polygon> riskZones = [];
  List<Marker> pointMarkers = [];
  Marker? _userLocationMarker;
  Polyline? _calculatedRoute;

  // --- Lógica de Navegación ---
  bool isNavigating = false;
  int _currentPathIndex = 0;
  final double _arrivalThreshold = 7.0;
  final double _instructionThreshold = 12.0;
  bool _instructionGivenForCurrentIndex = false;
  final double _offRouteThreshold = 15.0;
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
    _riskPredictor.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    // La lógica de permisos se mueve a _startLocationTracking
    await _startLocationTracking();
    if (_userLocationMarker != null) {
      await _loadMapData();
      await _setupTts();
    }
  }

  // --> AÑADIDO: Función dedicada para manejar la lógica de permisos.
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Revisa si los servicios de ubicación del dispositivo están activados.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Los servicios de ubicación están desactivados. Por favor, actívelos.',
          ),
        ),
      );
      return false;
    }

    // 2. Revisa el estado actual del permiso para la app.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Si está denegado, lo solicitamos.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Los permisos de ubicación fueron denegados.'),
          ),
        );
        return false;
      }
    }

    // 3. Maneja el caso en que el usuario deniega el permiso permanentemente.
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Los permisos de ubicación están denegados permanentemente, no podemos solicitar la ubicación.',
          ),
        ),
      );
      return false;
    }

    // Si llegamos aquí, los permisos están concedidos.
    return true;
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
    if (mounted) setState(() => loadingMessage = "Cargando datos del mapa...");

    final String response = await rootBundle.loadString(
      'assets/data/mapa_datos_app.json',
    );
    final data = json.decode(response);
    final List features = data['features'];
    _pathFinder = PathFinder(features, _riskPredictor);
    await _pathFinder!.buildGraph(features);

    List<Polyline> tempPaths = [];
    List<Polygon> tempRiskZones = [];
    List<Marker> tempMarkers = [];
    for (var feature in features) {
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      final type = geometry['type'];
      final coordinates = geometry['coordinates'];

      final int featureFloor = properties['piso'] ?? 0;

      if (featureFloor == _currentUserFloor) {
        if (type == 'LineString' && properties['tipo'] != 'escalera') {
          List<LatLng> points =
              (coordinates as List).map((c) => LatLng(c[1], c[0])).toList();
          tempPaths.add(
            Polyline(
              points: points,
              color: Colors.grey.withOpacity(0.7),
              strokeWidth: 2.0,
            ),
          );
        } else if (type == 'Point') {
          bool isSafe = properties['es_punto_seguro'] ?? false;
          if (isSafe) {
            tempMarkers.add(
              Marker(
                width: 40.0,
                height: 40.0,
                point: LatLng(coordinates[1], coordinates[0]),
                child: Icon(
                  Icons.shield,
                  color: Colors.green.shade600,
                  size: 30.0,
                ),
              ),
            );
          }
        }
      }

      if (type == 'Polygon') {
        List<LatLng> points =
            (coordinates[0] as List).map((c) => LatLng(c[1], c[0])).toList();
        tempRiskZones.add(
          Polygon(
            points: points,
            color: Colors.red.withAlpha(80),
            borderColor: Colors.red,
            borderStrokeWidth: 2,
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        initialPaths = tempPaths;
        riskZones = tempRiskZones;
        pointMarkers = tempMarkers;
      });
    }
  }

  // --> MODIFICADO: Esta función ahora llama a nuestro manejador de permisos.
  Future<void> _startLocationTracking() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      if (mounted) setState(() => isLoading = false);
      return; // Si no hay permisos, no continuamos.
    }

    if (mounted) setState(() => loadingMessage = "Obteniendo ubicación...");

    try {
      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userLatLng = LatLng(
        initialPosition.latitude,
        initialPosition.longitude,
      );

      final initialFloor = _floorService.getFloorFromAltitude(
        initialPosition.altitude,
      );

      if (mounted) {
        setState(() {
          _currentUserFloor = initialFloor;
          _userLocationMarker = Marker(
            point: userLatLng,
            width: 80,
            height: 80,
            child: Transform.rotate(
              angle: vector.radians(initialPosition.heading),
              child: const Icon(
                Icons.navigation,
                color: Colors.blueAccent,
                size: 40,
              ),
            ),
          );
          isLoading = false;
        });
      }
      _mapController.move(userLatLng, 19.0);
      _loadMapData(); // Recargamos los datos del mapa para mostrar solo el piso actual
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      print("Error al obtener ubicación inicial: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener la ubicación: $e')),
      );
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final userLatLng = LatLng(position.latitude, position.longitude);

      final newFloor = _floorService.getFloorFromAltitude(position.altitude);
      if (newFloor != _currentUserFloor) {
        if (mounted) {
          setState(() {
            _currentUserFloor = newFloor;
          });
        }
        _loadMapData();
        _speak(
          "Piso ${_currentUserFloor == 0 ? 'Bajo' : _currentUserFloor} detectado.",
        );
      }

      if (mounted) {
        setState(() {
          _userLocationMarker = Marker(
            point: userLatLng,
            width: 80,
            height: 80,
            child: Transform.rotate(
              angle: vector.radians(position.heading),
              child: const Icon(
                Icons.navigation,
                color: Colors.blueAccent,
                size: 40,
              ),
            ),
          );
        });
      }

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

  void _calculateAndShowRoute({bool isRecalculation = false}) async {
    if (_pathFinder == null || _userLocationMarker == null) {
      _speak(
        "Ubicación no disponible. Active los permisos e intente de nuevo.",
      );
      return;
    }

    if (!isNavigating) {
      if (mounted)
        setState(() {
          isNavigating = true;
        });
    }

    if (!isRecalculation) {
      _pathFinder!.resetCosts();
    }

    final startPoint = _userLocationMarker!.point;
    Node? closestSafePoint = _pathFinder!.findClosestSafePoint(startPoint);
    if (closestSafePoint == null) {
      _speak("No se encontró un punto seguro cercano.");
      if (mounted)
        setState(() {
          isNavigating = false;
        });
      return;
    }

    final path = _pathFinder!.findShortestPath(
      startPoint,
      closestSafePoint.position,
      _currentUserFloor,
    );

    if (path.isNotEmpty) {
      if (mounted) {
        setState(() {
          _calculatedRoute = Polyline(
            points: path,
            color: Colors.green,
            strokeWidth: 6.0,
          );
          _currentPathIndex = 0;
          _instructionGivenForCurrentIndex = false;
        });
      }
      if (!isRecalculation) {
        _speak("Ruta de evacuación encontrada. Siga la línea verde.");
      }
    } else {
      _speak("No se pudo calcular una nueva ruta desde esta ubicación.");
    }
  }

  // ... (El resto de tus funciones como _reportBlockage, _updateNavigation, _isUserOffRoute, _getTurnInstruction se mantienen igual)
  void _reportBlockage() {
    if (!isNavigating ||
        _userLocationMarker == null ||
        _pathFinder == null ||
        _calculatedRoute == null)
      return;
    if (_currentPathIndex >= _calculatedRoute!.points.length - 1) return;

    _speak("Ruta bloqueada reportada. Recalculando...");

    final segmentStart = _calculatedRoute!.points[_currentPathIndex];
    final segmentEnd = _calculatedRoute!.points[_currentPathIndex + 1];
    _pathFinder!.addBlockageOnSegment(segmentStart, segmentEnd);

    _calculateAndShowRoute(isRecalculation: true);
  }

  void _updateNavigation(Position currentPosition) {
    if (_calculatedRoute == null || _calculatedRoute!.points.isEmpty) return;

    final userPoint = LatLng(
      currentPosition.latitude,
      currentPosition.longitude,
    );

    if (_isUserOffRoute(userPoint)) {
      final now = DateTime.now();
      if (_lastRecalculationTime == null ||
          now.difference(_lastRecalculationTime!).inSeconds > 5) {
        _lastRecalculationTime = now;
        _speak("Recalculando ruta.");
        _calculateAndShowRoute(isRecalculation: true);
        return;
      }
    }

    final pathPoints = _calculatedRoute!.points;
    final pathNodes =
        pathPoints
            .map((p) => _pathFinder!.findNearestNode(p))
            .where((n) => n != null)
            .toList();

    if (_currentPathIndex >= pathNodes.length - 1) {
      final distanceToEnd = Geolocator.distanceBetween(
        userPoint.latitude,
        userPoint.longitude,
        pathNodes.last!.position.latitude,
        pathNodes.last!.position.longitude,
      );
      if (distanceToEnd < _arrivalThreshold) {
        _speak("Ha llegado a la zona segura.");
        if (mounted) {
          setState(() {
            isNavigating = false;
            _calculatedRoute = null;
          });
        }
        _positionStreamSubscription?.cancel();
      }
      return;
    }

    final nextWaypoint = pathNodes[_currentPathIndex + 1]!.position;
    final distanceToNextWaypoint = Geolocator.distanceBetween(
      userPoint.latitude,
      userPoint.longitude,
      nextWaypoint.latitude,
      nextWaypoint.longitude,
    );

    if (distanceToNextWaypoint < _arrivalThreshold) {
      if (mounted) {
        setState(() {
          _currentPathIndex++;
          _instructionGivenForCurrentIndex = false;
        });
      }
      return;
    }

    if (distanceToNextWaypoint < _instructionThreshold &&
        !_instructionGivenForCurrentIndex) {
      if (_currentPathIndex < pathNodes.length - 2) {
        final currentNode = pathNodes[_currentPathIndex]!;
        final nextNode = pathNodes[_currentPathIndex + 1]!;

        if (nextNode.floor != currentNode.floor) {
          final edge = _pathFinder!.adjacencyList[currentNode.id]!.firstWhere(
            (e) => e.to == nextNode.id,
            orElse: () => Edge(from: 0, to: 0, baseCost: 0, distance: 0),
          );
          if (edge.type == PathType.stairs) {
            if (nextNode.floor < currentNode.floor) {
              _speak("A continuación, baje las escaleras.");
            } else {
              _speak("A continuación, suba las escaleras.");
            }
            if (mounted)
              setState(() {
                _instructionGivenForCurrentIndex = true;
              });
            return;
          }
        }

        final upcomingWaypoint = pathNodes[_currentPathIndex + 2]!.position;
        final bearing = Geolocator.bearingBetween(
          currentNode.position.latitude,
          currentNode.position.longitude,
          nextNode.position.latitude,
          nextNode.position.longitude,
        );
        final nextBearing = Geolocator.bearingBetween(
          nextNode.position.latitude,
          nextNode.position.longitude,
          upcomingWaypoint.latitude,
          upcomingWaypoint.longitude,
        );

        final turn = _getTurnInstruction(bearing, nextBearing);
        int distance = distanceToNextWaypoint.round();
        _speak("En $distance metros, $turn");

        if (mounted)
          setState(() {
            _instructionGivenForCurrentIndex = true;
          });
      }
    }
  }

  bool _isUserOffRoute(LatLng userPoint) {
    if (_calculatedRoute == null) return false;
    double minDistance = double.infinity;
    for (final point in _calculatedRoute!.points) {
      final d = Geolocator.distanceBetween(
        userPoint.latitude,
        userPoint.longitude,
        point.latitude,
        point.longitude,
      );
      if (d < minDistance) minDistance = d;
    }
    return minDistance > _offRouteThreshold;
  }

  String _getTurnInstruction(double currentBearing, double targetBearing) {
    final angle = (targetBearing - currentBearing + 360) % 360;
    if (angle > 330 || angle < 30)
      return "continúe recto.";
    else if (angle >= 30 && angle < 150)
      return "gire a la derecha.";
    else if (angle >= 150 && angle < 210)
      return "dé la vuelta.";
    else
      return "gire a la izquierda.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isNavigating
              ? 'Piso: ${_currentUserFloor == 0 ? 'Bajo' : _currentUserFloor}'
              : 'Navegador de Evacuación',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            onPressed: _recenterMapOnUser,
            tooltip: 'Centrar en mi ubicación',
          ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(loadingMessage),
                  ],
                ),
              )
              : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      _userLocationMarker?.point ??
                      const LatLng(-0.3135, -78.4455),
                  initialZoom: 19.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  PolygonLayer(polygons: riskZones),
                  PolylineLayer(polylines: initialPaths),
                  if (_calculatedRoute != null)
                    PolylineLayer(polylines: [_calculatedRoute!]),
                  MarkerLayer(
                    markers: [
                      ...pointMarkers,
                      if (_userLocationMarker != null) _userLocationMarker!,
                    ],
                  ),
                ],
              ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isNavigating)
            FloatingActionButton(
              onPressed: _reportBlockage,
              tooltip: 'Ruta Bloqueada',
              backgroundColor: Colors.orange,
              heroTag: 'blockage_button',
              child: const Icon(Icons.block),
            ),
          if (isNavigating) const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: isNavigating ? null : _calculateAndShowRoute,
            label: Text(isNavigating ? "NAVEGANDO..." : "EVACUAR"),
            icon: const Icon(Icons.directions_run),
            backgroundColor: isNavigating ? Colors.grey : Colors.red,
            heroTag: 'evacuate_button',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
