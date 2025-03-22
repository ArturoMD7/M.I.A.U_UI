import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_scan2/barcode_scan2.dart'; // Importación corregida
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'custom_app_bar.dart';

class QRScreen extends StatefulWidget {
  const QRScreen({super.key});

  @override
  _QRScreenState createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  String qrData = ""; // Cambiado de 'final' a 'String'
  List<dynamic> myQRs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyQRs();
  }

  Future<void> fetchMyQRs() async {
    const String qrUrl = "http://192.168.1.95:8000/api/qr/";

    try {
      final response = await http.get(Uri.parse(qrUrl));

      if (response.statusCode == 200) {
        final List<dynamic> qrData = jsonDecode(response.body);
        setState(() {
          myQRs = qrData;
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

  Future<void> generateQR() async {
    const String createQRUrl = "http://192.168.1.95:8000/api/qr/create/";

    // Datos necesarios para crear el QR
    Map<String, dynamic> qrData = {
      "qr_code_url": "https://example.com/qr_code", // URL del código QR
      "pdf_url": "https://example.com/pdf", // URL del PDF
    };

    try {
      final response = await http.post(
        Uri.parse(createQRUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(qrData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          qrData = responseData['qr_code_url']; // Actualiza la URL del QR
        });
        fetchMyQRs(); // Actualiza la lista de QRs
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

  Future<void> scanQR() async {
    try {
      final result =
          await BarcodeScanner.scan(); // Uso correcto de BarcodeScanner
      if (result.rawContent.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(pdfUrl: result.rawContent),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al escanear el QR: $e')));
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
              "Escanea o Genera un QR",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child:
                  qrData.isEmpty
                      ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "Si se pide escanear un QR, aquí saldrá la opción para escanear, sin embargo, si se pide generar un QR, aquí saldrá el formulario",
                          textAlign: TextAlign.center,
                        ),
                      )
                      : QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: scanQR,
              child: const Text(
                "Escanear QR",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: generateQR,
              child: const Text(
                "Generar QR",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Mis QRs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            isLoading
                ? const CircularProgressIndicator()
                : Expanded(
                  child: ListView.builder(
                    itemCount: myQRs.length,
                    itemBuilder: (context, index) {
                      final qr = myQRs[index];
                      return ListTile(
                        title: Text(qr['pet_name'] ?? "Sin nombre"),
                        subtitle: Text(qr['qr_code_url'] ?? "Sin URL"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                // Editar información del QR
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                // Borrar QR
                              },
                            ),
                          ],
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

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PDF")),
      body: Center(child: Text("Visualizar PDF: $pdfUrl")),
    );
  }
}
