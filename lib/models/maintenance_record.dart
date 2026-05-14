// lib/models/maintenance_record.dart

class MaintenanceRecord {
  final String id;
  final String title; 
  final DateTime date;
  final int mileage; 
  final String description; 
  final double cost;

  MaintenanceRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.mileage,
    required this.description,
    required this.cost,
  });

  // Convierte el objeto a JSON para enviarlo a la base de datos
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'mileage': mileage,
      'description': description,
      'cost': cost,
    };
  }

  // Convierte el JSON de la base de datos en un objeto para la app
  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: json['id'],
      title: json['title'],
      date: DateTime.parse(json['date']),
      mileage: json['mileage'],
      description: json['description'],
      cost: (json['cost'] as num).toDouble(),
    );
  }
}