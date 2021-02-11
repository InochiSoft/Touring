import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseProvider {
  Database database;

  Future open() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'touring.db');
    int version = 1;
    database = await openDatabase(
      path,
      version: version,
      onCreate: onCreate(database, version),
    );
  }

  FutureOr onCreate(Database db, int version) async {
    String sqlTableUsers = "CREATE TABLE users "
        "("
        "uid varchar(32),"
        "name varchar(50),"
        "email varchar(100),"
        "image varchar(500)"
        ");";
    db.execute(sqlTableUsers);
  }

  Future close() async {
    database.close();
  }

}