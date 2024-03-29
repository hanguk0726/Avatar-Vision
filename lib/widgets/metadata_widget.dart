import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/services/database.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/widgets/button.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/metadata.dart';
import '../tools/time.dart';

class MetadataWidget extends StatefulWidget {
  final Metadata metadata;
  final bool smaller;
  final Function? onEdited;
  final Function? onSubmmited;

  MetadataWidget({
    required this.metadata,
    this.smaller = false,
    this.onEdited,
    this.onSubmmited,
  }) : super(key: ValueKey(metadata));

  @override
  MetadataWidgetState createState() => MetadataWidgetState();
}

class MetadataWidgetState extends State<MetadataWidget> with WindowListener {
  Color borderColor = customSky;
  Color backgroundColor = customOcean;
  Color textColor = customSky;
  late MetadataModel model;
  final isDirtySubject = BehaviorSubject<bool>.seeded(false);
  double? screenHeight;
  int maxLines = 12;
  Timer? _timer;
  final titleEditingController = TextEditingController();
  final datatimeEditingController = TextEditingController();
  final noteEditingController = TextEditingController();
  final titleFocusNode = FocusNode();
  final noteFocusNode = FocusNode();
  final _native = Native();
  Function onSubmitted = () {};

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    if (widget.smaller) {
      maxLines = 9;
    }
    model = MetadataModel(widget.metadata);
    onSubmitted = () {
      model.flush();
      isDirtySubject.add(false);
      widget.onSubmmited?.call();
    };
    titleEditingController.text = model.title;
    datatimeEditingController.text =
        formatTimestamp(timestamp: model.timestamp);
    noteEditingController.text = model.note ?? "";
    titleFocusNode.addListener(() {
      if (titleFocusNode.hasFocus) {
        widget.onEdited?.call();
      }
    });
    noteFocusNode.addListener(() {
      if (noteFocusNode.hasFocus) {
        widget.onEdited?.call();
      }
    });
  }

  @override
  void onWindowResize() async {
    await setWindowSize();
  }

  Future<void> setWindowSize() async {
    var size = await windowManager.getSize();
    setState(() {
      final currentResolutionHeight = _native.currentResolutionHeight;
      // The texture widget can't be bigger than the resolution.
      screenHeight = min(currentResolutionHeight, size.height);
      final defaultLines = widget.smaller ? 9 : 12;
      maxLines = defaultLines + ((screenHeight! - 720) ~/ 26);
    });
  }

  @override
  void dispose() {
    super.dispose();
    windowManager.removeListener(this);
    _timer?.cancel();
    titleEditingController.dispose();
    datatimeEditingController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
        child: ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: 550,
          maxHeight: (screenHeight ?? 720) - (widget.smaller ? 300 : 200)),
      child: ClipRRect(
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.8),
                  border: Border.all(
                    color: borderColor.withOpacity(0.8),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(0),
                ),
                constraints: const BoxConstraints(
                  minHeight: 520,
                ),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SizedBox(
                          height: 32,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TextField(
                                  readOnly: true,
                                  controller: datatimeEditingController,
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 18,
                                      fontFamily: mainFont),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              StreamBuilder<bool>(
                                  stream: isDirtySubject.stream,
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      if (snapshot.data!) {
                                        return customButton(
                                            customSky, Colors.white, "Apply",
                                            () {
                                          model.flush();
                                          isDirtySubject.add(false);
                                          widget.onSubmmited?.call();
                                        },
                                            height: 32.0,
                                            backgroundColorOpacity: 0.6,
                                            borderOpacity: 0.8,
                                            fontSize: 18.0);
                                      }
                                    }
                                    return const SizedBox();
                                  }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                            focusNode: titleFocusNode,
                            controller: titleEditingController,
                            cursorColor: Colors.white,
                            onChanged: (value) {
                              model.title = value;
                              isDirtySubject.add(model.isDirty);
                              widget.onEdited?.call();
                            },
                            onSubmitted: (value) {
                              onSubmitted();
                            },
                            style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontFamily: mainFont),
                            decoration: InputDecoration(
                              hintText: 'Empty title',
                              hintStyle: TextStyle(
                                color: Colors.white54,
                                fontFamily: mainFont,
                              ),
                              border: InputBorder.none,
                            )),
                        Divider(
                          color: borderColor,
                        ),
                        TextField(
                            focusNode: noteFocusNode,
                            cursorColor: Colors.white,
                            controller: noteEditingController,
                            maxLines: maxLines,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: mainFont,
                              fontSize: 18,
                            ),
                            onChanged: (value) {
                              model.note = value;
                              isDirtySubject.add(model.isDirty);
                              widget.onEdited?.call();
                            },
                            onSubmitted: (value) {
                              onSubmitted();
                            },
                            decoration: InputDecoration(
                              hintText: 'Empty note',
                              hintStyle: TextStyle(
                                color: Colors.white54,
                                fontFamily: mainFont,
                              ),
                              border: InputBorder.none,
                            )),
                      ],
                    )))),
      ),
    ));
  }
}

class MetadataModel {
  late final Metadata _data;

  late String title;

  late final int timestamp;

  late String? note;

  late String? tags;

  late String? thumbnail;

  MetadataModel(this._data) {
    title = _data.title;
    timestamp = _data.timestamp;
    note = _data.note;
    tags = _data.tags;
    thumbnail = _data.thumbnail;
  }

  Metadata get original => _data;

  bool get isDirty {
    return _data.title != title ||
        _data.note != note ||
        _data.tags != tags ||
        _data.thumbnail != thumbnail;
  }

  void flush() {
    DatabaseService().update(
        _data.timestamp,
        Metadata(
            title: title,
            timestamp: timestamp,
            note: note,
            tags: tags,
            thumbnail: thumbnail));
  }
}
