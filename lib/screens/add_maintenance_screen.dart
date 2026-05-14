import 'dart:io'; // Necesario para manejar archivos físicos en el móvil
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
// --- NUEVO: Herramienta para abrir la cámara ---
import 'package:image_picker/image_picker.dart';
import '../models/ModelProvider.dart';

class AddMaintenanceScreen extends StatefulWidget {
  const AddMaintenanceScreen({super.key});

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _tituloController = TextEditingController();
  final _costeController = TextEditingController();
  final _notasController = TextEditingController();

  bool _isSaving = false;
  DateTime _fechaSeleccionada = DateTime.now();

  // --- NUEVO: Variable para guardar la foto que hagamos ---
  File? _imagenFactura;

  @override
  void dispose() {
    _tituloController.dispose();
    _costeController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaElegida != null && fechaElegida != _fechaSeleccionada) {
      setState(() => _fechaSeleccionada = fechaElegida);
    }
  }

  // --- NUEVO: Función para abrir la cámara nativa del iPhone ---
  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    // Aquí es exactamente donde iOS te lanzará el mensaje de "¿Permites a Moto Care usar la cámara?"
    final XFile? foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    ); // Reducimos un poco la calidad para que suba rápido

    if (foto != null) {
      setState(() {
        _imagenFactura = File(foto.path); // Guardamos la ruta del archivo local
      });
    }
  }

  // --- ACTUALIZADO: Función de guardado en dos pasos (S3 + Base de datos) ---
  Future<void> _guardarEnAWS() async {
    if (_tituloController.text.isEmpty || _costeController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      String? rutaDiscoDuro; // Aquí guardaremos la "etiqueta" de S3

      // PASO 1: Si el usuario ha hecho una foto, la subimos a Amazon S3
      if (_imagenFactura != null) {
        // Generamos un nombre único basado en la fecha exacta para no sobreescribir fotos
        final nombreUnico =
            'facturas/${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Ejecutamos la subida al disco duro
        await Amplify.Storage.uploadFile(
          localFile: AWSFile.fromPath(_imagenFactura!.path),
          path: StoragePath.fromString(
            nombreUnico,
          ), // Usamos StoragePath como exige la nueva versión Gen 2
        ).result;

        rutaDiscoDuro = nombreUnico; // Guardamos el nombre para el paso 2
        print('📸 Foto subida con éxito a S3: $rutaDiscoDuro');
      }

      // PASO 2: Guardamos el texto y los números en la Base de Datos
      final nuevaRevision = MaintenanceRecord(
        title: _tituloController.text,
        cost: double.parse(_costeController.text.replaceAll(',', '.')),
        date: TemporalDate(_fechaSeleccionada),
        notes: _notasController.text.isNotEmpty ? _notasController.text : null,
        receiptKey:
            rutaDiscoDuro, // Inyectamos la etiqueta de la foto (o null si no hay)
      );

      final request = ModelMutations.create(nuevaRevision);
      await Amplify.API.mutate(request: request).response;

      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      print('❌ Error al guardar: $e');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Nueva Revisión',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.lightBlue, // A juego con tu Dashboard
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Usamos SingleChildScrollView para que la pantalla se pueda desplazar si el teclado tapa cosas
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _costeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Coste total (€)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.lightBlue),
                  const SizedBox(width: 10),
                  Text(
                    'Fecha: ${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _seleccionarFecha(context),
                    child: const Text(
                      'Cambiar',
                      style: TextStyle(
                        color: Colors.lightBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notasController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas del taller (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // --- NUEVO: Sección visual para la cámara ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _tomarFoto,
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text(
                      'Escanear Factura',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                if (_imagenFactura != null) ...[
                  const SizedBox(width: 15),
                  // Si hay foto, mostramos una pequeña miniatura cuadrada
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _imagenFactura!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _guardarEnAWS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Guardar Revisión',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
