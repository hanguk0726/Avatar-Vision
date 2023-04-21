import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/widgets/tabItem.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../domain/event.dart';
import '../services/event_bus.dart';
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
  bool _isVisible = false;
  late StreamSubscription<Event> _eventSubscription;
  @override
  void initState() {
    super.initState();
    _eventSubscription = EventBus().onEvent.listen((event) {
      if (!_isVisible) {
        return;
      }
      switch (event) {
        case Event.keyboardControlArrowLeft:
          if (selectedIndex > 0) {
            setState(() {
              selectedIndex--;
              widget.onTabSelected(widget.buttonLabels[selectedIndex]);
            });
            return;
          }
          break;
        case Event.keyboardControlArrowRight:
          if (selectedIndex < widget.buttonLabels.length - 1) {
            setState(() {
              selectedIndex++;
              widget.onTabSelected(widget.buttonLabels[selectedIndex]);
            });
            return;
          }
          break;

        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
        key: const Key('tab'),
        onVisibilityChanged: (visibilityInfo) {
          if (mounted) {
            setState(() {
              _isVisible = visibilityInfo.visibleFraction > 0;
            });
          }
        },
        child: Container(
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
                          isActive: selectedIndex == entry.key,
                          onPressed: () {
                            setState(() {
                              selectedIndex = entry.key;
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
                            fontFamily: 'TitilliumWeb',
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
