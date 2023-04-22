import 'dart:io';


class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();


  Future<void> init() async {
    final appDataDir = Directory.current;

  }

}
