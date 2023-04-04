import 'package:flutter/material.dart';


Widget dropdown(
    {required String value,
    required List<String> items,
    required Function(String) onChanged}) {
      print("value: $value \n");
      print("items: $items");


  return DropdownButton<String>(
    value: value,
    icon: const Icon(Icons.arrow_downward),
    iconSize: 24,
    elevation: 16,
    style: const TextStyle(color: Colors.deepPurple),
    underline: Container(
      height: 2,
      color: Colors.deepPurpleAccent,
    ),
    onChanged: (String? newValue) {
      if (newValue!.isNotEmpty) {
        onChanged(newValue);
      }
    },
    items: items.map<DropdownMenuItem<String>>((String value) {
      return DropdownMenuItem<String>(
        value: value,
        child: Text(value),
      );
    }).toList(),
  );
}
