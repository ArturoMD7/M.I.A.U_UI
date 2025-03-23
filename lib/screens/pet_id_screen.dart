import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_app_bar.dart';
import '../services/pet_provider.dart';

class PetIdScreen extends StatelessWidget {
  const PetIdScreen({super.key});

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  @override
  Widget build(BuildContext context) {
    final petProvider = Provider.of<PetProvider>(context);

    // Llama a fetchPets solo si no se ha cargado antes
    if (!petProvider.hasLoaded && !petProvider.isLoading) {
      getToken().then((token) {
        if (token != null) {
          petProvider.fetchPets(token); // Pasar el token a fetchPets
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No se encontró un token de autenticación."),
            ),
          );
        }
      });
    }

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
              child:
                  petProvider.isLoading
                      ? Center(child: CircularProgressIndicator())
                      : petProvider.pets.isEmpty
                      ? Center(
                        child: Text(
                          "No tienes mascotas registradas aún.",
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                      : ListView.builder(
                        itemCount: petProvider.pets.length,
                        itemBuilder: (context, index) {
                          final pet = petProvider.pets[index];
                          // Manejar valores nulos
                          final petName = pet['name'] ?? 'Nombre no disponible';
                          final imagePath =
                              pet['imagePath'] ??
                              'https://via.placeholder.com/150'; // Imagen por defecto
                          return _buildPetCard(petName, imagePath);
                        },
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/add-pet');
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
          backgroundImage: NetworkImage(imagePath),
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
