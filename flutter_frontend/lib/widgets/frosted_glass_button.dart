import 'dart:ui';
import 'package:flutter/material.dart';
import '../themes/colors.dart';

class FrostedGlassButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final Color? backgroundColor;

  const FrostedGlassButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.backgroundColor,
  });

  @override
  State<FrostedGlassButton> createState() => _FrostedGlassButtonState();
}

class _FrostedGlassButtonState extends State<FrostedGlassButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: _getBackgroundColor(isDisabled),
                border: Border.all(
                  color: _getBorderColor(),
                  width: widget.isPrimary ? 1 : 2,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _getShadowColor(),
                    blurRadius: _isHovered ? 12 : 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Boska',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _getTextColor(isDisabled),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isDisabled) {
    if (isDisabled) {
      return Color.fromARGB(102, 107, 114, 128);
    }

    // Use custom background color if provided
    if (widget.backgroundColor != null) {
      return widget.backgroundColor!.withOpacity(0.8);
    }

    if (widget.isPrimary) {
      return Color.fromARGB(230, 6, 78, 59);
    } else {
      return Color.fromARGB(26, 255, 255, 255);
    }
  }

  Color _getBorderColor() {
    // If custom background color is provided, use a lighter shade of it for border
    if (widget.backgroundColor != null) {
      return widget.backgroundColor!.withOpacity(0.4);
    }

    if (widget.isPrimary) {
      return Color.fromARGB(51, 255, 255, 255);
    } else {
      return Color.fromARGB(128, 6, 78, 59);
    }
  }

  Color _getShadowColor() {
    // If custom background color is provided, use it for shadow
    if (widget.backgroundColor != null) {
      return widget.backgroundColor!.withOpacity(0.3);
    }

    if (widget.isPrimary) {
      return Color.fromARGB(26, 6, 78, 59);
    } else {
      return Color.fromARGB(13, 255, 255, 255);
    }
  }

  Color _getTextColor(bool isDisabled) {
    if (isDisabled) return Colors.grey;
    return widget.isPrimary ? kBgWhite : kPrimary;
  }
}
