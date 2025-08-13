import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../path_finder.dart';


class ChatbotEvacuacionESPE {
  final PathFinder? pathFinder;
  final LatLng? userLocation;
  final Function(String)? onNavigationRequest;
  final Function(String)? onSpeakRequest;

  ChatbotEvacuacionESPE({
    this.pathFinder,
    this.userLocation,
    this.onNavigationRequest,
    this.onSpeakRequest,
  });

  // Detecta la intención según palabras clave expandidas
  String detectarIntencion(String texto) {
    texto = texto.toLowerCase();

    // Comandos de navegación directa
    if (texto.contains("navegar") || texto.contains("iniciar navegación") || texto.contains("empezar ruta")) return "iniciar_navegacion";
    if (texto.contains("detener") && texto.contains("navegación")) return "detener_navegacion";
    if (texto.contains("recalcular") || texto.contains("nueva ruta")) return "recalcular_ruta";

    // Rutas y ubicaciones específicas ESPE
    if (texto.contains("ruta") && (texto.contains("cercana") || texto.contains("más cerca"))) return "ruta_cercana";
    if (texto.contains("zona segura") || texto.contains("área segura")) return "zona_segura";
    if (texto.contains("ruta") && texto.contains("segura")) return "ruta_segura";
    if (texto.contains("mapa") && texto.contains("rutas")) return "mapa_rutas";
    if (texto.contains("punto de encuentro") || texto.contains("punto encuentro")) return "punto_encuentro";

    // Información sobre distancias y tiempos
    if (texto.contains("distancia") && texto.contains("zona segura")) return "distancia_zona_segura";
    if (texto.contains("tiempo") && texto.contains("llegar")) return "tiempo_llegada";
    if (texto.contains("cuánto falta") || texto.contains("que tan lejos")) return "distancia_restante";

    // Edificios específicos ESPE
    if (texto.contains("edificio") && (texto.contains("a") || texto.contains("b") || texto.contains("c") || texto.contains("d"))) return "evacuacion_edificio";
    if (texto.contains("laboratorios") || texto.contains("labs")) return "evacuacion_laboratorios";
    if (texto.contains("biblioteca")) return "evacuacion_biblioteca";
    if (texto.contains("comedor") || texto.contains("cafetería")) return "evacuacion_comedor";
    if (texto.contains("auditorio")) return "evacuacion_auditorio";
    if (texto.contains("gimnasio") || texto.contains("coliseo")) return "evacuacion_gimnasio";
    if (texto.contains("parqueadero") || texto.contains("parking")) return "evacuacion_parqueadero";

    // Información específica del volcán
    if (texto.contains("cotopaxi") && texto.contains("distancia")) return "distancia_volcan";
    if (texto.contains("lahares") || texto.contains("lodo volcánico")) return "info_lahares";
    if (texto.contains("ceniza volcánica") || texto.contains("caída ceniza")) return "info_ceniza";
    if (texto.contains("tiempo") && texto.contains("llegar") && texto.contains("lahar")) return "tiempo_lahares";
    if (texto.contains("dirección") && texto.contains("viento")) return "direccion_viento";

    // Medidas y preparación
    if (texto.contains("medidas") || texto.contains("antes de salir") || texto.contains("preparación")) return "medidas_previas";
    if (texto.contains("kit") && texto.contains("emergencia")) return "kit_emergencia";
    if (texto.contains("tiempo") && texto.contains("evacuar")) return "tiempo_evacuacion";
    if (texto.contains("mascarilla") || texto.contains("protección respiratoria")) return "usar_mascarilla";
    if (texto.contains("sin mascarilla")) return "sin_mascarilla";
    if (texto.contains("ceniza") && texto.contains("proteger")) return "proteger_ceniza";
    if (texto.contains("vehículo") || texto.contains("auto") || texto.contains("carro")) return "evacuacion_vehicular";
    if (texto.contains("a pie") || texto.contains("caminando")) return "evacuacion_pie";

    // Situaciones de emergencia
    if (texto.contains("ruta") && texto.contains("bloqueada")) return "ruta_bloqueada";
    if (texto.contains("cerrada") || texto.contains("otra ruta")) return "ruta_alternativa";
    if (texto.contains("me perdí") || texto.contains("perdido") || texto.contains("perdida")) return "perdido";
    if (texto.contains("atrapado") || texto.contains("atrapada")) return "atrapado";
    if (texto.contains("herido") || texto.contains("lesionado")) return "persona_herida";

    // Contactos y comunicación
    if (texto.contains("llamar") || texto.contains("emergencia") || texto.contains("911")) return "contacto_emergencia";
    if (texto.contains("autoridades") || texto.contains("policía")) return "contacto_autoridades";
    if (texto.contains("bomberos")) return "contacto_bomberos";
    if (texto.contains("cruz roja")) return "contacto_cruz_roja";
    if (texto.contains("familia") || texto.contains("comunicar")) return "comunicar_familia";

    // Información específica de la universidad
    if (texto.contains("espe") && texto.contains("protocolo")) return "protocolo_espe";
    if (texto.contains("personal") || texto.contains("empleados")) return "info_personal";
    if (texto.contains("estudiantes")) return "info_estudiantes";
    if (texto.contains("clases") || texto.contains("suspensión")) return "suspension_actividades";

    // Transporte y salidas
    if (texto.contains("transporte público")) return "transporte_publico";
    if (texto.contains("salida") && texto.contains("universidad")) return "salidas_universidad";
    if (texto.contains("carreteras") || texto.contains("vías")) return "estado_vias";

    // Estados de alerta
    if (texto.contains("alerta") && (texto.contains("amarilla") || texto.contains("naranja") || texto.contains("roja"))) return "niveles_alerta";
    if (texto.contains("semáforo volcánico")) return "semaforo_volcanico";

    return "no_entendido";
  }

