import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geocode_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();

  final _geocodeService = GeocodeService();
  Timer? _debounce;

  // Overlay
  OverlayEntry? _overlayEntry;
  final LayerLink _startLink = LayerLink();
  final LayerLink _endLink = LayerLink();

  bool _isLoading = false;

  // Coordenadas válidas
  double? _startLat;
  double? _startLon;
  double? _endLat;
  double? _endLon;

  // Recientes
  final List<String> _recentSearches = [];

  bool get isFormValid =>
      _startLat != null &&
      _startLon != null &&
      _endLat != null &&
      _endLon != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  // -----------------------------
  // AUTOCOMPLETE
  // -----------------------------
  void _onSearchChanged(String value, bool isStart) {
    _debounce?.cancel();

    // Texto manual invalida coordenadas
    setState(() {
      if (isStart) {
        _startLat = null;
        _startLon = null;
      } else {
        _endLat = null;
        _endLon = null;
      }
    });

    if (value.trim().isEmpty) {
      _removeOverlay();
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _geocodeService.searchPlaces(value);

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (results.isEmpty) {
        _removeOverlay();
        return;
      }

      _showOverlay(
        context: context,
        link: isStart ? _startLink : _endLink,
        controller: isStart ? _startController : _endController,
        suggestions: results,
        isStart: isStart,
      );
    });
  }

  // -----------------------------
  // CURRENT LOCATION
  // -----------------------------
  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        _showLocationDialog(
          title: "GPS desactivado",
          message: "Activa el GPS para usar tu ubicación actual",
          actionText: "Activar GPS",
          onAction: () async {
            await Geolocator.openLocationSettings();
          },
        );
        return;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          
          _showLocationDialog(
            title: "Permiso denegado",
            message: "Necesitamos acceso a tu ubicación para usar esta función",
            actionText: "Dar permiso",
            onAction: () async {
              permission = await Geolocator.requestPermission();
              if (permission == LocationPermission.whileInUse || 
                  permission == LocationPermission.always) {
                _useCurrentLocation(); // Reintentar
              }
            },
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        _showLocationDialog(
          title: "Permiso denegado",
          message: "Activa el permiso de ubicación en la configuración de la app",
          actionText: "Abrir configuración",
          onAction: () async {
            await Geolocator.openAppSettings();
          },
        );
        return;
      }

      // OBTENER LA UBICACIÓN ACTUAL EN TIEMPO REAL
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lon = position.longitude;

      // Obtener la dirección
      final address = await _geocodeService.getAddressFromCoordinates(lat, lon);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (address != null) {
          _startController.text = address.split(',').take(2).join(',').trim();
          _startLat = lat;
          _startLon = lon;
        } else {
          // Si falla la geocodificación, usar coordenadas pero sin dirección
          _startController.text = "Mi ubicación actual";
          _startLat = lat;
          _startLon = lon;
        }
      });

      _removeOverlay();
      FocusScope.of(context).unfocus();

      // Mostrar confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ubicación obtenida correctamente"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al obtener ubicación: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showLocationDialog({
    required String title,
    required String message,
    required String actionText,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.location_off,
              color: Color(0xFF922E42),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF922E42),
              foregroundColor: Colors.white,
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // OVERLAY
  // -----------------------------
  void _showOverlay({
    required BuildContext context,
    required LayerLink link,
    required TextEditingController controller,
    required List<dynamic> suggestions,
    required bool isStart,
  }) {
    _removeOverlay();

    final width = MediaQuery.of(context).size.width;

    _overlayEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.transparent)),
            CompositedTransformFollower(
              link: link,
              offset: const Offset(0, 60),
              child: SizedBox(
                width: width - 40,
                child: Material(
                  borderRadius: BorderRadius.circular(12),
                  elevation: 6,
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: suggestions.map((item) {
                      return ListTile(
                        leading: Icon(
                          isStart ? Icons.trip_origin : Icons.flag,
                          color: const Color(0xFF922E42),
                        ),
                        title: Text(
                          item["display_name"],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          controller.text = item["display_name"]
                              .split(',')
                              .first
                              .trim();

                          setState(() {
                            if (isStart) {
                              _startLat = double.parse(item["lat"]);
                              _startLon = double.parse(item["lon"]);
                            } else {
                              _endLat = double.parse(item["lat"]);
                              _endLon = double.parse(item["lon"]);
                            }
                          });

                          _removeOverlay();
                          FocusScope.of(context).unfocus();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buscar Ruta"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF922E42),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInput(
              hint: "Ubicación de partida",
              controller: _startController,
              link: _startLink,
              isStart: true,
              onUseCurrentLocation: _useCurrentLocation,
            ),
            const SizedBox(height: 20),
            _buildInput(
              hint: "Destino",
              controller: _endController,
              link: _endLink,
              isStart: false,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isFormValid
                    ? () {
                        Navigator.pushNamed(
                          context,
                          "/instructions",
                          arguments: {
                            "startLat": _startLat,
                            "startLon": _startLon,
                            "endLat": _endLat,
                            "endLon": _endLon,
                            "destName": _endController.text,
                          },
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFormValid
                      ? const Color(0xFF922E42)
                      : Colors.grey.shade400,
                  foregroundColor: isFormValid ? Colors.white : Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Buscar ruta",
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------
  // INPUT
  // -----------------------------
  Widget _buildInput({
    required String hint,
    required TextEditingController controller,
    required LayerLink link,
    required bool isStart,
    VoidCallback? onUseCurrentLocation,
  }) {
    return CompositedTransformTarget(
      link: link,
      child: TextField(
        controller: controller,
        onChanged: (v) => _onSearchChanged(v, isStart),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(
            isStart ? Icons.trip_origin : Icons.flag,
            color: const Color(0xFF922E42),
          ),
          suffixIcon: onUseCurrentLocation != null
              ? IconButton(
                  icon: const Icon(Icons.my_location),
                  color: const Color(0xFF922E42),
                  onPressed: onUseCurrentLocation,
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}