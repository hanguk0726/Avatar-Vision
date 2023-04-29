import 'package:flutter/material.dart';

class HoverButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color backgroundColorOnHover;

  final Color textColor;
  final Color textColorOnHover;
  const HoverButton(
      {super.key,
      required this.text,
      required this.onPressed,
      required this.backgroundColor,
      required this.backgroundColorOnHover,
      required this.textColor,
      required this.textColorOnHover});

  @override
  HoverButtonState createState() => HoverButtonState();
}

class HoverButtonState extends State<HoverButton> {
  late Color _backgroundColor;
  late Color _textColor;

  @override
  void initState() {
    super.initState();
    _backgroundColor = widget.backgroundColor;
    _textColor = widget.textColor;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onPressed,
      onHover: (isHovering) {
        setState(() {
          _backgroundColor = isHovering
              ? widget.backgroundColorOnHover
              : widget.backgroundColor;
          _textColor = isHovering ? widget.textColorOnHover : widget.textColor;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds:300),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: _backgroundColor,
        ),
        child: Text(
          widget.text,
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
