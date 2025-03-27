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

    const String petsUrl = "http://137.131.25.37:8000/api/pets/";

    try {
      final response = await http.get(
        Uri.parse(petsUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

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

    if (token == null) return;

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
        fetchMyPets(); // Actualiza la lista de mascotas
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR generado correctamente')),
        );
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

    if (token == null) return;

    const String deleteQRUrl = "http://192.168.1.95:8000/api/qr/delete/";

    try {
      final response = await http.delete(
        Uri.parse('$deleteQRUrl$petId/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        fetchMyPets(); // Actualiza la lista de mascotas
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR eliminado correctamente')),
        );
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

  void _showQRDetails(String qrContent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Información del QR"),
          content: SingleChildScrollView(child: Text(qrContent)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cerrar"),
            ),
          ],
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
                  final hasQR = pet['qrId'] != null;

                  // Generar el contenido del QR
                  final qrContent =
                      "Nombre: ${pet['name']}\n"
                      "Raza: ${pet['breed']}\n"
                      "Color: ${pet['color']}\n"
                      "Fecha de Nacimiento: ${pet['birthDate']}";

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
                          if (hasQR)
                            Column(
                              children: [
                                QrImageView(
                                  data:
                                  qrContent, // QR ahora muestra la info
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
                                          () => _showQRDetails(qrContent),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      child: const Text(
                                        "Ver Info",
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => deleteQR(petId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
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
                          if (!hasQR)
                            ElevatedButton(
                              onPressed: () => generateQR(petId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
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