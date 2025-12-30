import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../models/instruction_model.dart';
import '../models/summary_model.dart';

class InstructionsScreen extends StatefulWidget {
  const InstructionsScreen({super.key});

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> with TickerProviderStateMixin {
  
  // =========================================================
  //  CONFIGURACIÓN DE UI Y MAPA
  // =========================================================
  
  final int _animDurationMs = 1200; 
  final double _maxZoomLevel = 16.5; 
  final double _minZoomLevel = 5.0;
  final double _verticalShiftFactor = 0.30; // Mueve el mapa hacia arriba

  // =========================================================

  final MapController _mapController = MapController();

  List<Instruction> _steps = [];
  Summary? _summary;

  bool _loading = true;
  int _currentStepIndex = 0;

  late double _inicioLat;
  late double _inicioLon;
  late double _destinoLat;
  late double _destinoLon;
  late String _destName;

  LatLng? _stepFrom;
  LatLng? _stepTo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    _inicioLat = args["startLat"];
    _inicioLon = args["startLon"];
    _destinoLat = args["endLat"];
    _destinoLon = args["endLon"];
    _destName = args["destName"];

    _loadInstructions();
  }

  // -----------------------------
  // LOAD
  // -----------------------------
  Future<void> _loadInstructions() async {
    try {
      final res = await ApiService.getInstrucciones(
        inicioLat: _inicioLat,
        inicioLon: _inicioLon,
        destinoLat: _destinoLat,
        destinoLon: _destinoLon,
      );

      _steps = res["instructions"] as List<Instruction>;
      _summary = res["summary"] as Summary;

      _updateStepFocus();
    } catch (e) {
      debugPrint("Error loading instructions: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  // -----------------------------
  // STEP FOCUS
  // -----------------------------
  void _updateStepFocus() {
    if (_steps.isEmpty) return;

    final step = _steps[_currentStepIndex];
    final isLastStep = _currentStepIndex == _steps.length - 1;

    // Lógica original de asignación de coordenadas
    if (step.type == "walk") {
      if (step.from != null && step.to != null) {
        _stepFrom = LatLng(
          (step.from!["lat"] as num).toDouble(),
          (step.from!["lon"] as num).toDouble(),
        );
        _stepTo = LatLng(
          (step.to!["lat"] as num).toDouble(),
          (step.to!["lon"] as num).toDouble(),
        );
      } else {
        // Fallback
        if (_currentStepIndex == 0) {
          _stepFrom = LatLng(_inicioLat, _inicioLon);
          if (_currentStepIndex + 1 < _steps.length && _steps[_currentStepIndex + 1].type == "bus") {
            final nextStep = _steps[_currentStepIndex + 1];
            _stepTo = LatLng(
              (nextStep.fromStop!["latitud"] as num).toDouble(),
              (nextStep.fromStop!["longitud"] as num).toDouble(),
            );
          } else {
            _stepTo = LatLng(_destinoLat, _destinoLon);
          }
        } else if (isLastStep) {
          if (_currentStepIndex > 0 && _steps[_currentStepIndex - 1].type == "bus") {
            final prevStep = _steps[_currentStepIndex - 1];
            _stepFrom = LatLng(
              (prevStep.toStop!["latitud"] as num).toDouble(),
              (prevStep.toStop!["longitud"] as num).toDouble(),
            );
          } else {
            _stepFrom = LatLng(_inicioLat, _inicioLon);
          }
          _stepTo = LatLng(_destinoLat, _destinoLon);
        } else {
          _stepFrom = LatLng(_inicioLat, _inicioLon);
          _stepTo = LatLng(_destinoLat, _destinoLon);
        }
      }
    } else {
      // Bus
      if (step.fromStop != null && step.toStop != null) {
        _stepFrom = LatLng(
          (step.fromStop!["latitud"] as num).toDouble(),
          (step.fromStop!["longitud"] as num).toDouble(),
        );
        _stepTo = LatLng(
          (step.toStop!["latitud"] as num).toDouble(),
          (step.toStop!["longitud"] as num).toDouble(),
        );
      }
    }

    if (_stepFrom != null && _stepTo != null) {
      final bounds = LatLngBounds(_stepFrom!, _stepTo!);
      
      double targetZoom = _getZoomForBounds(bounds);
      
      targetZoom = targetZoom.clamp(_minZoomLevel, _maxZoomLevel);
      LatLng targetCenter = bounds.center;
      double latDiff = (bounds.northEast.latitude - bounds.southWest.latitude).abs();
      if (latDiff == 0) latDiff = 0.005;
      double newLat = targetCenter.latitude - (latDiff * _verticalShiftFactor);
      _animatedMapMove(LatLng(newLat, targetCenter.longitude), targetZoom);
    }

    setState(() {});
  }

  // -----------------------------
  // FUNCIONES DE ANIMACIÓN Y ZOOM (NUEVAS)
  // -----------------------------

  /// Calcula un zoom aproximado basado en la distancia de los puntos
  double _getZoomForBounds(LatLngBounds bounds) {
    final double distance = const Distance().as(LengthUnit.Kilometer, bounds.northEast, bounds.southWest);
    
    double zoomLevel = 15.0;
    if (distance < 0.1) zoomLevel = 18;       // < 100m
    else if (distance < 0.5) zoomLevel = 16.5; // < 500m
    else if (distance < 1) zoomLevel = 15.5;  // < 1km
    else if (distance < 3) zoomLevel = 14;    // < 3km
    else if (distance < 8) zoomLevel = 13;    // < 8km
    else if (distance < 15) zoomLevel = 11;   // < 15km
    else zoomLevel = 9;                       // > 15km

    return zoomLevel;
  }

  /// Mueve la cámara suavemente usando interpolación
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Protección simple por si el mapa no está listo
    if (!_mapController.mapEventStream.isBroadcast) return;

    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: Duration(milliseconds: _animDurationMs),
      vsync: this,
    );

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn, // Curva suave: rápido al inicio, frena al final
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }


  // -----------------------------
  // UI - RESTO DEL CÓDIGO (IGUAL)
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_inicioLat, _inicioLon),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.koox.app",
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          Positioned(top: 50, left: 20, right: 20, child: _buildHeader()),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomSheet()),
        ],
      ),
    );
  }

  // -----------------------------
  // MARKERS
  // -----------------------------
  List<Marker> _buildMarkers() {
    if (_stepFrom == null || _stepTo == null) return [];

    final step = _steps[_currentStepIndex];
    final isFirstStep = _currentStepIndex == 0;
    final isLastStep = _currentStepIndex == _steps.length - 1;

    // Determinar tipo de marcador para FROM
    bool fromIsBusStop = false;
    bool fromIsStart = false;
    
    if (isFirstStep && step.type == "walk") {
      fromIsStart = true;
    } else if (step.type == "bus") {
      fromIsBusStop = true; 
    } else if (step.type == "walk" && _currentStepIndex > 0) {
      final prevStep = _steps[_currentStepIndex - 1];
      if (prevStep.type == "bus") {
        fromIsBusStop = true;
      }
    }

    // Determinar tipo de marcador para TO
    bool toIsBusStop = false;
    bool toIsDestination = false;
    
    if (isLastStep && step.type == "walk") {
      toIsDestination = true;
    } else if (step.type == "bus") {
      toIsBusStop = true;
    } else if (step.type == "walk" && _currentStepIndex + 1 < _steps.length) {
      final nextStep = _steps[_currentStepIndex + 1];
      if (nextStep.type == "bus") {
        toIsBusStop = true;
      }
    }

    return [
      // Marcador FROM
      Marker(
        point: _stepFrom!,
        width: 60,
        height: 80,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Text(
                "1",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (fromIsStart)
              _markerCircle(Icons.my_location, Colors.blue)
            else if (fromIsBusStop)
              _busStopMarker(Colors.blue)
            else
              _markerCircle(Icons.location_on, Colors.blue),
          ],
        ),
      ),
      
      // Marcador TO
      Marker(
        point: _stepTo!,
        width: 60,
        height: 80,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF922E42),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Text(
                "2",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (toIsDestination)
              _markerCircle(Icons.location_on, const Color(0xFF922E42))
            else if (toIsBusStop)
              _busStopMarker(const Color(0xFF922E42))
            else
              _markerCircle(Icons.location_on, const Color(0xFF922E42)),
          ],
        ),
      ),
    ];
  }

  Widget _markerCircle(IconData icon, Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icon, color: Colors.white, size: 15),
    );
  }

  Widget _busStopMarker(Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
      ),
      padding: const EdgeInsets.all(5.0),
      child: ClipOval(
        child: Image.asset(
          'assets/icons/bus_stop.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // -----------------------------
  // HEADER
  // -----------------------------
  Widget _buildHeader() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Destino", style: TextStyle(color: Colors.grey)),
            Text(
              _destName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_summary != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem(
                    "Tiempo",
                    "${_summary!.totalMinutes.round()} min",
                  ),
                  _summaryItem("Camiones", _summary!.numBuses.toString()),
                  _summaryItem(
                    "Distancia",
                    "${((_summary!.walkKm + _summary!.busKm) * 1000).round()} m",
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF922E42),
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  // -----------------------------
  // BOTTOM SHEET
  // -----------------------------
  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF922E42),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Paso ${_currentStepIndex + 1} de ${_steps.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStepCard(_steps[_currentStepIndex]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _currentStepIndex == 0 ? null : _prevStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF922E42),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade400,
                              disabledForegroundColor: Colors.white70,
                            ),
                            child: const Text("Atrás"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _currentStepIndex == _steps.length - 1
                                    ? null
                                    : _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF922E42),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade400,
                              disabledForegroundColor: Colors.white70,
                            ),
                            child: const Text("Siguiente"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // -----------------------------
  // STEP CARD
  // -----------------------------
  Widget _buildStepCard(Instruction step) {
    final isWalk = step.type == "walk";

    String fromName;
    String toName;
    
    if (isWalk) {
      if (_currentStepIndex == 0) {
        fromName = "Tu ubicación";
      } else {
        if (_currentStepIndex > 0) {
          final prevStep = _steps[_currentStepIndex - 1];
          if (prevStep.type == "bus" && prevStep.toStop != null) {
            fromName = prevStep.toStop!["nombre"] ?? "Punto anterior";
          } else {
            fromName = "Punto anterior";
          }
        } else {
          fromName = "Punto anterior";
        }
      }

      if (_currentStepIndex == _steps.length - 1) {
        toName = _destName;
      } else {
        if (_currentStepIndex + 1 < _steps.length) {
          final nextStep = _steps[_currentStepIndex + 1];
          if (nextStep.type == "bus" && nextStep.fromStop != null) {
            toName = nextStep.fromStop!["nombre"] ?? "Siguiente punto";
          } else {
            toName = "Siguiente punto";
          }
        } else {
          toName = "Siguiente punto";
        }
      }
    } else {
      fromName = step.fromStop?["nombre"] ?? "Parada de origen";
      toName = step.toStop?["nombre"] ?? "Parada de destino";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isWalk ? "Camina" : "Toma el bus",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (!isWalk && step.bus != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                step.bus!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF922E42),
                  fontSize: 16,
                ),
              ),
            ),
          const SizedBox(height: 14),
          
          const Text(
            "Desde:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            fromName,
            style: const TextStyle(fontSize: 15),
          ),
          
          const SizedBox(height: 12),
          
          const Text(
            "Hasta:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            toName,
            style: const TextStyle(fontSize: 15),
          ),
          
          const SizedBox(height: 14),
          Text(
            "⏱️ ${step.minutes.round()} min · 📍 ${(step.distanceKm * 1000).round()} m",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() => _currentStepIndex++);
      _updateStepFocus();
    }
  }

  void _prevStep() {
    if (_currentStepIndex > 0) {
      setState(() => _currentStepIndex--);
      _updateStepFocus();
    }
  }
}