import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_diary/domain/event.dart';

import '../domain/assets.dart';
import '../services/event_bus.dart';

Widget fileCommandWidget(List<int> timestamps) {
  Color borderColor = customSky;
  Color backgroundColor = customOcean;
  Color textColor = customSky;
  return FocusScope(
      canRequestFocus: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 550,
          maxHeight: 350,
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
                    borderRadius: BorderRadius.circular(0),
                  ),
                  constraints: const BoxConstraints(
                    minHeight: 520,
                  ),
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          ListTile(
                              title: Text(
                            "${timestamps.length} files selected.",
                            textAlign: TextAlign.start,
                            style: TextStyle(
                                color: textColor,
                                fontFamily: mainFont,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          )),
                          const SizedBox(height: 16),
                          Divider(
                            color: borderColor,
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              EventBus().fire(
                                  FileEvent(
                                      timestamps, FileEvent.sendFileToDesktop),
                                  'system');
                            },
                            child: const ListTile(
                              leading: Icon(
                                Icons.shortcut,
                                color: Colors.white,
                              ),
                              title: Text('Send to Desktop',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 32),
                          GestureDetector(
                              onTap: () {
                                EventBus().fire(
                                    FileEvent(timestamps, FileEvent.delete),
                                    'system');
                              },
                              child: const ListTile(
                                leading:
                                    Icon(Icons.delete, color: Colors.white),
                                title: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )),
                          const SizedBox(height: 32),
                          GestureDetector(
                              onTap: () {
                                EventBus().fire(
                                    const FileEvent([], FileEvent.cancel),
                                    'system');
                              },
                              child: const ListTile(
                                leading:
                                    Icon(Icons.cancel, color: Colors.white),
                                title: Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )),
                        ],
                      )))),
        ),
      ));
}
