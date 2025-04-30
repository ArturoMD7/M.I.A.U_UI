import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'custom_app_bar.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


class QRScreen extends StatefulWidget {
  const QRScreen({super.key});

  @override
  _QRScreenState createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  List<dynamic> myPets = [];
  bool isLoading = true;
  late String baseUrl;

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['API_URL'] ?? 'http://137.131.25.37:8000';
    fetchMyPets();
  }

  void generateAndDownloadPDF(String qrData, Map<String, dynamic> pet) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Datos del QR", style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 10),
              pw.Text("Nombre: ${pet['name'] ?? 'Sin nombre'}"),
              pw.Text("Raza: ${pet['breed'] ?? 'Sin raza'}"),
              pw.Text("Datos QR: $qrData"),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 200,
                  height: 200,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
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

    final String petsUrl = "$baseUrl/pets/";

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

    final String generateQRUrl = "$baseUrl/generate-qr/";

    try {
      final response = await http.post(
        Uri.parse('$generateQRUrl$petId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 201) {
        fetchMyPets();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR generado correctamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el QR: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  Future<void> deleteQR(int petId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) return;

    final String deleteQRUrl = "$baseUrl/qr/delete/";

    try {
      final response = await http.delete(
        Uri.parse('$deleteQRUrl$petId/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        fetchMyPets();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR eliminado correctamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el QR: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  void _showQRDetails(String qrContent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Información del QR"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Esta información está codificada en el QR:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(qrContent),
              ],
            ),
          ),
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
                : myPets.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Text("No tienes mascotas registradas"),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: myPets.length,
                          itemBuilder: (context, index) {
                            final pet = myPets[index];
                            final petId = pet['id'];
                            final hasQR = pet['qrId'] != null;
                            print("usuarios");
                            final user = (pet['userId'] != null && pet['userId'] is Map) ? pet['userId'] : {};
                            print(user);


                            // Generar el contenido del QR con información completa
                            final qrContent = """
                                Nombre de la mascota: ${pet['name'] ?? 'No disponible'}
                                Edad: ${pet['age'] ?? 'No disponible'}
                                Raza: ${pet['breed'] ?? 'No disponible'}
                                Tamaño: ${pet['size'] ?? 'No disponible'}
                                Estado: ${_getStatusText(pet['statusAdoption'])}

                                Dueño:
                                - Nombre: ${user['name'] ?? 'No disponible'} ${user['first_name'] ?? ''}
                                - Email: ${user['email'] ?? 'No disponible'}
                                - Teléfono: ${user['phone_number'] ?? 'No disponible'}
                                - Ubicación: ${user['neighborhood'] ?? ''}, ${user['city'] ?? ''}, ${user['state'] ?? ''}
                            """;


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
                                      "Estatus de adopcion: ${pet['statusAdoption'] ?? "No disponible"}",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Dueño: ${user['name'] ?? 'No disponible'} ${user['first_name'] ?? ''}",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 10),
                                    if (hasQR)
                                      Column(
                                        children: [
                                          QrImageView(
                                            data: qrContent,
                                            version: QrVersions.auto,
                                            size: 150.0,
                                          ),
                                          const SizedBox(height: 10),
                                            ElevatedButton(
                                              onPressed: () => generateAndDownloadPDF(qrContent, pet),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange,
                                              ),
                                              child: const Text(
                                                "Ver PDF",
                                                style: TextStyle(color: Colors.white),
                                              ),
                                            ),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              ElevatedButton(
                                                onPressed: () => _showQRDetails(qrContent),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                ),
                                                child: const Text(
                                                  "Ver Info",
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => deleteQR(petId),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text(
                                                  "Eliminar QR",
                                                  style: TextStyle(color: Colors.white),
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

  String _getStatusText(int? status) {
    switch (status) {
      case 0:
        return 'Perdido';
      case 1:
        return 'En adopción';
      case 2:
        return 'Adoptado';
      default:
        return 'Estado desconocido';
    }
  }
}