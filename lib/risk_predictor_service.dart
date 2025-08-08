import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class RiskPredictorService {
  Interpreter? _interpreter;

  RiskPredictorService() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      // Carga el modelo usando el intérprete, que es la forma correcta para tflite_flutter
      _interpreter = await Interpreter.fromAsset('assets/ml/risk_model.tflite');
      print('✅ Modelo TFLite cargado correctamente.');
    } catch (e) {
      print('❌ Error al cargar el modelo TFLite: $e');
    }
  }

  // El método ahora no es async, ya que la predicción con el intérprete es síncrona.
  double predictRisk(double distancia, bool esEscalera, bool pasilloEstrecho, int densidadPersonas) {
    if (_interpreter == null) {
      print("⚠️ Modelo no cargado. Usando riesgo por defecto.");
      return 1.0; // Devuelve un riesgo neutral si el modelo no está listo
    }

    // El modelo que creamos espera un array de números de punto flotante (Float32).
    // Creamos el array de entrada con el formato correcto: [1, 4]
    var input = Float32List(4)
      ..[0] = distancia
      ..[1] = esEscalera ? 1.0 : 0.0
      ..[2] = pasilloEstrecho ? 1.0 : 0.0
      ..[3] = densidadPersonas.toDouble();

    var reshapedInput = input.reshape([1, 4]);

    // La salida será un array con un solo número.
    var output = List.filled(1, 0.0).reshape([1, 1]);

    // Ejecuta la inferencia
    _interpreter!.run(reshapedInput, output);

    // El resultado es el primer (y único) valor en el array de salida
    double predictedRisk = output[0][0];

    // Normalizamos el riesgo para que sea un multiplicador razonable (ej. entre 1 y 10)
    return (predictedRisk / 10).clamp(1.0, 10.0);
  }

  void close() {
    _interpreter?.close();
  }
}
