import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';
import '../services/geocode_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static double lastKnownLat = 0;
  static double lastKnownLon = 0;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GeocodeService _geocodeService = GeocodeService();

  String? userStreetName;
  LatLng? _lastGeocodedPosition;

  bool loading = true;

  LatLng? currentPosition;
  LatLng? closestStopPosition;

  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;

  Map<String, dynamic>? closestStop;
  String? closestStopDistanceMeters;

  @override
  void initState() {
    super.initState();
    initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // -----------------------------
  // INIT FLOW
  // -----------------------------
  Future<void> initLocation() async {
    if (kIsWeb) {
      await _initWebLocation();
    } else {
      await _initMobileLocation();
      _startRealtimeLocation(); // realtime
    }

    if (currentPosition != null) {
      HomeScreen.lastKnownLat = currentPosition!.latitude;
      HomeScreen.lastKnownLon = currentPosition!.longitude;

      await fetchClosestStop();
    }

    setState(() => loading = false);
  }

  // -----------------------------
  // LOCATION
  // -----------------------------
  Future<void> _initWebLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      currentPosition = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      currentPosition = const LatLng(19.845, -90.525);
    }
  }

  Future<void> _initMobileLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      currentPosition = const LatLng(19.845, -90.525);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      currentPosition = const LatLng(19.845, -90.525);
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    currentPosition = LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _updateUserStreetIfNeeded(LatLng newPosition) async {
    if (_lastGeocodedPosition != null) {
      final distance = const Distance().as(
        LengthUnit.Meter,
        _lastGeocodedPosition!,
        newPosition,
      );

      if (distance < 30) return;
    }

    _lastGeocodedPosition = newPosition;

    final address = await _geocodeService.getAddressFromCoordinates(
      newPosition.latitude,
      newPosition.longitude,
    );

    if (address != null && mounted) {
      setState(() {
        userStreetName = address;
      });
    }
  }

  void _startRealtimeLocation() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 3,
          ),
        ).listen((Position pos) {
          final newPosition = LatLng(pos.latitude, pos.longitude);

          setState(() {
            currentPosition = newPosition;
          });

          _updateUserStreetIfNeeded(newPosition);
          fetchClosestStop();
        });
  }

  // -----------------------------
  // API
  // -----------------------------
  Future<void> fetchClosestStop() async {
    if (currentPosition == null) return;

    final result = await ApiService.getParadaCercana(
      currentPosition!.latitude,
      currentPosition!.longitude,
    );

    if (result != null && result["ok"] == true) {
      setState(() {
        closestStop = result;
        int meters = ((result["distance_km"] ?? 0.0) * 1000).floor();
        closestStopDistanceMeters = "En ${meters.toString()} metros";

        closestStopPosition = LatLng(
          result["body"]["latitud"],
          result["body"]["longitud"],
        );
      });
    }
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    if (loading || currentPosition == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentPosition!,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.koox.app",
              ),

              // -----------------------------
              // MARKERS
              // -----------------------------
              MarkerLayer(
                markers: [
                  // USER REALTIME LOCATION
                  Marker(
                    point: currentPosition!,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.blue, width: 4),
                      ),
                    ),
                  ),

                  // CLOSEST STOP
                  if (closestStopPosition != null)
                    Marker(
                      point: closestStopPosition!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF922E42),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            "assets/icons/bus_stop.png",
                            width: 18,
                            height: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // -----------------------------
          // CLOSEST STOP CARD
          // -----------------------------
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(blurRadius: 8, color: Colors.black26),
                ],
              ),
              child: Row(
                children: [
                  Image.asset(
                    "assets/icons/kooxbus_icon.png",
                    width: 50,
                    height: 50,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Paradero más cercano",
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                        Text(
                          closestStop?["body"]?["nombre"] ?? "Buscando...",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          closestStopDistanceMeters ?? "Cargando ...",
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // -----------------------------
          // BOTTOM PANEL
          // -----------------------------
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
              decoration: const BoxDecoration(
                color: Color(0xFF922E42),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "¿A dónde quieres ir?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (userStreetName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            userStreetName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, "/search");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7A7A7A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text("Buscar destino"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _mapController.move(currentPosition!, 16);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC2425C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.my_location),
                      label: const Text("Ubicación Actual"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
