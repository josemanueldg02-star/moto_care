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

import 'models/ModelProvider.dart';
import 'widgets/dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

    print('¡Conexión a AWS (API, Auth y Storage) activada con éxito! 🚀');
  } on Exception catch (e) {
    print('Error configurando Amplify: $e');
  }

  runApp(const MotoCareApp());
}

class MotoCareApp extends StatelessWidget {
  const MotoCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 4. El Authenticator actúa como un guardián. Envuelve toda la aplicación.
    return Authenticator(
      child: MaterialApp(
        // builder: Authenticator.builder() es la magia. Si el usuario no está logueado,
        // secuestra la pantalla y le muestra el Login. Si está logueado, le deja pasar.
        builder: Authenticator.builder(),
        title: 'Moto Care',
        theme: ThemeData(primarySwatch: Colors.green),
        home: const Dashboard(),
      ),
    );
  }
}
