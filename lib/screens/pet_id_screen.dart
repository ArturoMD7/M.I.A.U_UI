import 'package:flutter/material.dart';
import 'custom_app_bar.dart';

class PetIdScreen extends StatelessWidget {
  const PetIdScreen({super.key});

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
              "Carnets de Mascotas",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  _buildPetCard("Firulais", "assets/images/pet1.jpg"),
                  _buildPetCard("Mishka", "assets/images/pet2.jpg"),
                  _buildPetCard("Rocky", "assets/images/pet3.jpg"),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navegar a la pantalla de agregar carnet
        },
        icon: Icon(Icons.add),
        label: Text("Agregar Carnet"),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildPetCard(String petName, String imagePath) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: AssetImage(imagePath),
          radius: 30,
        ),
        title: Text(
          petName,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                // Editar información del carnet
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                // Borrar carnet
              },
            ),
          ],
        ),
      ),
    );
  }
}
