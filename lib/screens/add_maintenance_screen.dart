import 'dart:io'; // Necesario para manejar archivos físicos en el móvil
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
// --- NUEVO: Herramienta para abrir la cámara ---
import 'package:image_picker/image_picker.dart';
import '../models/ModelProvider.dart';

class AddMaintenanceScreen extends StatefulWidget {
  // Declaramos la variable que guardará el registro si estamos editando.
  final MaintenanceRecord? recordToEdit;

  const AddMaintenanceScreen({super.key, this.recordToEdit});

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

  // --- NUEVO: Lógica de inicialización ---
  @override
  void initState() {
    super.initState();
    // Si la pantalla ha recibido un registro para editar...
    if (widget.recordToEdit != null) {
      final rec = widget.recordToEdit!;
      // Auto-rellenamos los controladores con los datos viejos.
      _tituloController.text = rec.title;
      _costeController.text = rec.cost.toString().replaceAll(".", ",");
      _fechaSeleccionada = rec.date.getDateTime();
      _notasController.text = rec.notes ?? '';
      // NOTA UX: No rellenamos _imagenFactura con la remota,
      // dejamos que el usuario suba una NUEVA local si quiere cambiarla.
    }
  }

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

  // --- ACTUALIZADO: Función flexible para Cámara o Galería. ---
  Future<void> _seleccionarImagen(ImageSource source) async {
    final picker = ImagePicker();
    // Aquí es donde decidimos si es cámara o galería.
    final XFile? foto = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (foto != null) {
      setState(() {
        _imagenFactura = File(foto.path);
      });
    }
  }

  // --- ACTUALIZADO: Función de guardado en dos pasos (S3 + Base de datos) ---
  Future<void> _guardarEnAWS() async {
    if (_tituloController.text.isEmpty || _costeController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      // Usamos la misma lógica de subida de foto local (ya la tienes)
      String? rutaDiscoDuro;
      if (_imagenFactura != null) {
        // ... (tu código de subida a S3 de ayer)
        final nombreUnico =
            'facturas/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Amplify.Storage.uploadFile(
          localFile: AWSFile.fromPath(_imagenFactura!.path),
          path: StoragePath.fromString(nombreUnico),
        ).result;
        rutaDiscoDuro = nombreUnico;
        print('📸 Foto subida con éxito a S3: $rutaDiscoDuro');
      }

      // --- CAMBIO AQUÍ: Decidimos si Crear o Actualizar ---

      if (widget.recordToEdit != null) {
        // MODO EDITAR: Usamos .copyWith para modificar solo lo que ha cambiado
        final revisionActualizada = widget.recordToEdit!.copyWith(
          title: _tituloController.text,
          cost: double.parse(_costeController.text.replaceAll(',', '.')),
          date: TemporalDate(_fechaSeleccionada),
          notes: _notasController.text.isNotEmpty
              ? _notasController.text
              : null,
          // Si subió foto nueva, ponemos la nueva ruta. Si no, mantenemos la vieja.
          receiptKey: rutaDiscoDuro ?? widget.recordToEdit!.receiptKey,
        );

        // Llamamos a la mutación .update (crucial)
        final request = ModelMutations.update(revisionActualizada);
        await Amplify.API.mutate(request: request).response;
        print('✅ Registro actualizado con éxito en AWS');
      } else {
        // MODO AÑADIR (lo que ya tenías)
        final nuevaRevision = MaintenanceRecord(
          title: _tituloController.text,
          cost: double.parse(_costeController.text.replaceAll(',', '.')),
          date: TemporalDate(_fechaSeleccionada),
          notes: _notasController.text.isNotEmpty
              ? _notasController.text
              : null,
          receiptKey: rutaDiscoDuro,
        );

        final request = ModelMutations.create(nuevaRevision);
        await Amplify.API.mutate(request: request).response;
        print('✅ Registro creado con éxito en AWS');
      }

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
        title: Text(
          widget.recordToEdit != null ? 'Editar Revisión' : 'Nueva Revisión',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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

            // --- ACTUALIZADO: Fila con dos botones para adjuntar factura ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarImagen(ImageSource.gallery),
                    icon: const Icon(
                      Icons.photo_library,
                      color: Colors.blueGrey,
                    ),
                    label: const Text(
                      'Galería',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarImagen(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, color: Colors.blueGrey),
                    label: const Text(
                      'Cámara',
                      style: TextStyle(color: Colors.blueGrey),
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
                    : Text(
                        widget.recordToEdit != null
                            ? 'Guardar Cambios'
                            : 'Guardar Revisión',
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
