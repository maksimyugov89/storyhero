import 'package:flutter/material.dart';
import '../../../core/utils/text_style_helpers.dart';

class MagicText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Gradient? gradient;
  final double? fontSize;
  final FontWeight? fontWeight;

  const MagicText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.gradient,
    this.fontSize,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultGradient = LinearGradient(
      colors: [
        Theme.of(context).colorScheme.primary,
        Theme.of(context).colorScheme.secondary,
      ],
    );

    if (gradient != null || style == null) {
      return ShaderMask(
        shaderCallback: (bounds) =>
            (gradient ?? defaultGradient).createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        ),
        child: Text(
          text,
          style: safeCopyWith(style, 
            fontSize: fontSize,
            defaultFontSize: 16,
            fontWeight: fontWeight,
            color: Colors.white,
          ),
          textAlign: textAlign,
        ),
      );
    }

    return Text(
      text,
      style: safeCopyWith(style,
        fontSize: fontSize,
        defaultFontSize: 16,
        fontWeight: fontWeight,
      ),
      textAlign: textAlign,
    );
  }
}

