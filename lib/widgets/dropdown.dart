import 'package:flutter/material.dart';

Widget dropdown(
    {required String value,
    required List<String> items,
    required Function(String) onChanged,
    required Icon icon,
    required String textOnEmpty,
    required Icon iconOnEmpty}) {
  if (items.isEmpty) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(textOnEmpty),
        const SizedBox(width: 8),
        iconOnEmpty,
      ],
    );
  }

  return DropdownButton<String>(
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    isExpanded: true,
    value: value,
    icon: icon,
    iconSize: 24,
    elevation: 16,
    style: const TextStyle(color: Colors.black),
    underline: Container(
      height: 2,
      color: Colors.grey[300],
    ),
    onChanged: (String? newValue) {
      if (newValue!.isNotEmpty) {
        onChanged(newValue);
      }
    },
    items: items.map<DropdownMenuItem<String>>((String value) {
      return DropdownMenuItem<String>(
        alignment: Alignment.center,
        value: value,
        child: Text(
          value,
        ),
      );
    }).toList(),
  );
}
