import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:omni_bar/providers/theme_provider.dart';
import 'package:omni_bar/tools/omni_tools.dart';
import 'package:provider/provider.dart';

class ColorPickerTool extends OmniTool {
  static const _channel = MethodChannel('pixel_color');

  Future<Color?> _retrieveColorAtCursor(String input) async {
    try {
      final int color = await _channel.invokeMethod('getPixelColor');
    return Color(color);
    } catch (_) {
      return null;
    }
  }

  // TODO: Another "triggering" mechanism is needed for this. the color only gets picked when text gets updated
  // TODO: The omnibar should also probably get invisible when getting near it, as it hast a "shimmer" arround it that strongly alters color picking when getting to close
  @override
  Widget buildDisplay(BuildContext context, String input) {
    // TODO: Doing it this way is bad but i was to lazy to make it pretty (the async kinda fucks with the gui and makes it flash, because it has to wait for the swift part to answer)
    // Fix should probably be something like: Providing the elements and then just updating them as we get the values
    // -> Maybe even do a content ini and a relod function in the abstrct?
    return FutureBuilder<Color?>(
      future: _retrieveColorAtCursor(input),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Text("Invalid color");
        }

        final color = snapshot.data!;
        final hsl = HSLColor.fromColor(color);

        int formatToRGB(double value) => (value * 255).round().clamp(0, 255);
        final rgbStr =
            'RGB(${formatToRGB(color.red / 255)}, ${formatToRGB(color.green / 255)}, ${formatToRGB(color.blue / 255)})';
        final hslStr =
            'HSL(${hsl.hue.toStringAsFixed(0)}°, ${(hsl.saturation * 100).toStringAsFixed(0)}%, ${(hsl.lightness * 100).toStringAsFixed(0)}%)';
        final hexStr =
            '#${color.value.toRadixString(16).substring(2).toUpperCase()}';

        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            bool isDark = themeProvider.themeMode == ThemeMode.system
                ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
                : themeProvider.themeMode == ThemeMode.dark;

            final backgroundColor = isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.7);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildValueRow("HEX", hexStr),
                        const SizedBox(height: 4),
                        _buildValueRow("RGB", rgbStr),
                        const SizedBox(height: 4),
                        _buildValueRow("HSL", hslStr),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildValueRow(String label, String value) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        SelectableText(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Menlo',
          ),
        ),
      ],
    );
  }

  @override
  String get helperText => "left click somewhere on the screen";

  @override
  String get name => "Color Picker";

  @override
  SearchSuggestion get wakeCommands => SearchSuggestion(
    ['pick'],
    'pick a color on the screen',
    Icons.data_object,
  );
}
