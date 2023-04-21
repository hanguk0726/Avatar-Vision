import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/widgets/past_entries.dart';
import 'package:video_diary/widgets/setting_widget.dart';

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

class TabItemWidgetState extends State<TabItemWidget>
    with WidgetsBindingObserver {
  late Size _windowSize;
  double tabItemWidetWidth = 500.0;
  double tabItemWidetHeight = 500.0;
  double windowPadding = 32.0;
  void setWindowSize() {
    setState(() {
      _windowSize = WidgetsBinding.instance.window.physicalSize /
          WidgetsBinding.instance.window.devicePixelRatio;
    });
    tabItemWidetHeight = _windowSize.height - 100.0;
    //if tabItemWidetWidth or height bigger than window size, set to window size
    if (_windowSize.width < tabItemWidetWidth) {
      tabItemWidetWidth = (_windowSize.width - (2 * windowPadding));
    }
    if (_windowSize.height < tabItemWidetHeight) {
      tabItemWidetHeight = (_windowSize.height - (2 * windowPadding));
    }
    debugPrint('window size: $_windowSize');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setWindowSize();
  }

  @override
  void didChangeMetrics() {
    setWindowSize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TabItem>(
      stream: widget.tabItem,
      initialData: TabItem.mainCam,
      builder: (context, snapshot) {
        final tabItem = snapshot.data;
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildTabItem(
              tabItem, context, tabItemWidetWidth, tabItemWidetHeight),
        );
      },
    );
  }
}

Widget _buildTabItem(
    TabItem? tabItem, BuildContext context, double tabItemWidetWidth, double tabItemWidetHeight) {
  switch (tabItem) {
    case TabItem.mainCam:
      return _mainCam();
    case TabItem.pastEntries:
      return PastEntries(
        width: tabItemWidetWidth,
        height: tabItemWidetHeight,
      );
    case TabItem.settings:
      return settings(context, tabItemWidetWidth);
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
