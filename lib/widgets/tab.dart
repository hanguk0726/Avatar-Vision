import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/widgets/key_listener.dart';

import '../domain/event.dart';
import '../domain/tab_item.dart';
import '../services/event_bus.dart';
import '../services/runtime_data.dart';
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
  int selectedIndex = 0;
  late StreamSubscription<KeyEventPair> _eventSubscription;
  final String eventKey = 'tab';
  final String allowedEventKey = 'pastEntries';
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    selectedIndex = RuntimeData().tabIndex;

    _eventSubscription = EventBus().onEvent.listen((event) {
      if (event.key != eventKey && event.key != allowedEventKey) {
        return;
      }
      switch (event.event) {
        case KeyboardEvent.keyboardControlArrowLeft:
          if (selectedIndex > 0) {
            setState(() {
              selectedIndex = selectedIndex - 1;
              RuntimeData().tabIndex = selectedIndex;
              widget.onTabSelected(widget.buttonLabels[selectedIndex]);
            });
            return;
          }
          break;
        case KeyboardEvent.keyboardControlArrowRight:
          if (selectedIndex < widget.buttonLabels.length - 1) {
            setState(() {
              selectedIndex = selectedIndex + 1;
              RuntimeData().tabIndex = selectedIndex;
              widget.onTabSelected(widget.buttonLabels[selectedIndex]);
            });
            return;
          }
          break;

        default:
          break;
      }
    });
    focusNode.requestFocus();
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    focusNode.dispose();
    super.dispose();
  }

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
            child: keyListener(
              eventKey,
              focusNode,
              Row(
                  children: widget.buttonLabels
                      .asMap()
                      .entries
                      .map(
                        (entry) => ToggleButton(
                          text: entry.value.name,
                          isActive: selectedIndex == entry.key,
                          onPressed: () {
                            setState(() {
                              selectedIndex = entry.key;
                              RuntimeData().tabIndex = selectedIndex;
                              widget.onTabSelected(entry.value);
                            });
                          },
                        ),
                      )
                      .toList()),
            ),
          ),
        ));
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
    return buttonColor() == customSky ? customBlack : Colors.white;
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
              child: GestureDetector(
                  onTap: widget.onPressed,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        widget.text,
                        style: TextStyle(
                            fontFamily: mainFont,
                            fontWeight: FontWeight.w600,
                            color: textColor(),
                            fontSize: 13),
                      ),
                    ),
                  )),
            ),
          )),
    );
  }
}
