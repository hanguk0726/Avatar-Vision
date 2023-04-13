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

class ToggleButton extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback onPressed;

  const ToggleButton({
    super.key,
    required this.text,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    Color buttonColor = isActive ? customSky : customOcean;
    Color textColor = buttonColor == customSky ? customNavy : Colors.white;
    double width_ = text.length * 11;
    double width = width_ > 100 ? width_ : 100;
    return SizedBox(
      height: 25,
      width: width,
      child: ClipPath(
        clipper: CustomButtonClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6.0),
            ),
          ),
          child: TextButton(
            onPressed: onPressed,
            style: const ButtonStyle(
              alignment: Alignment.centerLeft,
            ),
            child: Text(
              text,
              style: TextStyle(
                  fontFamily: 'TitilliumWeb',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
