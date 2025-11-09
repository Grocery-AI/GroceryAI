import 'dart:ui';
import 'package:flutter/material.dart';
import '../themes/colors.dart';

class FrostedGlassTextField extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const FrostedGlassTextField({
    required this.controller,
    required this.placeholder,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<FrostedGlassTextField> createState() => _FrostedGlassTextFieldState();
}

class _FrostedGlassTextFieldState extends State<FrostedGlassTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _focusNode.hasFocus ? 10 : 8,
          sigmaY: _focusNode.hasFocus ? 10 : 8,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _focusNode.hasFocus
                ? Color.fromARGB(242, 255, 255, 255)
                : Color.fromARGB(204, 255, 255, 255),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? Color.fromARGB(204, 6, 78, 59)
                  : Color.fromARGB(128, 229, 231, 235),
              width: _focusNode.hasFocus ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (_focusNode.hasFocus)
                BoxShadow(
                  color: Color.fromARGB(26, 6, 78, 59),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              BoxShadow(
                color: Color.fromARGB(10, 0, 0, 0),
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            style: TextStyle(
              fontSize: 14,
              color: kTextDark,
              fontFamily: 'StackSansText',
            ),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Color.fromARGB(153, 155, 163, 175),
                fontFamily: 'StackSansText',
              ),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}
