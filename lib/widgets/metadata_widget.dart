import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/services/event_bus.dart';

import '../domain/metadata.dart';

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
  @override
  void initState() {
    super.initState();
    model = MetadataModel(widget.metadata);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return  FocusScope(child: ConstrainedBox(
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
                          Text(
                            model.videoTitle,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: mainFont),
                          ),
                          Divider(
                            color: borderColor,
                          ),
                          TextField(
                            controller: TextEditingController(text: model.note),
                            onChanged: (value) {
                              model.note = value;
                            },
                          ),
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
}
