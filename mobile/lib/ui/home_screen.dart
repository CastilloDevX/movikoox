import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  LatLng? currentPosition;
  bool loading = true;
  bool locationDenied = false;
  String? locationError;

  Map<String, dynamic>? closestStop;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // -----------------------------
  // LOCATION
  // -----------------------------

  Future<void> _initLocation() async {
    setState(() {
      loading = true;
      locationDenied = false;
      locationError = null;
    });

    try {
      if (!kIsWeb) {
        final serviceEnabled =
            await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception("Servicios de ubicación desactivados");
        }
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception("Permisos de ubicación denegados");
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentPosition = LatLng(pos.latitude, pos.longitude);
      await _fetchClosestStop();
    } catch (e) {
      locationDenied = true;
      locationError = e.toString();
    }

    setState(() => loading = false);
  }

  Future<void> _fetchClosestStop() async {
    if (currentPosition == null) return;

    final response = await ApiService.getParadaCercana(
      currentPosition!.latitude,
      currentPosition!.longitude,
    );

    if (response["ok"] == true) {
      setState(() {
        closestStop = response;
      });
    }
  }

  // -----------------------------
  // UI
  // -----------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (locationDenied) {
      return _LocationDeniedView(
        error: locationError,
        onRetry: _initLocation,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // MAPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentPosition!,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.movikoox.app",
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: currentPosition!,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // TARJETA SUPERIOR
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: _ClosestStopCard(closestStop),
          ),

          // PANEL INFERIOR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomPanel(
              onCenter: () {
                _mapController.move(currentPosition!, 16);
              },
              onRefresh: _fetchClosestStop,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------
// COMPONENTS
// ---------------------------------

class _ClosestStopCard extends StatelessWidget {
  final Map<String, dynamic>? closestStop;

  const _ClosestStopCard(this.closestStop);

  @override
  Widget build(BuildContext context) {
    return Container(
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
            width: 44,
            height: 44,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.directions_bus, size: 40),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Paradero más cercano",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Text(
                closestStop?["body"]?["stop_name"] ?? "Buscando...",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final VoidCallback onCenter;
  final VoidCallback onRefresh;

  const _BottomPanel({
    required this.onCenter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
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
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
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
              onPressed: onCenter,
              icon: const Icon(Icons.my_location),
              label: const Text("Mi ubicación"),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFC2425C),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRefresh,
            child: const Text(
              "Actualizar paradero",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------
// LOCATION DENIED VIEW
// ---------------------------------

class _LocationDeniedView extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;

  const _LocationDeniedView({
    this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                "Ubicación no disponible",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Necesitamos acceso a tu ubicación para mostrar paraderos cercanos y rutas correctas.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.location_on),
                label: const Text("Permitir ubicación"),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF922E42),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
