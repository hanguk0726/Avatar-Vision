import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/widgets/play.dart';

import '../services/native.dart';

class PastEntries extends StatefulWidget {
  final double width;
  final double height;

  const PastEntries({required this.width, required this.height});
  @override
  PastEntriesState createState() => PastEntriesState();
}

class PastEntriesState extends State<PastEntries> {
  int selectedIndex = 0;

  Color backgroundColor = customBlack;
  Color textColor = Colors.white;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Widget pastEntry(String file, bool selected) {
    if (selected) {
      return Text(file,
          style:
              TextStyle(color: textColor, fontFamily: mainFont, fontSize: 16));
    }
    return Text(
      file,
      style: TextStyle(color: textColor, fontFamily: mainFont, fontSize: 16),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void play() async {
    Native native = context.read<Native>();
    String fileName = native.files[selectedIndex];
    String filePath = "${native.filePathPrefix}/$fileName.mp4";
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Play(
                filePath: filePath,
                fileName: fileName,
                onPlay: () {},
              )),
    );
  }

  @override
  build(BuildContext context) {
    Native native = context.watch<Native>();
    List<String> files = native.files;
    return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                    decoration: BoxDecoration(
                      color: backgroundColor.withOpacity(0.2),
                    ),
                    child: Padding(
                        padding: const EdgeInsets.only(bottom: 16, top: 16),
                        child: RawKeyboardListener(
                            focusNode: _focusNode,
                            onKey: (event) {
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.enter) {
                                play();
                                return;
                              }

                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowUp) {
                                if (selectedIndex > 0) {
                                  setState(() {
                                    selectedIndex--;
                                  });
                                  return;
                                }
                              }
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowDown) {
                                if (selectedIndex < files.length - 1) {
                                  setState(() {
                                    selectedIndex++;
                                  });
                                  return;
                                }
                              }
                            },
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const ClampingScrollPhysics(),
                              itemCount: files.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedIndex = index;
                                      });
                                    },
                                    onDoubleTap: () {
                                      setState(() {
                                        selectedIndex = index;
                                      });
                                      play();
                                    },
                                    child: Container(
                                        color: selectedIndex == index
                                            ? customSky.withOpacity(0.3)
                                            : Colors.transparent,
                                        child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 32,
                                              right: 32,
                                            ),
                                            child: pastEntry(files[index],
                                                selectedIndex == index))));
                              },
                            )))))));
  }
}
