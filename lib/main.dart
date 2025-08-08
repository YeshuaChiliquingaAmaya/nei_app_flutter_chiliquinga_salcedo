import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';

// Asegúrate de que este archivo exista en tu carpeta 'lib'
import 'path_finder.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
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

  // --- Estado de la UI ---
  bool isLoading = true;
  String loadingMessage = "Cargando datos del mapa...";

  // --- Elementos del Mapa ---
  List<Polyline> initialPaths = [];
  List<Polygon> riskZones = [];
  List<Marker> pointMarkers = [];
  Marker? _userLocationMarker;
  Polyline? _calculatedRoute;

  @override
  void initState() {
    super.initState();
    // Inicia la carga de datos y luego busca la ubicación del usuario.
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadMapData();
    await _setupTts();
    await _getCurrentLocation();
  }

  Future<void> _setupTts() async {
    await _flutterTts.setLanguage("es-EC");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  /// Carga y procesa el archivo JSON para construir el grafo y los elementos visuales del mapa.
  Future<void> _loadMapData() async {
    try {
      final String response = await rootBundle.loadString('assets/data/mapa_datos_app.json');
      final data = json.decode(response);
      final List features = data['features'];

      // Construye el "cerebro" que calculará las rutas.
      _pathFinder = PathFinder(features);
      print('PathFinder inicializado: ${_pathFinder?.allNodes.length} nodos, ${_pathFinder?.safePoints.length} puntos seguros.');

      List<Polyline> tempPaths = [];
      List<Polygon> tempRiskZones = [];
      List<Marker> tempMarkers = [];

      for (var feature in features) {
        final geometry = feature['geometry'];
        final type = geometry['type'];
        final coordinates = geometry['coordinates'];

        if (type == 'LineString') {
          List<LatLng> points = (coordinates as List).map((c) => LatLng(c[1], c[0])).toList();
          tempPaths.add(Polyline(points: points, color: Colors.grey.withOpacity(0.8), strokeWidth: 2.0));
        } else if (type == 'Point') {
          final properties = feature['properties'];
          bool isSafe = properties['es_punto_seguro'] ?? false;
          if (isSafe) {
            tempMarkers.add(
              Marker(
                width: 40.0,
                height: 40.0,
                point: LatLng(coordinates[1], coordinates[0]),
                child: const Icon(Icons.shield, color: Colors.green, size: 30.0),
              ),
            );
          }
        } else if (type == 'Polygon') {
          List<LatLng> points = (coordinates[0] as List).map((c) => LatLng(c[1], c[0])).toList();
          tempRiskZones.add(
            Polygon(
              points: points,
              color: Colors.red.withOpacity(0.3),
              borderColor: Colors.red.withOpacity(0.7),
              borderStrokeWidth: 2,
            ),
          );
        }
      }

      setState(() {
        initialPaths = tempPaths;
        riskZones = tempRiskZones;
        pointMarkers = tempMarkers;
      });
    } catch (e) {
      print("Error cargando los datos del mapa: $e");
      setState(() {
        loadingMessage = "Error al cargar datos.";
      });
    }
  }

  /// Obtiene la ubicación actual del GPS, maneja los permisos y actualiza el mapa.
  Future<void> _getCurrentLocation() async {
    setState(() {
      loadingMessage = "Obteniendo ubicación...";
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _speak("Por favor, active el GPS para continuar.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _speak("El permiso de ubicación es necesario para calcular la ruta.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _speak("El permiso de ubicación fue denegado permanentemente.");
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _userLocationMarker = Marker(
          point: userLatLng,
          width: 80,
          height: 80,
          child: const Icon(Icons.my_location, color: Colors.blueAccent, size: 35),
        );
        isLoading = false;
      });

      _mapController.move(userLatLng, 18.0);
      _speak("Ubicación encontrada. Presione el botón de evacuación para encontrar la ruta más segura.");
    } catch (e) {
      print("Error obteniendo la ubicación: $e");
      setState(() {
        loadingMessage = "No se pudo obtener la ubicación.";
      });
    }
  }

  /// Calcula y muestra la ruta de evacuación más óptima.
  void _calculateAndShowRoute() async {
    if (_pathFinder == null || _userLocationMarker == null) {
      _speak("Espere, los datos de ubicación o del mapa aún no están listos.");
      return;
    }

    final startPoint = _userLocationMarker!.point;

    // Encuentra el punto seguro más cercano al usuario.
    Node? closestSafePoint = _pathFinder!.findClosestSafePoint(startPoint);

    if (closestSafePoint == null) {
      _speak("Error: No se encontraron puntos de encuentro seguros en el mapa.");
      return;
    }

    _speak("Calculando la ruta de evacuación más segura. Por favor espere.");

    // Usa el PathFinder (con A*) para obtener la lista de coordenadas de la ruta.
    final path = _pathFinder!.findShortestPath(startPoint, closestSafePoint.position);

    if (path.isNotEmpty) {
      setState(() {
        _calculatedRoute = Polyline(
          points: path,
          color: Colors.green,
          strokeWidth: 6.0,
          isDotted: false,
        );
      });

      final distance = Distance();
      final totalDistance = distance.as(LengthUnit.Meter, startPoint, closestSafePoint.position).round();
      _speak("Ruta encontrada. El punto seguro está a $totalDistance metros. Siga la línea verde.");

    } else {
      _speak("No se pudo calcular una ruta de evacuación desde su ubicación actual.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navegador de Evacuación Inteligente'),
        actions: [
          // Botón para recentrar el mapa en la ubicación del usuario
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            onPressed: _getCurrentLocation,
          )
        ],
      ),
      body: isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 20), Text(loadingMessage)]))
          : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(-0.314, -78.444), // Centro inicial de la ESPE
          initialZoom: 17.0,
        ),
        children: [
          // Capa de mapa (puedes cambiarla por tiles offline más adelante)
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),

          // Capas de datos del JSON
          PolygonLayer(polygons: riskZones),
          PolylineLayer(polylines: initialPaths),

          // Capa para la ruta calculada (solo se muestra si no es nula)
          if (_calculatedRoute != null)
            PolylineLayer(polylines: [_calculatedRoute!]),

          // Capa de marcadores (puntos seguros y ubicación del usuario)
          MarkerLayer(markers: [
            ...pointMarkers,
            if (_userLocationMarker != null) _userLocationMarker!,
          ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _calculateAndShowRoute,
        label: const Text("Evacuar"),
        icon: const Icon(Icons.directions_run),
        backgroundColor: Colors.red,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