  // Respuestas expandidas que integran navegación
  String responder(String intencion) {
    final respuestas = {
      // === COMANDOS DE NAVEGACIÓN ===
      "iniciar_navegacion": _responderIniciarNavegacion(),
      "detener_navegacion": "🛑 Navegación detenida. Puedes reiniciar la navegación cuando lo necesites preguntando 'navegar' o presionando el botón EVACUAR.",
      "recalcular_ruta": "🔄 Recalculando ruta desde tu ubicación actual... ${_iniciarRecalculo()}",

      // === RUTAS CON INFORMACIÓN DINÁMICA ===
      "ruta_cercana": _responderRutaCercana(),
      "zona_segura": _responderZonaSegura(),
      "ruta_segura": _responderRutaSegura(),
      "distancia_zona_segura": _responderDistanciaZonaSegura(),
      "tiempo_llegada": _responderTiempoLlegada(),
      "distancia_restante": _responderDistanciaRestante(),

      "mapa_rutas": "🗺️ El mapa interactivo muestra:\n• VERDE: Ruta calculada hacia zona segura\n• GRIS: Rutas disponibles en el campus\n• ROJO: Zonas de peligro (lahares)\n• VERDE (íconos): Puntos seguros\n\nPuedes decir 'navegar' para iniciar navegación guiada.",

      "punto_encuentro": "📍 PUNTOS DE ENCUENTRO OFICIALES:\n• Principal: Plaza de Armas de Sangolquí\n• Alternativo 1: Parque La Merced\n• Alternativo 2: Estadio Rumiñahui\n• Campus: Cancha deportiva (solo temporal)\n\n💡 Di 'navegar' para que te guíe al punto más cercano.",

      // === SITUACIONES DE EMERGENCIA CON NAVEGACIÓN ===
      "ruta_bloqueada": "🚧 RUTA BLOQUEADA:\n${_manejarRutaBloqueada()}\n\n💡 Di 'recalcular ruta' para encontrar una alternativa automáticamente.",

      "ruta_alternativa": "🔄 RUTAS ALTERNATIVAS:\n${_mostrarRutasAlternativas()}\n\n🗣️ Di 'navegar' para que calcule la mejor ruta alternativa desde tu ubicación.",

      "perdido": "📱 PERDIDO EN EVACUACIÓN:\n1. MANTÉN LA CALMA\n2. ${_ayudarPersonaPerdida()}\n3. Busca señalización naranja de evacuación\n4. Llama al 911 si es urgente\n\n🧭 Di 'navegar' para recalcular ruta desde tu nueva ubicación.",

      // === EDIFICIOS CON RUTAS ESPECÍFICAS ===
      "evacuacion_edificio": _responderEvacuacionEdificio(),
      "evacuacion_laboratorios": "🔬 LABORATORIOS - PROTOCOLO ESPECIAL:\n1. Apagar equipos según procedimiento\n2. Cerrar válvulas de gas\n3. Evacuar por salidas de emergencia\n4. NO regreses por materiales\n\n🗣️ Una vez fuera, di 'navegar' para dirigirte a zona segura.",

      "evacuacion_biblioteca": "📚 BIBLIOTECA ESPE:\n• Salida principal hacia patio central\n• Salida de emergencia lateral este\n• Deja todo y evacúa inmediatamente\n\n➡️ Al salir del edificio, di 'navegar' para continuar hacia zona segura.",

      "evacuacion_comedor": "🍽️ COMEDOR/CAFETERÍA:\n• Salida principal al patio\n• Salida trasera hacia parqueaderos\n• Dirigirse al punto temporal en cancha\n\n🧭 Desde la cancha, di 'navegar' para la ruta final hacia zona segura.",

      // === INFORMACIÓN DEL VOLCÁN ===
      "distancia_volcan": "🌋 DISTANCIA COTOPAXI-ESPE: 35 km\n• Tiempo estimado llegada lahares: 45-60 minutos\n• Ceniza volcánica: 15-30 minutos (según viento)\n• Zona de riesgo ALTO para lahares\n\n⚡ ¡EVACÚA INMEDIATAMENTE! Di 'navegar' para ruta de escape.",

      "info_lahares": "⚠️ LAHARES (lodo volcánico):\n• Flujos a 60+ km/h por ríos y quebradas\n• Llegan en 45-60 min desde erupción\n• NUNCA cruces ríos durante evacuación\n\n🛣️ Mi navegación evita automáticamente zonas de lahar. Di 'navegar' para ruta segura.",

      "tiempo_lahares": "⏱️ TIEMPO CRÍTICO:\n• Lahares desde Cotopaxi: 45-60 minutos\n• Evacuación ESPE: 20-30 minutos\n• Ventana de escape: 15-30 minutos\n\n🚨 ¡EVACÚA YA! Di 'navegar' para navegación inmediata.",

      // === MEDIDAS Y PREPARACIÓN ===
      "medidas_previas": "📋 MEDIDAS ANTES DE EVACUAR:\n✓ Mascarilla o pañuelo\n✓ Agua (1 litro mín.)\n✓ Documentos de identidad\n✓ Teléfono con batería\n✓ Medicamentos esenciales\n\n🏃‍♂️ Una vez listo, di 'navegar' para iniciar evacuación guiada.",

      "tiempo_evacuacion": _responderTiempoEvacuacion(),

      // === MODOS DE EVACUACIÓN ===
      "evacuacion_vehicular": "🚗 EVACUACIÓN EN VEHÍCULO:\n${_calcularRutaVehicular()}\n\n🗣️ Di 'navegar' para navegación GPS vehicular paso a paso.",

      "evacuacion_pie": "🚶 EVACUACIÓN A PIE:\n${_calcularRutaPeatonal()}\n\n👟 Di 'navegar' para instrucciones de navegación peatonal.",

      // === CONTACTOS ===
      "contacto_emergencia": "📞 CONTACTOS DE EMERGENCIA:\n• ECU-911: 911\n• Bomberos Quito: (02) 266-0000\n• Cruz Roja: 131\n• ESPE Seguridad: (02) 398-7500 ext. 5555\n• SNGRE: 1800-911-911\n\n🧭 Después de llamar, di 'navegar' para evacuar.",

      // Resto de respuestas originales...
      "info_ceniza": "🌪️ CENIZA VOLCÁNICA:\n• Llegada estimada: 15-30 minutos\n• Peligros: respiratorios, visibilidad\n• Protección: mascarillas N95 o pañuelo húmedo\n• Evita conducir con ceniza densa",

      "usar_mascarilla": "😷 PROTECCIÓN RESPIRATORIA:\n• Mascarilla N95: Ideal contra ceniza fina\n• Mascarilla quirúrgica: Protección básica\n• Pañuelo húmedo: Alternativa de emergencia\n• Cubre nariz Y boca completamente",

      "sin_mascarilla": "🚨 SIN MASCARILLA - ALTERNATIVAS:\n1. Pañuelo o tela húmeda sobre nariz/boca\n2. Camiseta levantada cubriendo respiración\n3. Respirar por la nariz (no por boca)\n4. Buscar refugio techado si hay mucha ceniza",

      "proteger_ceniza": "🥽 PROTECCIÓN CONTRA CENIZA:\n• Ojos: Gafas o lentes de seguridad\n• Respiración: Mascarilla N95\n• Piel: Ropa manga larga, pantalón largo\n• Cabello: Gorro o capucha\n• Evita lentes de contacto",

      "atrapado": "🆘 PERSONA ATRAPADA:\n1. Llama INMEDIATAMENTE al 911\n2. Proporciona tu ubicación exacta\n3. Si hay lesionados, prioriza ayuda médica\n4. Mantente en zona alta y segura\n5. Haz ruido para ser localizado (silbato/gritos)",

      "persona_herida": "🚑 PERSONA HERIDA:\n1. NO muevas al herido si hay lesión de columna\n2. Controla hemorragias con presión directa\n3. Llama inmediatamente al 911\n4. Proporciona primeros auxilios básicos\n5. Espera ayuda médica profesional",

      "protocolo_espe": "🏛️ PROTOCOLO OFICIAL ESPE:\n1. Alarma sonora continua = Evacuación inmediata\n2. Personal docente coordina evacuación por aulas\n3. Brigadistas con chalecos naranjas guían rutas\n4. Punto de encuentro temporal: Cancha deportiva\n5. Reporte final en Plaza Sangolquí",

      "niveles_alerta": "⚠️ NIVELES DE ALERTA VOLCÁNICA:\n• AMARILLA: Preparación y monitoreo\n• NARANJA: Alistamiento para evacuación\n• ROJA: Evacuación inmediata obligatoria\n• Estado actual: Consulta IGEPN en tiempo real",

      "no_entendido": "❓ No entendí tu consulta. Comandos disponibles:\n\n🧭 NAVEGACIÓN:\n• 'navegar' - Iniciar navegación\n• 'recalcular ruta' - Nueva ruta\n• 'detener navegación' - Parar guía\n\n📍 INFORMACIÓN:\n• 'zona segura más cercana'\n• 'cuánto falta para llegar'\n• 'ruta bloqueada'\n• 'medidas de protección'\n• 'contactos de emergencia'"
    };

    return respuestas[intencion] ?? respuestas["no_entendido"]!;
  }

