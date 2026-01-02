import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models/parada_model.dart';
import '../models/ruta_model.dart';

class BusesMapScreen extends StatefulWidget {
  const BusesMapScreen({super.key});

  @override
  State<BusesMapScreen> createState() => _BusesMapScreenState();
}

class _BusesMapScreenState extends State<BusesMapScreen>
    with TickerProviderStateMixin {
  LatLng? userPosition;
  StreamSubscription<Position>? _positionStream;

  final MapController _mapController = MapController();

  int? selectedIndex;

  @override
  void initState() {
    super.initState();
    _startRealtimeLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // --------------------------------------------------
  // UBICACIÓN USUARIO EN TIEMPO REAL
  // --------------------------------------------------
  Future<void> _startRealtimeLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      setState(() {
        userPosition = LatLng(pos.latitude, pos.longitude);
      });
    });
  }

  // --------------------------------------------------
  // ANIMACIÓN MAPA
  // --------------------------------------------------
  void _animateMapTo(LatLng target, double zoom) {
    final latTween = Tween<double>(
      begin: _mapController.center.latitude,
      end: target.latitude,
    );

    final lngTween = Tween<double>(
      begin: _mapController.center.longitude,
      end: target.longitude,
    );

    final zoomTween = Tween<double>(
      begin: _mapController.zoom,
      end: zoom,
    );

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final animation =
        CurvedAnimation(parent: controller, curve: Curves.easeInOut);

    controller.addListener(() {
      _mapController.move(
        LatLng(
          latTween.evaluate(animation),
          lngTween.evaluate(animation),
        ),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) controller.dispose();
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final Ruta ruta =
        ModalRoute.of(context)!.settings.arguments as Ruta;

    final List<Parada> paradas = ruta.paradas;

    if (paradas.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Sin paradas")),
        body: const Center(child: Text("Esta ruta no tiene paradas")),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // --------------------------------------------------
          // MAPA
          // --------------------------------------------------
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                paradas.first.latitud,
                paradas.first.longitud,
              ),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.movikoox.app',
              ),

              // --------------------------------------------------
              // MARCADORES (ORDENADOS POR PRIORIDAD)
              // --------------------------------------------------
              MarkerLayer(
                markers: [
                  // ------------------
                  // USUARIO
                  // ------------------
                  if (userPosition != null)
                    Marker(
                      point: userPosition!,
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.blue,
                            width: 4,
                          ),
                        ),
                      ),
                    ),

                  // ------------------
                  // PARADAS NORMALES
                  // ------------------
                  ...List.generate(paradas.length, (i) {
                    if (selectedIndex == i) return null;

                    final parada = paradas[i];
                    return Marker(
                      point:
                          LatLng(parada.latitud, parada.longitud),
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => selectedIndex = i);
                          _animateMapTo(
                            LatLng(
                              parada.latitud,
                              parada.longitud,
                            ),
                            16,
                          );
                        },
                        child: _buildParadaIcon(selected: false),
                      ),
                    );
                  }).whereType<Marker>(),

                  // ------------------
                  // PARADA SELECCIONADA (AL FINAL)
                  // ------------------
                  if (selectedIndex != null)
                    Marker(
                      point: LatLng(
                        paradas[selectedIndex!].latitud,
                        paradas[selectedIndex!].longitud,
                      ),
                      width: 40,
                      height: 40,
                      child: _buildParadaIcon(selected: true),
                    ),
                ],
              ),
            ],
          ),

          // --------------------------------------------------
          // HEADER
          // --------------------------------------------------
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF922E42),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black26,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Image.asset(
                    "assets/icons/kooxbus_icon.png",
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Mapa de\n${ruta.nombre}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // --------------------------------------------------
          // LISTA DE PARADAS
          // --------------------------------------------------
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.35,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: paradas.length,
                itemBuilder: (_, i) {
                  final parada = paradas[i];
                  final selected = selectedIndex == i;

                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedIndex = i);
                      _animateMapTo(
                        LatLng(
                          parada.latitud,
                          parada.longitud,
                        ),
                        16,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF922E42).withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                const Color(0xFF922E42),
                            child: Text(
                              '${i + 1}',
                              style:
                                  const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              parada.nombre,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // ICONO DE PARADA
  // --------------------------------------------------
  Widget _buildParadaIcon({required bool selected}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? Colors.blue : const Color(0xFF922E42),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: selected ? 4 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: selected ? Colors.black38 : Colors.black26,
            blurRadius: selected ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          "assets/icons/bus_stop.png",
          width: selected ? 20 : 18,
          height: selected ? 20 : 18,
          color: Colors.white,
        ),
      ),
    );
  }
}
