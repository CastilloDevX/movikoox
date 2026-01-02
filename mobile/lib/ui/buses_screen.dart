import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/ruta_model.dart';

class BusesScreen extends StatefulWidget {
  const BusesScreen({super.key});

  @override
  State<BusesScreen> createState() => _BusesScreenState();
}

class _BusesScreenState extends State<BusesScreen> {
  List<Ruta> rutas = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchRutas();
  }

  Future<void> fetchRutas() async {
    try {
      final result = await ApiService.getRutas();
      setState(() {
        rutas = result;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error cargando rutas: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF922E42),
      appBar: AppBar(
        backgroundColor: const Color(0xFF922E42),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Camiones",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rutas.length,
              itemBuilder: (context, index) {
                final ruta = rutas[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      "/paradas",
                      arguments: ruta,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          "assets/icons/kooxbus_icon.png",
                          width: 48,
                          height: 48,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ruta.nombre,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${ruta.paradas.length} paradas",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.black38),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
