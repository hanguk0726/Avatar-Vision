import '../domain/tab_item.dart';

class RuntimeData {
  static final RuntimeData _instance = RuntimeData._internal();
  factory RuntimeData() => _instance;
  RuntimeData._internal();

  int tabIndex = 0;

  TabItem get currentTab => TabItem.values[tabIndex];
}
