import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart'; // Importamos la librería
import '../models/ModelProvider.dart';
import '../screens/add_maintenance_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<MaintenanceRecord> records = [];
  StreamSubscription<GraphQLResponse<MaintenanceRecord>>? subscription;
  bool _isLoading = true;

  String _nombreMoto = 'Cargando...'; // Texto temporal

  @override
  void initState() {
    super.initState();
    _cargarNombreMoto(); // Cargamos el nombre al inicio
    _sincronizarDatos();
    _iniciarSuscripcion();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  // --- NUEVO: Función para cargar el nombre guardado ---
  Future<void> _cargarNombreMoto() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Si no hay nada guardado, usamos 'Mi Moto' por defecto
      _nombreMoto = prefs.getString('nombre_moto') ?? 'Mi Moto';
    });
  }

  // --- NUEVO: Función para guardar el nombre en el dispositivo ---
  Future<void> _guardarNombreMoto(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nombre_moto', nombre);
  }

  void _ordenarRevisiones() {
    records.sort((a, b) {
      final fechaA = a.date.getDateTime();
      final fechaB = b.date.getDateTime();
      return fechaB.compareTo(fechaA);
    });
  }

  Future<void> _sincronizarDatos() async {
    try {
      final request = ModelQueries.list(MaintenanceRecord.classType);
      final response = await Amplify.API.query(request: request).response;

      final items = response.data?.items;
      if (items != null) {
        setState(() {
          records = items.whereType<MaintenanceRecord>().toList();
          _ordenarRevisiones();
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      print('❌ Error al sincronizar: ${e.message}');
      setState(() => _isLoading = false);
    }
  }

  void _iniciarSuscripcion() {
    final request = ModelSubscriptions.onCreate(MaintenanceRecord.classType);
    final stream = Amplify.API.subscribe(request);

    subscription = stream.listen((event) {
      final nuevaRevision = event.data;
      if (nuevaRevision != null) {
        setState(() {
          if (!records.any((r) => r.id == nuevaRevision.id)) {
            records.add(nuevaRevision);
            _ordenarRevisiones();
          }
        });
      }
    });
  }

  Future<void> _borrarRevision(MaintenanceRecord record) async {
    try {
      final request = ModelMutations.delete(record);
      await Amplify.API.mutate(request: request).response;
      setState(() => records.remove(record));
    } on ApiException catch (e) {
      print('❌ Error al borrar: ${e.message}');
    }
  }

  String _formatearFecha(TemporalDate temporalDate) {
    final date = temporalDate.getDateTime();
    final dia = date.day.toString().padLeft(2, '0');
    final mes = date.month.toString().padLeft(2, '0');
    return '$dia/$mes/${date.year}';
  }

  Future<void> _editarNombreMoto() async {
    final controller = TextEditingController(
      text: _nombreMoto == 'Cargando...' ? '' : _nombreMoto,
    );
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre de tu moto'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Ej. Kawasaki ER-6f'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text(
              'Guardar',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (nuevoNombre != null && nuevoNombre.trim().isNotEmpty) {
      setState(() {
        _nombreMoto = nuevoNombre.trim();
      });
      // Guardamos el nuevo nombre en la memoria del dispositivo
      await _guardarNombreMoto(_nombreMoto);
    }
  }

  Widget _construirGraficoAnual() {
    List<double> gastosPorMes = List.filled(12, 0.0);
    List<String> letrasMeses = [
      'E',
      'F',
      'M',
      'A',
      'M',
      'J',
      'J',
      'A',
      'S',
      'O',
      'N',
      'D',
    ];

    for (var record in records) {
      int mes = record.date.getDateTime().month;
      gastosPorMes[mes - 1] += record.cost;
    }

    double maximoGasto = gastosPorMes.reduce((a, b) => a > b ? a : b);
    if (maximoGasto == 0) maximoGasto = 1;

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gasto Anual por Mes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (index) {
                final porcentajeAltura = (gastosPorMes[index] / maximoGasto);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: '${gastosPorMes[index].toStringAsFixed(2)} €',
                      child: Container(
                        width: 14,
                        height: (porcentajeAltura * 80) > 2
                            ? (porcentajeAltura * 80)
                            : 2,
                        decoration: BoxDecoration(
                          color: gastosPorMes[index] > 0
                              ? Colors.green
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      letrasMeses[index],
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gastoTotal = records.fold<double>(
      0,
      (sum, record) => sum + record.cost,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _editarNombreMoto,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _nombreMoto,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit, color: Colors.white70, size: 18),
            ],
          ),
        ),
        backgroundColor: Colors.lightBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async => await Amplify.Auth.signOut(),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gasto Total Acumulado',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                '${gastoTotal.toStringAsFixed(2)} €',
                style: const TextStyle(
                  fontSize: 36,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              _construirGraficoAnual(),

              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.green),
                      )
                    : records.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay revisiones. ¡Añade la primera!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return Dismissible(
                            key: Key(record.id),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) => _borrarRevision(record),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.blueAccent,
                                  child: Icon(Icons.build, color: Colors.white),
                                ),
                                title: Text(
                                  record.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(_formatearFecha(record.date)),
                                trailing: Text(
                                  '${record.cost.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddMaintenanceScreen()),
        ),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
