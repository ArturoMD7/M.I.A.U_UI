import 'package:flutter/material.dart';
import 'custom_app_bar.dart';

class AdoptScreen extends StatefulWidget {
  @override
  _AdoptScreenState createState() => _AdoptScreenState();
}

class _AdoptScreenState extends State<AdoptScreen> {
  final List<Map<String, String>> adoptablePets = [
    {
      "image": "assets/images/pet1.jpg",
      "owner": "Juan Pérez",
      "description": "Labrador juguetón de 2 años en busca de hogar.",
    },
    {
      "image": "assets/images/pet2.jpg",
      "owner": "Ana López",
      "description": "Gata cariñosa y esterilizada, lista para adopción.",
    },
    {
      "image": "assets/images/pet3.jpg",
      "owner": "Carlos Gómez",
      "description": "Perro mediano muy amigable, ideal para familias.",
    },
    {
      "image": "assets/images/pet4.jpg",
      "owner": "Laura Rodríguez",
      "description": "Cachorro tierno, busca un hogar amoroso.",
    },
  ];

  String? selectedSize;
  String? selectedAge;
  String? selectedFur;
  String? selectedVaccination;
  String? selectedSterilized;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: Column(
        children: [
          SizedBox(height: 10),
          Text(
            "Adopta una mascota",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: Wrap(
              spacing: 10,
              children: [
                DropdownButton<String>(
                  hint: Text("Tamaño"),
                  value: selectedSize,
                  items: ["Pequeño", "Mediano", "Grande"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedSize = newValue;
                    });
                  },
                ),
                DropdownButton<String>(
                  hint: Text("Edad"),
                  value: selectedAge,
                  items: ["Cachorro", "Joven", "Adulto"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedAge = newValue;
                    });
                  },
                ),
                DropdownButton<String>(
                  hint: Text("Pelaje"),
                  value: selectedFur,
                  items: ["Corto", "Medio", "Largo"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedFur = newValue;
                    });
                  },
                ),
                DropdownButton<String>(
                  hint: Text("Vacunas"),
                  value: selectedVaccination,
                  items: ["Sí", "No"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedVaccination = newValue;
                    });
                  },
                ),
                DropdownButton<String>(
                  hint: Text("Esterilizado"),
                  value: selectedSterilized,
                  items: ["Sí", "No"].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedSterilized = newValue;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: adoptablePets.length,
              itemBuilder: (context, index) {
                final pet = adoptablePets[index];
                return Card(
                  elevation: 3,
                  margin: EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: Text("Publicar mascota en adopción"),
        icon: Icon(Icons.add),
      ),
    );
  }
}
