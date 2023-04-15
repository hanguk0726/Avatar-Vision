import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/widgets/tabItem.dart';

import '../tools/custom_button_clipper.dart';

class Tabs extends StatefulWidget {
  final List<TabItem> buttonLabels;
  final Function(TabItem) onTabSelected;

  const Tabs({
    Key? key,
    required this.buttonLabels,
    required this.onTabSelected,
  }) : super(key: key);

  @override
  TabsState createState() => TabsState();
}

class TabsState extends State<Tabs> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: customSky, width: 2.0),
        borderRadius: const BorderRadius.all(
          Radius.circular(10.0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: FittedBox(
          child: Row(
            children: widget.buttonLabels
                .asMap()
                .entries
                .map(
                  (entry) => ToggleButton(
                    text: entry.value.name,
                    isActive: _selectedIndex == entry.key,
                    onPressed: () {
                      setState(() {
                        _selectedIndex = entry.key;
                        widget.onTabSelected(entry.value);
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class ToggleButton extends StatefulWidget {
  final String text;
  final bool isActive;
  final VoidCallback onPressed;
  final hoverEffect = false;

  const ToggleButton({
    super.key,
    required this.text,
    required this.isActive,
    required this.onPressed,
  });

  @override
  ToggleButtonState createState() => ToggleButtonState();
}

class ToggleButtonState extends State<ToggleButton> {
  bool isHovering = false;
  late double width;
  late Function(PointerHoverEvent) onHover;
  late Function(PointerExitEvent) onHoverExit;
  @override
  void initState() {
    super.initState();
    double width_ = widget.text.length * 11;
    width = width_ > 100 ? width_ : 100;

    if (widget.hoverEffect) {
      onHover = (PointerHoverEvent event) {
        setState(() {
          isHovering = true;
        });
      };
      onHoverExit = (PointerExitEvent event) {
        setState(() {
          isHovering = false;
        });
      };
    } else {
      onHover = (PointerHoverEvent event) {};
      onHoverExit = (PointerExitEvent event) {};
    }
  }

  Color buttonColor() {
    if (widget.isActive) {
      return customSky;
    } else if (isHovering) {
      return customOrange;
    } else {
      return customOcean;
    }
  }

  Color textColor() {
    return buttonColor() == customSky ? customNavy : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: onHover,
      onExit: onHoverExit,
      child: SizedBox(
          height: 25,
          width: width,
          child: ClipPath(
            clipper: CustomButtonClipper(),
            child: Container(
              decoration: BoxDecoration(
                color: buttonColor(),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6.0),
                ),
              ),
              child: TextButton(
                onPressed: widget.onPressed,
                style: const ButtonStyle(
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  widget.text,
                  style: TextStyle(
                      fontFamily: 'TitilliumWeb',
                      fontWeight: FontWeight.w600,
                      color: textColor(),
                      fontSize: 13),
                ),
              ),
            ),
          )),
    );
  }
}
