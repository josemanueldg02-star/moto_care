import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
// 1. Importamos los nuevos módulos de seguridad y pantallas
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
// Importamos el motor de almacenamiento.
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/ModelProvider.dart';
import 'widgets/dashboard.dart';
// --- NUEVO: Control manual de la pantalla de carga ---
import 'package:flutter_native_splash/flutter_native_splash.dart';

// --- NUEVO: Gestor global para el Modo Oscuro ---
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  // --- NUEVO: Congelamos la pantalla de carga nativa ---
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    final apiPlugin = AmplifyAPI(
      options: APIPluginOptions(modelProvider: ModelProvider.instance),
    );
    // 2. Instanciamos el plugin de Autenticación
    final authPlugin = AmplifyAuthCognito();

    final storagePlugin = AmplifyStorageS3();
    // 3. Añadimos AMBOS motores a Amplify
    await Amplify.addPlugins([apiPlugin, authPlugin, storagePlugin]);

    String amplifyConfig = await rootBundle.loadString('amplify_outputs.json');
    await Amplify.configure(amplifyConfig);
    print('¡Conexión a AWS activada con éxito! 🚀');

    // Retiramos la pantalla de carga porque el backend ya está listo.
    FlutterNativeSplash.remove();
    print('¡Conexión a AWS (API, Auth y Storage) activada con éxito! 🚀');
  } on Exception catch (e) {
    print('Error configurando Amplify: $e');
  }

  // --- NUEVO: Cargar preferencia de tema desde la memoria caché ---
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const MotoCareApp());
}

class MotoCareApp extends StatelessWidget {
  const MotoCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Moto Care',
          themeMode: currentMode,

          // --- PARA EL TEMA CLARO ---
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.lightBlue,
              foregroundColor: Colors.white,
            ),
          ),

          // --- TEMA OSCURO ---
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: const Color(
              0xFF121212,
            ), // Fondo gris muy oscuro
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F1F1F),
              foregroundColor: Colors.white,
            ),
            cardColor: const Color(
              0xFF1E1E1E,
            ), // Tarjetas ligeramente más claras.
            dialogBackgroundColor: const Color(0xFF2C2C2C),
          ),

          home: Authenticator(child: const Dashboard()),
        );
      },
    );
  }
}
