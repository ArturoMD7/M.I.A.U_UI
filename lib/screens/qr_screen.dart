import 'package:flutter/material.dart';
import 'package:miauuic/presentation/screens/pets/my_pets_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

class QRScreen extends StatefulWidget {
  const QRScreen({super.key});

  @override
  _QRScreenState createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  List<dynamic> myPets = [];
  bool isLoading = true;

  String get baseUrl => apiService.baseUrl;

  @override
  void initState() {
    super.initState();
    fetchMyPets();
  }

  void generateAndDownloadPDF(Map<String, dynamic> pet) async {
    try {
      final pdf = pw.Document();

      final qrImageUrl = pet['qrUrl'];
      if (qrImageUrl == null) {
        print("No hay URL de QR disponible");
        return;
      }

      final response = await http.get(Uri.parse(qrImageUrl));
      final qrImage = pw.MemoryImage(response.bodyBytes);

      //Crear el diseño del PDF
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text("Identificación de Mascota"),
                ),
                pw.SizedBox(height: 20),
                pw.Text("Nombre: ${pet['name']}"),
                pw.Text("Raza: ${pet['breed']}"),
                pw.SizedBox(height: 20),
                pw.Image(
                  qrImage,
                  width: 200,
                  height: 200,
                ), // Aquí dibujamos el QR
                pw.SizedBox(height: 20),
                pw.Text(
                  "Escanea este código para ver mi información.",
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                ),
              ],
            );
          },
        ),
      );

      // Guardar o Compartir
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'QR_${pet['name']}.pdf',
      );
    } catch (e) {
      print("Error generando PDF: $e");
    }
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

    final String petsUrl = "$baseUrl/pets/my-pets/";

    try {
      final response = await http.get(
        Uri.parse(petsUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> petsData;
        if (decoded is List) {
          petsData = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded.containsKey('data')) {
          petsData = (decoded['data'] as List<dynamic>?) ?? [];
        } else {
          petsData = [];
        }
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

    final String generateQRUrl = "$baseUrl/codeqr/generate_qr/";

    try {
      final response = await http.post(
        Uri.parse(generateQRUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pet_id': petId}),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  Future<void> deleteQR(int petId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('jwt_token');

    if (token == null) return;

    final String deleteQRUrl = "$baseUrl/codeqr/";

    try {
      final response = await http.delete(
        Uri.parse('$deleteQRUrl$petId/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 204) {
        fetchMyPets();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR eliminado correctamente')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyPetsScreen()),
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
      appBar: AppBar(
        title: const Text('Generar QR'),
        backgroundColor: const Color(0xFFD0894B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          },
        ),
      ),
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
                  child: Center(child: Text("No tienes mascotas registradas")),
                )
                : Expanded(
                  child: ListView.builder(
                    itemCount: myPets.length,
                    itemBuilder: (context, index) {
                      final pet = myPets[index];
                      final petId = pet['id'];
                      final hasQR = pet['qrId'] != null;
                      final status = _getStatusText(pet['statusAdoption']);

                      // Generar el contenido del QR con información completa
                      final qrContent = """
                      Nombre: ${pet['name'] ?? 'No disponible'}
                      Edad: ${pet['age'] ?? 'No disponible'}
                      Estado: $status
                      Nota: Los datos del dueño agregados en el QR son su nombre y su correo
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
                                status,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              if (hasQR)
                                Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton(
                                          onPressed:
                                              () => generateAndDownloadPDF(pet),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                          child: const Text(
                                            "Ver PDF",
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
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.black,
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
