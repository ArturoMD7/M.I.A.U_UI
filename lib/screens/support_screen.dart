import 'package:flutter/material.dart';
import 'custom_app_bar.dart';

const Color primaryColor = Color(0xFFD0894B);

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¿Buscas apoyo?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            _buildCategory("Grupo de Adopción", [
              _buildSupportItem(context, "Grupo de adopción A"),
              _buildSupportItem(context, "Grupo de adopción B"),
              _buildSupportItem(context, "Grupo de adopción C"),
            ]),
            SizedBox(height: 20),
            _buildCategory("Rescatistas", [
              _buildSupportItem(context, "Rescatista 1"),
              _buildSupportItem(context, "Rescatista 2"),
              _buildSupportItem(context, "Rescatista 3"),
            ]),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(String category, List<Widget> items) {
    return ExpansionTile(
      title: Text(
        category,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      children: items,
    );
  }

  Widget _buildSupportItem(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
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
              _showContactDialog(context, title);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: Size(120, 50),
            ),
            child: Text("Más información"),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Información de contacto"),
          content: Text(
            "Aquí va la información de contacto del $title.",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }
}
