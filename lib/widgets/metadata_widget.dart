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

  MetadataWidget({required this.metadata}) : super(key: ValueKey(metadata));

  @override
  MetadataWidgetState createState() => MetadataWidgetState();
}

class MetadataWidgetState extends State<MetadataWidget> {
  Color borderColor = customSky;
  Color backgroundColor = customOcean;
  Color textColor = customSky;
  late MetadataModel model;
  final isDirtySubject = BehaviorSubject<bool>.seeded(false);

  Timer? _timer;
  final titleEditingController = TextEditingController();
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
    titleEditingController.text = model.title;
    datatimeEditingController.text =
        getFormattedTimestamp(timestamp: model.timestamp);
    noteEditingController.text = model.note ?? "";
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
                        SizedBox(
                          height: 32,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 170,
                                height: 20,
                                child: TextField(
                                  readOnly: true,
                                  controller: datatimeEditingController,
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
                                      if (snapshot.data!) {
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
                        ),
                        const SizedBox(height: 16),
                        TextField(
                            controller: titleEditingController,
                            cursorColor: Colors.white,
                            onChanged: (value) {
                              model.title = value;
                              isDirtySubject.add(model.isDirty);
                            },
                            onSubmitted: (value) {
                              onSubmitted();
                            },
                            style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontFamily: mainFont),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            )),
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

  late int timestamp;

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
        _data.title,
        Metadata(
            title: title,
            timestamp: timestamp,
            note: note,
            tags: tags,
            thumbnail: thumbnail));
  }
}
