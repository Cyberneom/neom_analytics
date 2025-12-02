import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';

class StatisticBox extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;
  final String bottomText;
  final bool isLoading;
  final VoidCallback? onTap;

  const StatisticBox({
    super.key,
    required this.title,
    required this.value,
    this.color,
    this.bottomText = '',
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded( // Usamos Expanded para que ocupen el espacio disponible horizontalmente
      child: Card(
        color: color, // Color de fondo del cuadro
        elevation: 4.0, // Sombra
        shape: RoundedRectangleBorder( // Bordes redondeados
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Centrar contenido verticalmente
              crossAxisAlignment: CrossAxisAlignment.center, // Centrar contenido horizontalmente
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70, // Color del texto del título
                  ),
                ),
                AppTheme.heightSpace10,
                !isLoading ? Text(value,
                  style: const TextStyle(
                    fontSize: 24, // Tamaño grande para el número
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // Color del texto del valor
                  ),
                ) : CircularProgressIndicator(),
                if(bottomText.isNotEmpty) Column(
                  children: [
                    const SizedBox(height: 8.0), // Espacio entre título y valor
                    Text(
                      bottomText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70, // Color del texto del título
                      ),
                    ),

                ],),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
