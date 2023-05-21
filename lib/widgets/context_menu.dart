import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/domain/event.dart';

import '../services/event_bus.dart';
import '../services/native.dart';

Widget contextMenu(int timestmap, String eventKey) {
  var eventBus = EventBus();
  var native = Native();
  return Builder(builder: (context) {
    return IconButton(
      onPressed: () {
        final RenderBox button = context.findRenderObject() as RenderBox;
        final RenderBox overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(
            button.localToGlobal(Offset.zero, ancestor: overlay),
            button.localToGlobal(button.size.bottomRight(Offset.zero),
                ancestor: overlay),
          ),
          Offset.zero & overlay.size,
        );
        showMenu(
          context: context,
          position: position.shift(const Offset(0, 36)),
          color: customOcean,
          items: [
            PopupMenuItem(
              child: const ListTile(
                leading: Icon(
                  Icons.shortcut,
                  color: Colors.white,
                ),
                title: Text('Send to Desktop', style : TextStyle(color: Colors.white)),
              ),
              onTap: () {
                eventBus.fire(
                    DialogEvent(
                      text: 'Sending to Desktop',
                      eventKey: eventKey,
                      automaticTask: () => native.sendFileToDesktop(timestmap),
                    ),
                    eventKey);
              },
            ),
            PopupMenuItem(
              child: const ListTile(
                leading: Icon(Icons.delete, color: Colors.white),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              onTap: () {
                eventBus.fire(
                    DialogEvent(
                      text: 'Proceed to delete?',
                      eventKey: eventKey,
                      buttonSky: 'Yes',
                      buttonSkyTask: () => native.deleteFile(timestmap),
                      buttonOrange: 'No',
                      buttonOrangeTask: () => Future.microtask(
                          () => eventBus.fire(DialogEvent.dismiss, eventKey)),
                    ),
                    eventKey);
              },
            ),
          ],
          elevation: 8.0,
        );
      },
      icon: const Icon(CupertinoIcons.ellipsis_vertical,
          color: CupertinoColors.white, size: 24),
    );
  });
}
