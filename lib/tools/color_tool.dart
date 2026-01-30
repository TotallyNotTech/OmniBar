import 'package:flutter/material.dart';
import 'package:omni_bar/providers/theme_provider.dart';
import 'package:omni_bar/tools/omni_tools.dart';
import 'package:provider/provider.dart';

class ColorTool extends OmniTool {
  @override
  String get name => "Color Tool";

  @override
  get helperText => "Enter HEX color value...";

  // Regex to match Hex: #RRGGBB, RRGGBB, #RGB, or RGB
  final RegExp _hexRegex = RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

  @override
  bool canHandle(String input) {
    return _hexRegex.hasMatch(input.trim());
  }

  @override
  get wakeCommands => SearchSuggestion(
    ['color'],
    'Color Converter (Hex/RGB)',
    Icons.color_lens,
  );

  Color? _parseColor(String input) {
    String hex = input.trim().replaceAll('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget buildDisplay(BuildContext context, String input) {
    final color = _parseColor(input);
    if (color == null) return const SizedBox.shrink();

    final hsl = HSLColor.fromColor(color);

    int formatToRGB(double value) {
      int formattedValue;
      formattedValue = (value * 255).round().clamp(0, 255);
      return formattedValue;
    }

    // Formatting strings
    final rgbStr =
        'RGB(${formatToRGB(color.r)}, ${formatToRGB(color.g)}, ${formatToRGB(color.b)})';
    final hslStr =
        'HSL(${hsl.hue.toStringAsFixed(0)}°, ${(hsl.saturation * 100).toStringAsFixed(0)}%, ${(hsl.lightness * 100).toStringAsFixed(0)}%)';
    final hexStr =
        '#${color.value.toRadixString(16).substring(2).toUpperCase()}';

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        bool isDark;
        if (themeProvider.themeMode == ThemeMode.system) {
          isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        } else {
          isDark = themeProvider.themeMode == ThemeMode.dark;
        }

        final backgroundColor = isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.black.withOpacity(0.7);

        return Container(
          width: double.infinity,
          // This outer padding is fine, keep it.
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),

          child: Row(
            children: [
              // 1. Color Preview Box
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // 2. Color Values
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
  String? getCopyableData(String input) {
    final color = _parseColor(input);
    return color != null
        ? '#${color.value.toRadixString(16).substring(2).toUpperCase()}'
        : null;
  }
}
