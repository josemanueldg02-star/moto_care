// lib/services/weather_service.dart

import 'dart:convert'; // Para traducir el texto de internet (JSON) a objetos de Dart
import 'package:http/http.dart' as http; // Nuestra herramienta para hacer llamadas a la red.

class WeatherService {
    // Coordenadas aproximadas de Sevilla Este (Latitud y Longitud)
    // Usamos Open-Meteo porque es gratuito y no pide API Key.
    final String _url = 'https://api.open-meteo.com/v1/forecast?latitude=37.38&longitude=-5.93&current_weather=true';

    // Función asíncrona (Future) porque ir a internet lleva tiempo y la app no debe quedarse congelada.
    Future<Map<String, dynamic>?> getCurrentWeather() async {
        try {
            // 1. Hacemos la llamada (petición GET) a la URL.
            final response = await http.get(Uri.parse(_url));

            // 2. Comprobamos si el servidor nos ha respondido con éxito (Código 200 significa "OK")
            if (response.statusCode == 200) {
                // 3. Traducimos el texto plano que nos llega a un formato JSON estructurado.
                final decodedData = json.decode(response.body);

                // 4. De todo el batiburrillo de datos, extraemos solo la sección "current_weather"
                return decodedData['current_weather'];
            } else {
                // Si el código no es 200 (ej: 404, 500), mostramos un error en consola.
                print('Error del servidor meteorológico: ${response.statusCode}');
                return null;
            }
        } catch (e) {
            // Si no hay internet o el móvil está en modo avión, saltará este error.
            print('Error de conexión a internet: $e');
            return null;
        }
    }
}