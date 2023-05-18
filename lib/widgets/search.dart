import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/services/database.dart';
import 'package:video_diary/services/event_bus.dart';

class DateSearchBar extends StatefulWidget {
  const DateSearchBar({super.key});

  @override
  DateSearchBarState createState() => DateSearchBarState();
}

class DateSearchBarState extends State<DateSearchBar> {
  final _textController = TextEditingController();
  final focusNode = FocusNode();
  TextStyle textStyle =
      TextStyle(color: Colors.white, fontFamily: subFont, fontSize: 22);
  DateTime? _getSelectedDate() {
    try {
      final inputFormat = DateFormat('MM/dd/yyyy');
      final text = _textController.text;
      if (text.length != 8) {
        return null;
      }
      final month = text.substring(0, 2);
      final day = text.substring(2, 4);
      final year = text.substring(4, 8);
      final formatted = "$month/$day/$year";

      return inputFormat.parse(formatted);
    } catch (e) {
      return null;
    }
  }

  void _handleSearch() {
    var db = DatabaseService();
    final selectedDate = _getSelectedDate();
    if (selectedDate != null) {
      db.filterEntriesBefore(selectedDate.millisecondsSinceEpoch);
    }
  }

  @override
  void initState() {
    super.initState();
    focusNode.addListener(() {
       EventBus().off = focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    EventBus().off = false;
    var db = DatabaseService();
    db.resetUiStatePastEntries(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
        message: "input date in MMDDYYYY format ",
        decoration: BoxDecoration(
          color: customOcean,
        ),
        textStyle:
            TextStyle(color: Colors.white, fontSize: 16, fontFamily: mainFont),
        preferBelow: false,
        child: SizedBox(
            height: 50,
            width: 250,
            child: Row(
              children: [
                Expanded(
                    child: TextFormField(
                  focusNode: focusNode,
                  controller: _textController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  cursorColor: Colors.white,
                  onChanged: (value) {
                    EasyDebounce.debounce(
                        "searchDate",
                        const Duration(milliseconds: 300),
                        () => _handleSearch());
                  },
                  style: textStyle,
                )),
                const SizedBox(width: 8),
                Icon(Icons.search, color: customSky.withOpacity(0.6)),
                const SizedBox(width: 16),
              ],
            )));
  }
}
