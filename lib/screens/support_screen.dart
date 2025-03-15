import 'package:flutter/material.dart';
import 'custom_app_bar.dart';
const Color primaryColor = Color(0xFFD0894B);

class SupportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "¿Buscas apoyo?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildSupportItem("Grupo de adopción"),
            SizedBox(height: 10),
            _buildSupportItem("Rescatista"),
            SizedBox(height: 10),
            _buildSupportItem("Grupo de adopción"),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportItem(String title) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        SizedBox(width: 10),
        ElevatedButton(
          onPressed: () {
            // Acción al presionar "Contactar"
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            minimumSize: Size(120, 50),
          ),
          child: Text("Contactar"),
        ),
      ],
    );
  }
}
