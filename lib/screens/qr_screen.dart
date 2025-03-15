import 'package:flutter/material.dart';
import 'custom_app_bar.dart';

class QRScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 10),
            Text(
              "Escanea o Genera un QR",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Si se pide escanear un QR, aquí saldrá la opción para escanear, sin embargo, si se pide generar un QR, aquí saldrá el formulario",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: () {},
              child: Text("Escanear QR", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: () {},
              child: Text("Generar QR", style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            SizedBox(height: 10),
            Text(
              "Mis QRs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _customButton("Firulais"),
                _customButton("Ver QR")
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _customButton("Editar Info"),
                _customButton("Borrar QR", isDelete: true)
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _customButton(String text, {bool isDelete = false}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDelete ? Colors.orange : Colors.white,
        foregroundColor: isDelete ? Colors.white : Colors.black,
        minimumSize: Size(80, 40),
        side: BorderSide(color: Colors.black),
      ),
      onPressed: () {},
      child: Text(text, style: TextStyle(fontSize: 14)),
    );
  }
}
