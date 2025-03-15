import 'package:flutter/material.dart';
import 'custom_app_bar.dart';

class LostPetsScreen extends StatelessWidget {
  final List<Map<String, String>> lostPets = [
    {
      "image": "assets/images/pet1.jpg",
      "owner": "Juan Pérez",
      "description": "Perro labrador perdido en el parque central.",
    },
    {
      "image": "assets/images/pet2.jpg",
      "owner": "Ana López",
      "description": "Gato siamés desaparecido cerca de la avenida principal.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: ListView.builder(
        padding: EdgeInsets.all(10),
        itemCount: lostPets.length,
        itemBuilder: (context, index) {
          final pet = lostPets[index];
          return Card(
            elevation: 3,
            margin: EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                Image.asset(pet["image"]!, fit: BoxFit.cover, height: 200, width: double.infinity),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pet["owner"]!, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text(pet["description"]!, style: TextStyle(fontSize: 14)),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: Icon(Icons.comment, color: Colors.blue),
                            label: Text("Comentar"),
                            onPressed: () {},
                          ),
                          TextButton.icon(
                            icon: Icon(Icons.message, color: Colors.green),
                            label: Text("Enviar mensaje"),
                            onPressed: () {},
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navegar a la pantalla de creación de publicación
        },
        label: Text("Perdí a mi mascota"),
        icon: Icon(Icons.add),
      ),
    );
  }
}
