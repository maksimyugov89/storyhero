import 'package:flutter/material.dart';
import '../../core/theme/app_theme_magic.dart';
import 'asset_icon.dart';

/// Магический input-поле с анимированным placeholder и светящейся рамкой
class AnimatedMagicInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final String? prefixIconAsset;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  const AnimatedMagicInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.prefixIconAsset,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
  });

  @override
  State<AnimatedMagicInput> createState() => _AnimatedMagicInputState();
}

class _AnimatedMagicInputState extends State<AnimatedMagicInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _labelAnimation;
  late Animation<double> _glowAnimation;
  late Animation<Color?> _borderColorAnimation;
  
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _labelAnimation = Tween<double>(begin: 1.0, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    final primaryColor = AppThemeMagic.primaryColor;
    _borderColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: primaryColor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _focusNode.addListener(_onFocusChange);
    widget.controller?.addListener(_onTextChange);
    
    // Проверяем начальное состояние
    _hasText = widget.controller?.text.isNotEmpty ?? false;
    if (_hasText || _focusNode.hasFocus) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    widget.controller?.removeListener(_onTextChange);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    
    if (_isFocused || _hasText) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _onTextChange() {
    final hasText = widget.controller?.text.isNotEmpty ?? false;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
      
      if (_hasText || _isFocused) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  void _validate() {
    if (widget.validator != null && widget.controller != null) {
      final error = widget.validator!(widget.controller!.text);
      setState(() {
        _errorText = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final labelScale = _labelAnimation.value;
            final glowValue = _glowAnimation.value;
            final borderColor = _borderColorAnimation.value ?? Colors.transparent;

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _isFocused
                    ? LinearGradient(
                        colors: [
                          AppThemeMagic.primaryColor.withOpacity(0.1),
                          AppThemeMagic.secondaryColor.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: !_isFocused
                    ? (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white.withOpacity(0.8))
                    : null,
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3 * glowValue),
                          blurRadius: 12 * glowValue,
                          spreadRadius: 1 * glowValue,
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                maxLines: widget.maxLines,
                enabled: widget.enabled,
                onChanged: (value) {
                  widget.onChanged?.call(value);
                  _onTextChange();
                  _validate();
                },
                onSubmitted: (_) => _validate(),
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent, // Прозрачный, т.к. градиент в Container
                  hintText: _isFocused || _hasText ? null : widget.hint,
                  hintStyle: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                  ),
                  labelStyle: TextStyle(
                    color: _isFocused ? primaryColor : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: widget.prefixIcon != null || widget.prefixIconAsset != null
                      ? widget.prefixIconAsset != null
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: AssetIcon(
                                assetPath: widget.prefixIconAsset!,
                                size: 20,
                                color: _isFocused
                                    ? primaryColor
                                    : Colors.black54,
                              ),
                            )
                          : Icon(
                              widget.prefixIcon,
                              color: _isFocused
                                  ? primaryColor
                                  : Colors.black54,
                            )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _errorText != null
                          ? errorColor
                          : Colors.black26,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: _errorText != null ? errorColor : borderColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: errorColor,
                      width: 2,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: errorColor,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            );
          },
        ),
        // Анимированный label
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
            child: AnimatedBuilder(
              animation: _labelAnimation,
              builder: (context, child) {
                final scale = _labelAnimation.value;
                final isFloating = _isFocused || _hasText;
                final primaryColor = Theme.of(context).colorScheme.primary;
                
                return Transform.translate(
                  offset: Offset(0, isFloating ? -8 : 0),
                  child: Transform.scale(
                    scale: scale,
                    origin: const Offset(0, 0),
                    child: Text(
                      widget.label!,
                      style: TextStyle(
                        fontSize: isFloating ? 12 : 16,
                        fontWeight: isFloating ? FontWeight.w600 : FontWeight.w500,
                        color: _isFocused
                            ? primaryColor
                            : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        // Анимация отображения ошибок
        if (_errorText != null)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -10 * (1 - value)),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