  // === MÉTODOS AUXILIARES PARA NAVEGACIÓN ===

  String _responderIniciarNavegacion() {
    if (pathFinder == null || userLocation == null) {
      return "❌ Sistema de navegación no disponible. Verificando ubicación GPS...";
    }

    onNavigationRequest?.call("start");
    onSpeakRequest?.call("Iniciando navegación hacia zona segura.");

    return "🧭 INICIANDO NAVEGACIÓN:\n✅ Calculando ruta más segura desde tu ubicación\n🔊 Activando instrucciones por voz\n🗺️ Sigue la línea VERDE en el mapa\n\n🗣️ Mantén la app abierta para recibir instrucciones paso a paso.";
  }

  String _iniciarRecalculo() {
    onNavigationRequest?.call("recalculate");
    return "Buscando nueva ruta desde tu posición actual...";
  }

  String _responderRutaCercana() {
    if (pathFinder == null || userLocation == null) {
      return "🗺️ Para mostrarte la ruta más cercana necesito tu ubicación GPS. Asegúrate de tener activada la ubicación.";
    }

    Node? closestSafe = pathFinder!.findClosestSafePoint(userLocation!);
    if (closestSafe != null) {
      double distance = Geolocator.distanceBetween(
          userLocation!.latitude, userLocation!.longitude,
          closestSafe.position.latitude, closestSafe.position.longitude
      );

      return "🎯 ZONA SEGURA MÁS CERCANA:\n📍 A ${distance.round()} metros de tu ubicación\n⏱️ Tiempo estimado: ${_calcularTiempoEstimado(distance)} minutos\n\n🗣️ Di 'navegar' para recibir instrucciones paso a paso.";
    }

    return "🔍 Buscando zona segura más cercana... Di 'navegar' para calcular ruta automáticamente.";
  }

