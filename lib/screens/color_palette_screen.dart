import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPaletteScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Color currentColor = Colors.primaries.first; // Default color

    return Scaffold(
      appBar: AppBar(title: Text('Select Color')),
      body: Column(
        children: [
          Expanded(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (Color color) {
                currentColor = color;
              },
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  currentColor,
                ); // Return the selected color
              },
              child: Text('Select Color'),
            ),
          ),
        ],
      ),
    );
  }
}
