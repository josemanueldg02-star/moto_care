import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/ModelProvider.dart';

class AddMaintenanceScreen extends StatefulWidget {
  final MaintenanceRecord? recordToEdit;

  const AddMaintenanceScreen({super.key, this.recordToEdit});

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();

  final _tituloController = TextEditingController();
  final _costeController = TextEditingController();
  final _notasController = TextEditingController();

  DateTime _fechaSeleccionada = DateTime.now();
  XFile? _imagenFactura;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Modo Editar: Auto-rellenamos los campos con los valores existentes
    if (widget.recordToEdit != null) {
      final rec = widget.recordToEdit!;
      _tituloController.text = rec.title;
      _costeController.text = rec.cost.toString().replaceAll('.', ',');
      _fechaSeleccionada = rec.date.getDateTime();
      _notasController.text = rec.notes ?? '';
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = picked;
      });
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imagenFactura = image;
      });
    }
  }

  String _formatearFecha(DateTime date) {
    final dia = date.day.toString().padLeft(2, '0');
    final mes = date.month.toString().padLeft(2, '0');
    return '$dia/$mes/${date.year}';
  }

  Future<void> _guardarEnAWS() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? rutaDiscoDuro;

      // Si el usuario ha seleccionado una nueva foto local, la subimos a S3
      if (_imagenFactura != null) {
        final nombreUnico =
            'facturas/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Amplify.Storage.uploadFile(
          localFile: AWSFile.fromPath(_imagenFactura!.path),
          path: StoragePath.fromString(nombreUnico),
        ).result;
        rutaDiscoDuro = nombreUnico;
        print('📸 Foto subida con éxito a S3: $rutaDiscoDuro');
      }

      if (widget.recordToEdit != null) {
        // MODO EDITAR: Actualizamos el registro existente usando copyWith
        final revisionActualizada = widget.recordToEdit!.copyWith(
          title: _tituloController.text.trim(),
          cost: double.parse(_costeController.text.replaceAll(',', '.').trim()),
          date: TemporalDate(_fechaSeleccionada),
          notes: _notasController.text.trim().isNotEmpty
              ? _notasController.text.trim()
              : null,
          receiptKey: rutaDiscoDuro ?? widget.recordToEdit!.receiptKey,
        );

        final request = ModelMutations.update(revisionActualizada);
        await Amplify.API.mutate(request: request).response;
        print('Flutter: Registro actualizado con éxito en AWS');
      } else {
        // MODO AÑADIR: Creamos un registro completamente nuevo
        final nuevaRevision = MaintenanceRecord(
          title: _tituloController.text.trim(),
          cost: double.parse(_costeController.text.replaceAll(',', '.').trim()),
          date: TemporalDate(_fechaSeleccionada),
          notes: _notasController.text.trim().isNotEmpty
              ? _notasController.text.trim()
              : null,
          receiptKey: rutaDiscoDuro,
        );

        final request = ModelMutations.create(nuevaRevision);
        await Amplify.API.mutate(request: request).response;
        print('Flutter: Registro creado con éxito en AWS');
      }

      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      print('❌ Error de comunicación con AWS: ${e.message}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: ${e.message}')));
    } catch (e) {
      print('❌ Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Almacenamos si hay una factura previa en la nube para mostrar el aviso visual
    final tieneFacturaPrevia = widget.recordToEdit?.receiptKey != null;

    return Scaffold(
      // Eliminado backgroundColor fijo para que use el del tema (claro/oscuro) automáticamente
      appBar: AppBar(
        title: Text(
          widget.recordToEdit != null ? 'Editar Revisión' : 'Nueva Revisión',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Campo: Título de la revisión
                TextFormField(
                  controller: _tituloController,
                  autofocus: widget.recordToEdit == null,
                  decoration: InputDecoration(
                    labelText: 'Concepto',
                    hintText: 'Ej. Cambio de Aceite, Neumáticos...',
                    filled: true,
                    fillColor: Theme.of(context).cardColor, // Dinámico
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, introduce el concepto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Campo: Coste Económico
                TextFormField(
                  controller: _costeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Coste (€)',
                    hintText: '0,00',
                    filled: true,
                    fillColor: Theme.of(context).cardColor, // Dinámico
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, introduce el coste';
                    }
                    final valorLimpio = value.replaceAll(',', '.').trim();
                    if (double.tryParse(valorLimpio) == null) {
                      return 'Introduce un número válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Selector de Fecha Estilo Tarjeta
                InkWell(
                  onTap: () => _seleccionarFecha(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor, // Dinámico
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade600),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Fecha de revisión',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatearFecha(_fechaSeleccionada),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo: Notas Adicionales
                TextFormField(
                  controller: _notasController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notas (Opcional)',
                    hintText: 'Kilómetros de la moto, marca de repuestos...',
                    filled: true,
                    fillColor: Theme.of(context).cardColor, // Dinámico
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // Zona de Factura / Adjunto Visual
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade600),
                  ),
                  color: Theme.of(context).cardColor, // Dinámico
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        if (_imagenFactura != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_imagenFactura!.path),
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ] else if (tieneFacturaPrevia) ...[
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_done, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Factura guardada en la nube',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        ElevatedButton.icon(
                          onPressed: _seleccionarImagen,
                          icon: const Icon(Icons.photo_library),
                          label: Text(
                            _imagenFactura != null || tieneFacturaPrevia
                                ? 'Cambiar Factura'
                                : 'Adjuntar Factura (Imagen)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 35),

                // Botón Principal de Acción de Enviar
                ElevatedButton(
                  onPressed: _isSaving ? null : _guardarEnAWS,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.recordToEdit != null
                              ? 'Guardar Cambios'
                              : 'Guardar Revisión',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
