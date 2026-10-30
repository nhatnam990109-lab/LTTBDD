import 'dart:io';

import 'package:clinic_api/clinic_server.dart';
import 'package:clinic_api/db.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final config = DbConfig.load();
  try {
    await ensureSchema(config);
    await ensureDoctorCanBeRemoved(config);
  } on SocketException {
    _mysqlHelp(config, 'Không kết nối được tới MySQL.');
    exitCode = 1;
    return;
  } catch (error) {
    _mysqlHelp(config, '$error');
    exitCode = 1;
    return;
  }

  final db = await openDatabase(config);
  final app = ClinicApp(db);
  final server = await shelf_io.serve(app.handler, InternetAddress.loopbackIPv4, config.apiPort);
  stdout.writeln('ClinicCare API đang chạy tại http://${server.address.host}:${server.port}');
  stdout.writeln('Database: ${config.database} trên ${config.host}:${config.port}');
}

void _mysqlHelp(DbConfig config, String error) {
  stderr.writeln(error);
  stderr.writeln('Mở MySQL Workbench, kết nối Local instance MySQL80, rồi nhập file sql/cliniccare.sql.');
  stderr.writeln('Nếu Workbench yêu cầu mật khẩu root, hãy ghi đúng mật khẩu đó vào clinic-api/config.json, khóa "password".');
  stderr.writeln('Đang dùng user ${config.user} tại ${config.host}:${config.port}.');
}
