import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_app_bar.dart';

class QRScreen extends StatefulWidget {
  const QRScreen({super.key});

  @override
  _QRScreenState createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  String qrData = "";
  List<dynamic> myPets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyPets();
  }

  Future<void> fetchMyPets() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    const String petsUrl = "http://192.168.1.95:8000/api/pets/";

    try {
      final response = await http.get(
        Uri.parse(petsUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("Respuesta del servidor: ${response.body}"); // Agregar esta línea

      if (response.statusCode == 200) {
        final List<dynamic> petsData = jsonDecode(response.body);
        setState(() {
          myPets = petsData;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> generateQR(int petId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      return;
    }

    const String generateQRUrl = "http://192.168.1.95:8000/api/generate-qr/";

    try {
      final response = await http.post(
        Uri.parse('$generateQRUrl$petId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          qrData = responseData['qr_code_url'];
        });
        fetchMyPets(); // Actualiza la lista de mascotas
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el QR: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  Future<void> deleteQR(int petId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) {
      return;
    }

    const String deleteQRUrl = "http://192.168.1.95:8000/api/qr/delete/";

    try {
      final response = await http.delete(
        Uri.parse('$deleteQRUrl$petId/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          qrData = ""; // Limpiar el QR generado
        });
        fetchMyPets(); // Actualiza la lista de mascotas
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('QR eliminado correctamente')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el QR: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  void _showQRPreview(String qrCodeUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: qrCodeUrl,
                version: QrVersions.auto,
                size: 250.0,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cerrar"),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            const Text(
              "Mis Mascotas y sus QRs",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            isLoading
                ? const CircularProgressIndicator()
                : Expanded(
                  child: ListView.builder(
                    itemCount: myPets.length,
                    itemBuilder: (context, index) {
                      final pet = myPets[index];
                      final petId = pet['id'];
                      final qrId = pet['qrId']; // qrId es un número entero

                      // Verificar si el qrId es válido (no es 1 ni null)
                      final bool hasValidQR = qrId != null && qrId != 1;
                      final qrCodeUrl =
                          hasValidQR
                              ? "http://192.168.1.95:8000/media/qr_$qrId.png"
                              : null;

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pet['name'] ?? "Sin nombre",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Raza: ${pet['breed'] ?? "Sin raza"}",
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              if (hasValidQR && qrCodeUrl != null)
                                Column(
                                  children: [
                                    QrImageView(
                                      data: qrCodeUrl,
                                      version: QrVersions.auto,
                                      size: 150.0,
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton(
                                          onPressed:
                                              () => _showQRPreview(qrCodeUrl),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 10,
                                            ),
                                          ),
                                          child: const Text(
                                            "Ver QR",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => deleteQR(petId),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 10,
                                            ),
                                          ),
                                          child: const Text(
                                            "Eliminar QR",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              if (!hasValidQR)
                                ElevatedButton(
                                  onPressed: () => generateQR(petId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    "Generar QR",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
