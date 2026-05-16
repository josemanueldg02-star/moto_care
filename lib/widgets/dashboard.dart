import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:moto_care/screens/settings_screen.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/ModelProvider.dart';
import '../screens/add_maintenance_screen.dart';
// Librerías para exportar a Excel/CSV
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<MaintenanceRecord> records = [];
  StreamSubscription<GraphQLResponse<MaintenanceRecord>>? subscription;
  StreamSubscription<GraphQLResponse<MaintenanceRecord>>? _updateSubscription;
  bool _isLoading = true;

  String _nombreMoto = 'Cargando...';
  String _searchQuery = ''; // Almacena el texto que tecleas

  @override
  void initState() {
    super.initState();
    _cargarNombreMoto();
    _sincronizarDatos();
    _iniciarSuscripcion();
  }

  @override
  void dispose() {
    subscription?.cancel();
    _updateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _cargarNombreMoto() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreMoto = prefs.getString('nombre_moto') ?? 'Mi Moto';
    });
  }

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
    // Canal de escucha para Nuevos Registros
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

    // Canal de escucha para Registros Editados
    final updateRequest = ModelSubscriptions.onUpdate(
      MaintenanceRecord.classType,
    );
    final updateStream = Amplify.API.subscribe(updateRequest);

    _updateSubscription = updateStream.listen((event) {
      final registroEditado = event.data;
      if (registroEditado != null) {
        setState(() {
          final index = records.indexWhere((r) => r.id == registroEditado.id);
          if (index != -1) {
            records[index] = registroEditado;
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

  Future<void> _mostrarFactura(String? receiptKey) async {
    if (receiptKey == null || receiptKey.isEmpty) return;

    try {
      final result = await Amplify.Storage.getUrl(
        path: StoragePath.fromString(receiptKey),
      ).result;

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text(
                    'Factura',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  backgroundColor: Colors.lightBlue,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Image.network(result.url.toString(), fit: BoxFit.contain),
              ],
            ),
          ),
        );
      }
    } on Exception catch (e) {
      print('❌ Error al descargar factura: $e');
    }
  }

  // --- ACTUALIZACIÓN: Función para generar y compartir el Excel (CSV) ---
  Future<void> _exportarDatosCSV() async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    try {
      // 1. Preparamos las cabeceras de las columnas
      String csvData = "Fecha,Título,Coste (€),Notas\n";

      // 2. Recorremos los registros y rellenamos las filas
      for (var record in records) {
        // Limpiamos comas y saltos de línea de las notas para que no rompan el Excel
        final notasLimpias = (record.notes ?? '')
            .replaceAll('\n', ' ')
            .replaceAll(',', ';');
        final fecha = _formatearFecha(record.date);

        csvData += "$fecha,${record.title},${record.cost},$notasLimpias\n";
      }

      // 3. Creamos un archivo temporal en la memoria caché del móvil
      final directorio = await getTemporaryDirectory();
      final rutaArchivo = '${directorio.path}/historial_moto.csv';
      final archivo = File(rutaArchivo);
      await archivo.writeAsString(csvData);

      // 4. Abrimos el menú nativo de iOS/Android para compartir el archivo
      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(rutaArchivo)],
          text: 'Aquí tienes el historial de mantenimiento de mi moto.',
          sharePositionOrigin:
              box!.localToGlobal(Offset.zero) & box.size, // Necesario para iPad
        );
      }
    } catch (e) {
      print('❌ Error al exportar: $e');
    }
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
        color: Theme.of(context).cardColor, // Color dinámico.
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ), // Borde dinámico.
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 2),
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
    // 1. Calculamos la lista filtrada en tiempo real para el ListView
    final filteredRecords = records.where((record) {
      return record.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // 2. El gasto total acumulado se sigue calculando con la lista completa original
    final gastoTotal = records.fold<double>(
      0,
      (sum, record) => sum + record.cost,
    );

    return Scaffold(
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
          // --- NUEVO: Botón para ir a Ajustes ---
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Ajustes',
          ),
          // --- NUEVO: Botón para exportar el CSV ---
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportarDatosCSV,
            tooltip: 'Exportar a Excel',
          ),
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

              // --- Barra de Búsqueda ---
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar revisión (ej. aceite)...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() => _searchQuery = '');
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).cardColor, // Automáticamente será blanco o negro según modo oscuro o blanco.
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 15),

              // --- Lista de Revisiones de Mantenimiento ---
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
                    : filteredRecords.isEmpty
                    ? Center(
                        child: Text(
                          'No hay resultados para "$_searchQuery"',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = filteredRecords[index];
                          return Slidable(
                            key: Key(record.id),
                            endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              extentRatio: 0.5,
                              children: [
                                SlidableAction(
                                  onPressed: (context) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddMaintenanceScreen(
                                              recordToEdit: record,
                                            ),
                                      ),
                                    );
                                  },
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit,
                                  label: 'Editar',
                                ),
                                SlidableAction(
                                  onPressed: (context) =>
                                      _borrarRevision(record),
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                  label: 'Borrar',
                                ),
                              ],
                            ),
                            child: Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                onTap: () => _mostrarFactura(record.receiptKey),
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
                                subtitle: Row(
                                  children: [
                                    Text(_formatearFecha(record.date)),
                                    if (record.receiptKey != null) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.receipt_long,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ],
                                ),
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
