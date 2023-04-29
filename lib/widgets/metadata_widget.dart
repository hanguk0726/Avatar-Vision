import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/services/db.dart';
import 'package:video_diary/services/event_bus.dart';
import 'package:video_diary/widgets/button.dart';

import '../domain/metadata.dart';
import '../tools/time.dart';

class MetadataWidget extends StatefulWidget {
  final Metadata metadata;

  const MetadataWidget({super.key, required this.metadata});

  @override
  MetadataWidgetState createState() => MetadataWidgetState();
}

class MetadataWidgetState extends State<MetadataWidget> {
  Color borderColor = customSky;
  Color backgroundColor = customOcean;
  Color textColor = customSky;
  late MetadataModel model;
  final isDirtySubject = BehaviorSubject<bool>.seeded(false);
  final inputFormatter =
      RegExp(r'^\d{0,4}[-]\d{0,2}[-]\d{0,2} \d{0,2}[:]\d{0,2}[:]\d{0,2}$');
  bool isTimestampFomatted = true; // User has to break the regex while editing

  Timer? _timer;
  final datatimeEditingController = TextEditingController();
  final noteEditingController = TextEditingController();

  Function onSubmitted = () {};
  @override
  void initState() {
    super.initState();

    model = MetadataModel(widget.metadata);
    onSubmitted = () {
      model.flush();
      isDirtySubject.add(false);
    };
    datatimeEditingController.text = getFormattedTimestamp(model.timestamp);
    noteEditingController.text = model.note ?? "";
  }

  void tick(String value) {
    _timer?.cancel();
    isTimestampFomatted = false;
    _timer = Timer(const Duration(milliseconds: 200), () {
      setState(() {
        isTimestampFomatted =
            inputFormatter.hasMatch(value);
            print("isTimestampFomatted $isTimestampFomatted value $value");
        if (isTimestampFomatted) {
          model.timestamp = toUtcTimestamp(value);
          isDirtySubject.add(model.isDirty);
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
        child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 550,
      ),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 170,
                              height: 32,
                              child: TextField(
                                controller: datatimeEditingController,
                                onChanged: (value) {
                                  tick(value);
                                },
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
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
                                    if (snapshot.data! && isTimestampFomatted) {
                                      return customButton(
                                          customSky, Colors.white, "Apply",
                                          () {
                                        model.flush();
                                        isDirtySubject.add(false);
                                      },
                                          height: 32.0,
                                          backgroundColorOpacity: 0.6,
                                          borderOpacity: 0.8,
                                          fontSize: 16.0);
                                    }
                                  }
                                  return const SizedBox();
                                }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          model.videoTitle,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontFamily: mainFont),
                        ),
                        Divider(
                          color: borderColor,
                        ),
                        TextField(
                            cursorColor: Colors.white,
                            controller: noteEditingController,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: mainFont,
                            ),
                            onChanged: (value) {
                              model.note = value;
                              isDirtySubject.add(model.isDirty);
                            },
                            onSubmitted: (value) {
                              onSubmitted();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Enter note here',
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

  late String videoTitle;

  late int timestamp;

  late String? note;

  late String? tags;

  late String? thumbnail;

  MetadataModel(this._data) {
    videoTitle = _data.videoTitle;
    timestamp = _data.timestamp;
    note = _data.note;
    tags = _data.tags;
    thumbnail = _data.thumbnail;
  }

  Metadata get original => _data;

  bool get isDirty {
    return _data.videoTitle != videoTitle ||
        _data.timestamp != timestamp ||
        _data.note != note ||
        _data.tags != tags ||
        _data.thumbnail != thumbnail;
  }

  void flush() {
    DatabaseService().updateMetadata(
        _data.videoTitle,
        Metadata(
            videoTitle: videoTitle,
            timestamp: timestamp,
            note: note,
            tags: tags,
            thumbnail: thumbnail));
  }
}