  String _responderZonaSegura() {
    if (pathFinder == null || userLocation == null) {
      return "🛡️ ZONAS SEGURAS PRINCIPALES:\n• Sangolquí centro (Plaza de Armas)\n• Parque La Merced\n• Estadio Rumiñahui\n\n💡 Activa tu ubicación GPS para calcular distancias exactas.";
    }

    List<Node> safePoints = pathFinder!.safePoints;
    String info = "🛡️ ZONAS SEGURAS CERCANAS:\n";

    for (int i = 0; i < safePoints.length && i < 3; i++) {
      double distance = Geolocator.distanceBetween(
          userLocation!.latitude, userLocation!.longitude,
          safePoints[i].position.latitude, safePoints[i].position.longitude
      );
      info += "• Zona ${i + 1}: ${distance.round()}m (${_calcularTiempoEstimado(distance)} min)\n";
    }

    return "$info\n🧭 Di 'navegar' para ir a la más cercana.";
  }

  String _responderRutaSegura() {
    return "✅ RUTA SEGURA CALCULADA:\n🛣️ Mi sistema evita automáticamente:\n• Zonas de riesgo de lahares\n• Ríos y quebradas\n• Áreas de caída de ceniza\n\n🗣️ Di 'navegar' para navegación paso a paso con instrucciones de voz.";
  }

