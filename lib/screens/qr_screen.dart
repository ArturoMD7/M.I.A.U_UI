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
    final int? userId = prefs.getInt('user_id');

    if (token == null || userId == null) {
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
                      final qrId = pet['qrId'];
                      final qrCodeUrl =
                          qrId is Map ? qrId['qr_code_url'] : null;

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
                              if (qrCodeUrl != null)
                                Column(
                                  children: [
                                    QrImageView(
                                      data: qrCodeUrl,
                                      version: QrVersions.auto,
                                      size: 150.0,
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      onPressed: () => deleteQR(pet['id']),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        "Eliminar QR",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              if (qrCodeUrl == null)
                                ElevatedButton(
                                  onPressed: () => generateQR(pet['id']),
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
