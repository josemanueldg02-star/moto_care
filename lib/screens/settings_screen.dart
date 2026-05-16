import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Importamos el themeNotifier global

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Función para cambiar el tema y guardarlo en la memoria del móvil
  void _toggleTheme(bool isDark) async {
    // 1. Cambiamos el estado visual al instante
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    // 2. Guardamos la preferencia para que no se pierda al cerrar la app
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    // Detectamos en qué modo estamos para que el interruptor esté en la posición correcta
    final isDark = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ajustes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'PREFERENCIAS VISUALES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // Interruptor maestro del Modo Oscuro
          SwitchListTile(
            title: const Text('Modo Oscuro'),
            subtitle: const Text('Reduce la fatiga visual en entornos oscuros'),
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: isDark ? Colors.orangeAccent : Colors.blue,
            ),
            value: isDark,
            onChanged: (bool value) {
              setState(() {
                _toggleTheme(value);
              });
            },
          ),

          const Divider(),

          // Información de la App (queda muy bien en el portfolio)
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Moto Care',
            applicationVersion: '1.0.0',
            applicationLegalese:
                '©️ 2026 Desarrollado por un crack de la programación',
            aboutBoxChildren: [
              Text(
                '\nEsta aplicación ha sido creada como parte de un portfolio profesional de alto nivel, integrando servicios AWS y arquitectura Flutter moderna.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