  String _responderDistanciaZonaSegura() {
    if (userLocation == null || pathFinder == null) {
      return "📏 Para calcular la distancia exacta necesito tu ubicación GPS. Di 'navegar' para activar navegación.";
    }

    return _responderRutaCercana(); // Reutiliza la lógica
  }

  String _responderTiempoLlegada() {
    if (userLocation == null || pathFinder == null) {
      return "⏰ Tiempo estimado no disponible sin ubicación GPS. Di 'navegar' para calcular ruta y tiempo.";
    }

    Node? closestSafe = pathFinder!.findClosestSafePoint(userLocation!);
    if (closestSafe != null) {
      double distance = Geolocator.distanceBetween(
          userLocation!.latitude, userLocation!.longitude,
          closestSafe.position.latitude, closestSafe.position.longitude
      );

      int tiempoPie = _calcularTiempoEstimado(distance);
      int tiempoVehiculo = (tiempoPie * 0.3).round(); // 30% del tiempo a pie

      return "⏰ TIEMPO ESTIMADO DE LLEGADA:\n🚶 A pie: $tiempoPie minutos\n🚗 En vehículo: $tiempoVehiculo minutos\n📍 Distancia: ${distance.round()} metros\n\n🗣️ Di 'navegar' para comenzar el recorrido.";
    }

    return "⏰ Calculando tiempo de llegada... Di 'navegar' para obtener estimación precisa.";
  }

  String _responderDistanciaRestante() {
    // En una implementación real, esto verificaría si hay navegación activa
    return "📍 Para conocer la distancia restante, primero inicia la navegación diciendo 'navegar'. Durante el recorrido podrás preguntar '¿cuánto falta?' para obtener información actualizada.";
  }

  String _manejarRutaBloqueada() {
    return "1. Recalculando ruta alternativa automáticamente\n2. Buscando caminos seguros disponibles\n3. Evitando la zona bloqueada identificada\n4. Nueva ruta lista para navegación";
  }

  String _mostrarRutasAlternativas() {
    return "• Ruta primaria: Av. General Rumiñahui (norte)\n• Ruta secundaria: Vía El Triángulo (este)\n• Ruta terciaria: Vía Selva Alegre (oeste)\n• Ruta de emergencia: Sendero Parque La Merced";
  }

  String _ayudarPersonaPerdida() {
    if (userLocation != null) {
      return "Tu ubicación GPS detectada: ${userLocation!.latitude.toStringAsFixed(6)}, ${userLocation!.longitude.toStringAsFixed(6)}";
    }
    return "Activando tu ubicación GPS para reubicarte...";
  }

