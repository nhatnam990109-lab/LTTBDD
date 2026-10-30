import 'dart:io';

import 'package:mysql_client/mysql_client.dart';

class DbConfig {
  DbConfig({
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.database,
    required this.apiPort,
  });

  final String host;
  final int port;
  final String user;
  final String password;
  final String database;
  final int apiPort;

  static DbConfig load() {
    final file = File('config.json');
    if (!file.existsSync()) {
      throw StateError('Thiếu clinic-api/config.json');
    }
    final raw = file.readAsStringSync();
    final map = _decode(raw);
    return DbConfig(
      host: '${map['host'] ?? '127.0.0.1'}',
      port: int.tryParse('${map['port'] ?? 3306}') ?? 3306,
      user: '${map['user'] ?? 'root'}',
      password: '${map['password'] ?? ''}',
      database: '${map['database'] ?? 'cliniccare'}',
      apiPort: int.tryParse('${map['apiPort'] ?? 8080}') ?? 8080,
    );
  }

  static Map<String, Object?> _decode(String raw) {
    final result = <String, Object?>{};
    final pattern = RegExp(r'"([^"]+)"\s*:\s*("([^"]*)"|-?\d+)');
    for (final match in pattern.allMatches(raw)) {
      final key = match.group(1)!;
      final number = match.group(2)!;
      if (number.startsWith('"')) {
        result[key] = match.group(3);
      } else {
        result[key] = int.tryParse(number) ?? number;
      }
    }
    return result;
  }
}

class Db {
  Db(this.pool);
  final MySQLConnectionPool pool;

  Future<List<Map<String, String?>>> query(String sql, [Map<String, dynamic>? params]) async {
    final result = await pool.execute(sql, params);
    return result.rows.map((row) => row.assoc()).toList();
  }

  Future<Map<String, String?>?> one(String sql, [Map<String, dynamic>? params]) async {
    final rows = await query(sql, params);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> exec(String sql, [Map<String, dynamic>? params]) async {
    final result = await pool.execute(sql, params);
    return result.affectedRows.toInt();
  }

  Future<void> close() => pool.close();
}

Future<void> ensureDoctorCanBeRemoved(DbConfig config) async {
  final conn = await MySQLConnection.createConnection(
    host: config.host,
    port: config.port,
    userName: config.user,
    password: config.password,
    databaseName: config.database,
    secure: true,
  );
  await conn.connect();
  try {
    final column = await conn.execute(
      '''SELECT IS_NULLABLE AS nullable FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'appointments' AND COLUMN_NAME = 'doctor_id' ''',
      {'db': config.database},
    );
    if (column.rows.isEmpty || column.rows.first.colByName('nullable') == 'YES') return;
    final foreignKey = await conn.execute(
      '''SELECT CONSTRAINT_NAME AS name FROM information_schema.KEY_COLUMN_USAGE
         WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'appointments' AND COLUMN_NAME = 'doctor_id'
           AND REFERENCED_TABLE_NAME = 'doctors' ''',
      {'db': config.database},
    );
    if (foreignKey.rows.isNotEmpty) {
      final name = foreignKey.rows.first.colByName('name') ?? '';
      if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(name)) {
        throw StateError('Khóa ngoại bác sĩ không hợp lệ.');
      }
      await conn.execute('ALTER TABLE appointments DROP FOREIGN KEY $name');
    }
    await conn.execute('ALTER TABLE appointments MODIFY doctor_id VARCHAR(20) NULL');
    await conn.execute(
      'ALTER TABLE appointments ADD CONSTRAINT fk_apt_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE SET NULL',
    );
  } finally {
    await conn.close();
  }
}

Future<void> ensureSchema(DbConfig config) async {
  final conn = await MySQLConnection.createConnection(
    host: config.host,
    port: config.port,
    userName: config.user,
    password: config.password,
    secure: true,
  );
  await conn.connect();
  try {
    final exists = await conn.execute(
      "SELECT COUNT(*) AS c FROM information_schema.tables WHERE table_schema = :db AND table_name = 'users'",
      {'db': config.database},
    );
    final count = int.tryParse(exists.rows.first.colByName('c') ?? '0') ?? 0;
    if (count > 0) return;

    final sqlFile = _sqlFile();
    final script = sqlFile.readAsStringSync();
    final statements = _statements(script);
    stdout.writeln('Đang nhập ${statements.length} lệnh từ ${sqlFile.path} vào MySQL...');
    for (final statement in statements) {
      await conn.execute(statement);
    }
    stdout.writeln('Đã tạo database cliniccare và dữ liệu mẫu.');
  } finally {
    await conn.close();
  }
}

File _sqlFile() {
  final candidates = [
    File('../sql/cliniccare.sql'),
    File('sql/cliniccare.sql'),
    File(r'd:\LTTBDD\sql\cliniccare.sql'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) return file;
  }
  throw StateError('Không thấy file sql/cliniccare.sql');
}

List<String> _statements(String script) {
  final kept = script
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');
  return kept
      .split(';')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

Future<Db> openDatabase(DbConfig config) async {
  final pool = MySQLConnectionPool(
    host: config.host,
    port: config.port,
    userName: config.user,
    password: config.password,
    maxConnections: 8,
    databaseName: config.database,
    secure: true,
  );
  await pool.execute('SELECT 1');
  return Db(pool);
}
