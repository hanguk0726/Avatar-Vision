import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/widgets/past_entries.dart';
import 'package:video_diary/widgets/setting_widget.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/assets.dart';

class TabItemWidget extends StatefulWidget {
  final BehaviorSubject<TabItem> tabItem;

  const TabItemWidget({
    Key? key,
    required this.tabItem,
  }) : super(key: key);

  @override
  TabItemWidgetState createState() => TabItemWidgetState();
}

class TabItemWidgetState extends State<TabItemWidget> {
  double windowPadding = 32.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final halfWidth = constraints.maxWidth / 2;
      final width =
          (halfWidth - (2 * windowPadding)).clamp(0.0, constraints.maxWidth);
      final height = ((constraints.maxHeight - 100) - (2 * windowPadding))
          .clamp(0.0, constraints.maxHeight);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: height,
        ),
        child: StreamBuilder<TabItem>(
          stream: widget.tabItem,
          initialData: TabItem.mainCam,
          builder: (context, snapshot) {
            final tabItem = snapshot.data;
            return Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildTabItem(tabItem, context));
          },
        ),
      );
    });
  }
}

Widget _buildTabItem(
  TabItem? tabItem,
  BuildContext context,
) {
  switch (tabItem) {
    case TabItem.mainCam:
      return _mainCam();
    case TabItem.pastEntries:
      return const PastEntries();
    case TabItem.settings:
      return settings(context);
    default:
      return _mainCam();
  }
}

Widget _mainCam() {
  return const SizedBox();
}

Widget recordingIndicator() {
  Color customRed = const Color.fromARGB(255, 255, 56, 63);
  return FittedBox(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          "REC",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: mainFont,
              fontSize: 24),
        ),
        const SizedBox(width: 8),
        ClipOval(
          child: ColorFiltered(
            colorFilter:
                ColorFilter.mode(customRed.withOpacity(0.8), BlendMode.lighten),
            child: Container(
                width: 24, height: 24, color: customRed.withOpacity(0.5)),
          ),
        )
      ],
    ),
  );
}

enum TabItem {
  mainCam('MAIN CAM'),
  pastEntries('PAST ENTRIES'),
  submit('SUBMIT'),
  settings('SETTINGS');

  final String name;

  const TabItem(this.name);
}