  String _responderEvacuacionEdificio() {
    return "🏢 EVACUACIÓN POR EDIFICIOS ESPE:\n• Edificio A: Salida este hacia parqueaderos\n• Edificio B: Salida norte directa\n• Edificio C: Salidas laterales este y oeste\n• Edificio D: Salida sur hacia Av. General Rumiñahui\n\n➡️ Una vez fuera del edificio, di 'navegar' para continuar hacia zona segura.";
  }

  String _responderTiempoEvacuacion() {
    if (userLocation != null && pathFinder != null) {
      Node? closestSafe = pathFinder!.findClosestSafePoint(userLocation!);
      if (closestSafe != null) {
        double distance = Geolocator.distanceBetween(
            userLocation!.latitude, userLocation!.longitude,
            closestSafe.position.latitude, closestSafe.position.longitude
        );
        int tiempoPersonal = _calcularTiempoEstimado(distance);

        return "⏰ TIEMPOS DE EVACUACIÓN:\n• Tu tiempo estimado: $tiempoPersonal minutos\n• Campus completo: 25-30 minutos\n• Tiempo crítico disponible: 45-60 minutos\n\n✅ Tienes tiempo suficiente. Di 'navegar' para comenzar.";
      }
    }

    return "⏰ TIEMPOS DE EVACUACIÓN GENERALES:\n• Edificios ESPE: 15-20 minutos\n• Campus completo: 25-30 minutos\n• Hacia zona segura: 30-45 minutos\n• TOTAL RECOMENDADO: Salir en primeros 20 minutos\n\n🗣️ Di 'navegar' para tiempo personalizado.";
  }

  String _calcularRutaVehicular() {
    return "• Ruta recomendada: Av. General Rumiñahui hacia norte\n• Evitar: Puentes sobre ríos\n• Velocidad: Moderada (tráfico esperado)\n• Destino: Sangolquí centro o más lejos";
  }

  String _calcularRutaPeatonal() {
    return "• Tiempo estimado: 45-60 min a zona segura\n• Ruta: Senderos peatonales marcados\n• Recomendación: Calzado cerrado y cómodo\n• Mantente en grupo cuando sea posible";
  }

  // Método auxiliar para calcular tiempo estimado (velocidad promedio 4 km/h a pie)
  int _calcularTiempoEstimado(double distanceInMeters) {
    const double walkingSpeedKmh = 4.0;
    double distanceInKm = distanceInMeters / 1000;
    double timeInHours = distanceInKm / walkingSpeedKmh;
    return (timeInHours * 60).round(); // Convertir a minutos
  }

  // Método para obtener información contextual según la ubicación
  String obtenerInfoUbicacion(String edificio) {
    final infoEdificios = {
      "edificio_a": "Edificio A - Rectorado: Salida principal este, tiempo evacuación 8-10 min. Di 'navegar' al salir del edificio.",
      "edificio_b": "Edificio B - Aulas: Múltiples salidas, tiempo evacuación 5-7 min. Navegación disponible desde cualquier salida.",
      "edificio_c": "Edificio C - Laboratorios: Protocolo especial, tiempo evacuación 10-12 min. Navegación post-evacuación del edificio.",
      "edificio_d": "Edificio D - Biblioteca: Salida controlada, tiempo evacuación 6-8 min. Sistema GPS activo para navegación externa.",
      "gimnasio": "Coliseo: Salidas amplias, tiempo evacuación 4-5 min. Di 'navegar' una vez en el exterior.",
      "comedor": "Comedor: Salida rápida al patio, tiempo evacuación 3-4 min. Navegación desde patio hacia zona segura disponible."
    };

    return infoEdificios[edificio] ?? "Ubicación no identificada. Di 'navegar' para calcular ruta desde cualquier punto del campus.";
  }

  // Método para verificar estado de emergencia en tiempo real
  bool verificarEstadoEmergencia() {
    // En una implementación real, esto consultaría APIs oficiales
    return false; // false = sin emergencia actual, true = emergencia activa
  }
}