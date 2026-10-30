import 'dart:convert';

import 'package:clinic_api/db.dart';
import 'package:clinic_api/util.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

const _netRevenue = '''
CASE
  WHEN paid = 1 AND refund_status = 'done' THEN GREATEST(amount - refund_amount, 0)
  WHEN paid = 1 THEN amount
  ELSE 0
END
''';

class ClinicApp {
  ClinicApp(this.db) {
    final router = Router()
      ..get('/api/health', _health)
      ..get('/api/meta', _meta)
      ..get('/api/slots', _slots)
      ..post('/api/appointments', _createAppointment)
      ..get('/api/appointments/lookup', _lookup)
      ..post('/api/appointments/confirm-payment', _confirmPayment)
      ..post('/api/appointments/guest-cancel', _guestCancel)
      ..post('/api/appointments/guest-reschedule', _guestReschedule)
      ..post('/api/appointments/guest-support', _guestSupport)
      ..post('/api/consults', _consult)
      ..post('/api/auth/register', _register)
      ..post('/api/auth/verify', _verify)
      ..post('/api/auth/login', _login)
      ..post('/api/auth/logout', _logout)
      ..post('/api/auth/forgot', _forgot)
      ..post('/api/auth/reset', _reset)
      ..get('/api/me', _me)
      ..put('/api/me', _updateMe)
      ..put('/api/me/password', _changePassword)
      ..get('/api/me/appointments', _myAppointments)
      ..get('/api/me/records', _myRecords)
      ..post('/api/appointments/<id>/cancel', _cancelOwn)
      ..post('/api/appointments/<id>/reschedule', _reschedule)
      ..post('/api/appointments/<id>/support-cancel', _supportCancel)
      ..post('/api/appointments/<id>/pay', _pay)
      ..get('/api/records/<id>', _record)
      ..get('/api/clinical/patients', _patients)
      ..get('/api/clinical/today', _today)
      ..get('/api/clinical/appointments', _clinicalAppointments)
      ..post('/api/clinical/records', _saveRecord)
      ..delete('/api/clinical/records/<id>', _deleteRecord)
      ..get('/api/admin/overview', _overview)
      ..get('/api/admin/revenue', _revenue)
      ..get('/api/admin/appointments', _adminAppointments)
      ..post('/api/admin/appointments/<id>/cancel', _adminCancel)
      ..post('/api/admin/appointments/<id>/status', _adminSetAppointmentStatus)
      ..delete('/api/admin/appointments/<id>', _adminDeleteAppointment)
      ..post('/api/admin/appointments/<id>/pay', _adminPay)
      ..post('/api/admin/appointments/<id>/reject-cancel', _rejectCancel)
      ..post('/api/admin/appointments/<id>/refund', _refund)
      ..post('/api/admin/doctors', _createDoctor)
      ..put('/api/admin/doctors/<id>', _updateDoctor)
      ..delete('/api/admin/doctors/<id>', _deleteDoctor)
      ..post('/api/admin/doctors/<id>/account', _createDoctorAccount)
      ..get('/api/admin/users', _users)
      ..post('/api/admin/users', _createPatient)
      ..post('/api/admin/users/<id>/role', _setRole)
      ..post('/api/admin/users/<id>/lock', _lock)
      ..post('/api/admin/users/<id>/unlock', _unlock)
      ..delete('/api/admin/users/<id>', _deleteUser)
      ..get('/api/admin/logs', _logs)
      ..get('/api/admin/medicines', _medicines)
      ..post('/api/admin/disease-groups', _addGroup)
      ..post('/api/admin/medicines', _addMedicine)
      ..post('/api/admin/medicines/<id>/detach', _detachMedicine)
      ..delete('/api/admin/medicines/<id>', _deleteMedicine);
    handler = const Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(logRequests())
        .addHandler(router.call);
  }

  final Db db;
  late final Handler handler;

  static const _json = {'content-type': 'application/json; charset=utf-8'};

  Response _ok(Object data, [int code = 200]) =>
      Response(code, body: jsonEncode(data), headers: _json);

  Response _err(int code, String message) =>
      _ok({'ok': false, 'message': message}, code);

  Future<Response> _guard(Future<Response> Function() action) async {
    try {
      return await action();
    } on ApiException catch (error) {
      return _err(error.code, error.message);
    } on FormatException {
      return _err(400, 'Dữ liệu gửi lên không hợp lệ.');
    } catch (error, stack) {
      // In ra console để biết lỗi SQL khi demo, không trả câu lệnh cho trình duyệt.
      // ignore: avoid_print
      print('$error\n$stack');
      return _err(500, 'Máy chủ gặp lỗi khi xử lý yêu cầu.');
    }
  }

  Future<Map<String, dynamic>> _body(Request request) async {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map)
      return decoded.map((key, value) => MapEntry('$key', value));
    throw const FormatException('JSON');
  }

  Future<Map<String, dynamic>?> _user(Request request) async {
    final header = request.headers['authorization'] ?? '';
    if (!header.startsWith('Bearer ')) return null;
    final token = header.substring(7).trim();
    if (token.isEmpty) return null;
    final row = await db.one(
      '''SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id
         WHERE s.token = :token AND s.expires_at > NOW()''',
      {'token': token},
    );
    return row == null ? null : _userJson(row);
  }

  Future<Response> _auth(Request request,
      Future<Response> Function(Map<String, dynamic> user) action,
      {List<String>? roles}) {
    return _guard(() async {
      final user = await _user(request);
      if (user == null) throw ApiException(401, 'Vui lòng đăng nhập.');
      if (user['locked'] == true)
        throw ApiException(403, 'Tài khoản đã bị khóa.');
      if (roles != null && !roles.contains(user['role'])) {
        throw ApiException(403, 'Bạn không có quyền thực hiện thao tác này.');
      }
      if (user['role'] == 'doctor') {
        final doctor = await db.one(
            'SELECT id FROM doctors WHERE user_id = :user OR id = :doctor LIMIT 1',
            {'user': user['id'], 'doctor': user['doctorId']});
        user['doctorId'] = doctor?['id'];
      }
      return action(user);
    });
  }

  Map<String, dynamic> _userJson(Map<String, String?> row) {
    return {
      'id': row['id'],
      'fullName': row['full_name'],
      'email': row['email'],
      'phone': row['phone'],
      'role': row['role'],
      'gender': row['gender'],
      'dateOfBirth': dateOnly(row['date_of_birth']),
      'address': row['address'] ?? '',
      'avatarUrl': row['avatar_url'],
      'verified': row['verified'] == '1',
      'locked': row['locked'] == '1',
      'lockReason': row['lock_reason'],
      'doctorId': row['doctor_id'],
    };
  }

  Map<String, dynamic> _appointmentJson(Map<String, String?> row) {
    return {
      'id': row['id'],
      'code': row['code'],
      'userId': row['user_id'],
      'patientName': row['patient_name'],
      'phone': row['phone'],
      'email': row['email'],
      'gender': row['gender'],
      'note': row['note'] ?? '',
      'packageId': row['package_id'],
      'packageName': row['package_name'],
      'tagline': row['tagline'],
      'branchId': row['branch_id'],
      'branchName': row['branch_name'],
      'doctorId': row['doctor_id'],
      'doctorName': (row['doctor_name'] == null || row['doctor_name']!.isEmpty)
          ? 'Bác sĩ đã nghỉ'
          : row['doctor_name'],
      'specialty': row['specialty'],
      'date': dateOnly(row['appointment_date']),
      'time': timeOnly(row['appointment_time']),
      'status': row['status'],
      'paymentMethod': row['payment_method'],
      'paid': row['paid'] == '1',
      'amount': intOf(row['amount']),
      'refundStatus': row['refund_status'],
      'refundAmount': intOf(row['refund_amount']),
      'cancelRequestStatus': row['cancel_request_status'],
      'cancelRequestReason': row['cancel_request_reason'],
      'createdAt': row['created_at'],
    };
  }

  Future<Map<String, String?>?> _appointmentRow(String id) {
    return db.one('''
      SELECT a.*, p.name AS package_name, p.tagline, b.name AS branch_name,
             d.full_name AS doctor_name, d.specialty
      FROM appointments a
      JOIN packages p ON p.id = a.package_id
      JOIN branches b ON b.id = a.branch_id
      LEFT JOIN doctors d ON d.id = a.doctor_id
      WHERE a.id = :id''', {'id': id});
  }

  Future<void> _log(
      Map<String, dynamic> actor, String action, String detail) async {
    await db.exec(
      '''INSERT INTO audit_logs (id, actor_id, actor_name, action, detail)
         VALUES (:id, :actor, :name, :action, :detail)''',
      {
        'id': 'log-${randomToken(6)}',
        'actor': actor['id'],
        'name': actor['fullName'],
        'action': action,
        'detail': detail.length > 250 ? detail.substring(0, 250) : detail,
      },
    );
  }

  Future<bool> _slotTaken(String doctorId, String date, String time,
      [String? exclude]) async {
    final row = await db.one(
      '''SELECT id FROM appointments
         WHERE doctor_id = :doctor AND appointment_date = :date AND appointment_time = :time
           AND status <> 'cancelled' AND id <> :exclude LIMIT 1''',
      {
        'doctor': doctorId,
        'date': date,
        'time': '$time:00',
        'exclude': exclude ?? ''
      },
    );
    return row != null;
  }

  Future<String> _assignDoctor(
      String branchId, String? doctorId, String date, String time,
      [String? exclude]) async {
    if (doctorId != null && doctorId.isNotEmpty && doctorId != 'any') {
      final doctor = await db.one(
          'SELECT id, branch_id FROM doctors WHERE id = :id', {'id': doctorId});
      if (doctor == null) throw ApiException(400, 'Không tìm thấy bác sĩ.');
      if (doctor['branch_id'] != branchId)
        throw ApiException(400, 'Bác sĩ không làm việc tại cơ sở này.');
      if (await _slotTaken(doctorId, date, time, exclude)) {
        throw ApiException(409, 'Khung giờ này đã có lịch với bác sĩ đã chọn.');
      }
      return doctorId;
    }
    final doctors = await db.query(
      'SELECT id FROM doctors WHERE branch_id = :branch ORDER BY full_name',
      {'branch': branchId},
    );
    for (final doctor in doctors) {
      final id = doctor['id']!;
      if (!await _slotTaken(id, date, time, exclude)) return id;
    }
    throw ApiException(409, 'Không còn bác sĩ trống ở khung giờ này.');
  }

  Future<Response> _health(Request request) => _guard(() async {
        final row = await db.one('SELECT COUNT(*) AS c FROM users');
        return _ok(
            {'ok': true, 'database': 'cliniccare', 'users': intOf(row?['c'])});
      });

  Future<Response> _meta(Request request) => _guard(() async {
        final branches = await db.query('SELECT * FROM branches ORDER BY name');
        final packages = await db.query(
          """SELECT * FROM packages ORDER BY FIELD(id, 'pkg-silver', 'pkg-gold', 'pkg-diamond', 'pkg-well-dia', 'pkg-well-elite', 'pkg-parasite', 'pkg-repro', 'pkg-vitamin')""",
        );
        final tests = await db.query(
            'SELECT package_id, test_name FROM package_tests ORDER BY sort_order');
        final doctors = await db.query('''
          SELECT d.*, b.name AS branch_name, u.id AS linked_user_id FROM doctors d
          JOIN branches b ON b.id = d.branch_id
          LEFT JOIN users u ON u.doctor_id = d.id OR (u.email = d.email AND u.role = 'doctor')
          ORDER BY d.full_name''');
        return _ok({
          'branches': branches
              .map((row) => {
                    'id': row['id'],
                    'name': row['name'],
                    'address': row['address'],
                    'phone': row['phone'],
                    'openingHours': row['opening_hours'],
                  })
              .toList(),
          'packages': packages.map((row) {
            final id = row['id'];
            return {
              'id': id,
              'name': row['name'],
              'tagline': row['tagline'],
              'price': intOf(row['price']),
              'testCount': intOf(row['test_count']),
              'badge': row['badge'],
              'summary': row['summary'],
              'tests': tests
                  .where((item) => item['package_id'] == id)
                  .map((item) => item['test_name'])
                  .toList(),
            };
          }).toList(),
          'doctors': doctors
              .map((row) => {
                    'id': row['id'],
                    'userId': row['user_id'] ?? row['linked_user_id'],
                    'hasAccount':
                        (row['user_id'] != null && row['user_id'] != '') ||
                            (row['linked_user_id'] != null &&
                                row['linked_user_id'] != ''),
                    'fullName': row['full_name'],
                    'specialty': row['specialty'],
                    'branchId': row['branch_id'],
                    'branchName': row['branch_name'],
                    'email': row['email'],
                    'bio': row['bio'] ?? '',
                    'avatarUrl': row['avatar_url'],
                  })
              .toList(),
          'timeSlots': timeSlots,
        });
      });

  Future<Response> _slots(Request request) => _guard(() async {
        final query = request.url.queryParameters;
        final branchId = textOf(query['branchId']);
        final date = textOf(query['date']);
        final doctorId = textOf(query['doctorId']);
        if (branchId.isEmpty ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
          throw ApiException(400, 'Chọn cơ sở và ngày khám.');
        }
        final doctors = doctorId.isEmpty || doctorId == 'any'
            ? await db.query('SELECT id FROM doctors WHERE branch_id = :id',
                {'id': branchId})
            : await db.query(
                'SELECT id FROM doctors WHERE id = :id AND branch_id = :branch',
                {'id': doctorId, 'branch': branchId});
        final taken = await db.query(
          '''SELECT doctor_id, DATE_FORMAT(appointment_time, '%H:%i') AS time_label
             FROM appointments
             WHERE branch_id = :branch AND appointment_date = :date AND status <> 'cancelled' ''',
          {'branch': branchId, 'date': date},
        );
        final slots = timeSlots.map((time) {
          final busy = taken
              .where((row) => row['time_label'] == time)
              .map((row) => row['doctor_id'])
              .toSet();
          final free =
              doctors.where((doctor) => !busy.contains(doctor['id'])).length;
          return {'time': time, 'full': free == 0};
        }).toList();
        return _ok({'slots': slots});
      });

  Future<Response> _createAppointment(Request request) => _guard(() async {
        final session = await _user(request);
        if (session == null)
          throw ApiException(401, 'Vui lòng đăng nhập để đặt lịch.');
        if (session['locked'] == true)
          throw ApiException(403, 'Tài khoản đã bị khóa.');
        final data = await _body(request);
        final name = textOf(data['patientName']);
        final phone = canonicalPhone(textOf(data['phone']));
        final email = textOf(data['email']).toLowerCase();
        final gender = textOf(data['gender'], 'other');
        final packageId = textOf(data['packageId']);
        final branchId = textOf(data['branchId']);
        final date = textOf(data['date']);
        final time = textOf(data['time']);
        final method = textOf(data['paymentMethod']);
        if (name.length < 2) throw ApiException(400, 'Vui lòng nhập họ tên.');
        if (!isValidVnPhone(phone))
          throw ApiException(400, 'Số điện thoại Việt Nam không hợp lệ.');
        if (!isValidEmail(email))
          throw ApiException(400, 'Email không hợp lệ.');
        if (!['male', 'female', 'other'].contains(gender))
          throw ApiException(400, 'Giới tính không hợp lệ.');
        if (!['momo', 'cash', 'transfer'].contains(method))
          throw ApiException(400, 'Hình thức thanh toán không hợp lệ.');
        if (!timeSlots.contains(time) ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
          throw ApiException(400, 'Ngày hoặc giờ khám không hợp lệ.');
        }
        final slot = slotDateTime(date, time);
        if (slot == null || slot.isBefore(DateTime.now()))
          throw ApiException(400, 'Khung giờ này đã qua.');
        final package = await db.one(
            'SELECT id, price FROM packages WHERE id = :id', {'id': packageId});
        final branch = await db
            .one('SELECT id FROM branches WHERE id = :id', {'id': branchId});
        if (package == null || branch == null)
          throw ApiException(400, 'Gói khám hoặc cơ sở không tồn tại.');
        final doctorId =
            await _assignDoctor(branchId, textOf(data['doctorId']), date, time);
        var code = '';
        for (var attempt = 0; attempt < 5; attempt++) {
          final candidate = 'CC-${randomCode(6)}';
          final exists = await db.one(
              'SELECT id FROM appointments WHERE code = :code',
              {'code': candidate});
          if (exists == null) {
            code = candidate;
            break;
          }
        }
        if (code.isEmpty)
          throw ApiException(500, 'Không tạo được mã lịch khám.');
        final id = 'apt-${randomToken(4)}';
        final status = method == 'cash' ? 'confirmed' : 'pending';
        await db.exec(
          '''INSERT INTO appointments (
               id, code, user_id, patient_name, phone, email, gender, note, package_id, branch_id, doctor_id,
               appointment_date, appointment_time, status, payment_method, paid, amount)
             VALUES (
               :id, :code, :userId, :name, :phone, :email, :gender, :note, :package, :branch, :doctor,
               :date, :time, :status, :method, 0, :amount)''',
          {
            'id': id,
            'code': code,
            'userId': session['id'],
            'name': name,
            'phone': phone,
            'email': email,
            'gender': gender,
            'note': textOf(data['note']),
            'package': packageId,
            'branch': branchId,
            'doctor': doctorId,
            'date': date,
            'time': '$time:00',
            'status': status,
            'method': method,
            'amount': intOf(package['price']),
          },
        );
        final created = await _appointmentRow(id);
        return _ok(
            {'ok': true, 'appointment': _appointmentJson(created!)}, 201);
      });

  Future<Response> _lookup(Request request) => _guard(() async {
        final query = request.url.queryParameters;
        final code = textOf(query['code']).toUpperCase();
        final phone = canonicalPhone(textOf(query['phone']));
        if (code.isEmpty || phone.isEmpty)
          throw ApiException(400, 'Nhập mã lịch và số điện thoại.');
        final row = await db.one('''
          SELECT a.*, p.name AS package_name, p.tagline, b.name AS branch_name,
                 d.full_name AS doctor_name, d.specialty
          FROM appointments a
          JOIN packages p ON p.id = a.package_id
          JOIN branches b ON b.id = a.branch_id
          LEFT JOIN doctors d ON d.id = a.doctor_id
          WHERE a.code = :code AND a.phone = :phone''',
            {'code': code, 'phone': phone});
        if (row == null) throw ApiException(404, 'Không tìm thấy lịch khám.');
        final record = await db.one(
            'SELECT id FROM medical_records WHERE appointment_id = :id',
            {'id': row['id']});
        final completedRecordId = row['status'] == 'completed' && record != null
            ? record['id']
            : null;
        final completedRecord = completedRecordId == null
            ? null
            : await _recordRow(completedRecordId);
        final recordDetails =
            completedRecord != null && completedRecord['status'] == 'completed'
                ? await _recordJson(completedRecord)
                : null;
        return _ok({
          'appointment': _appointmentJson(row),
          'recordId': record?['id'],
          'record': recordDetails,
        });
      });

  Future<Map<String, String?>> _byCodePhone(Map<String, dynamic> data) async {
    final code = textOf(data['code']).toUpperCase();
    final phone = canonicalPhone(textOf(data['phone']));
    final row = await db.one('''
      SELECT a.*, p.name AS package_name, p.tagline, b.name AS branch_name,
             d.full_name AS doctor_name, d.specialty
      FROM appointments a
      JOIN packages p ON p.id = a.package_id
      JOIN branches b ON b.id = a.branch_id
      LEFT JOIN doctors d ON d.id = a.doctor_id
      WHERE a.code = :code AND a.phone = :phone''',
        {'code': code, 'phone': phone});
    if (row == null) throw ApiException(404, 'Không tìm thấy lịch khám.');
    return row;
  }

  Future<Response> _confirmPayment(Request request) => _guard(() async {
        final row = await _byCodePhone(await _body(request));
        if (row['status'] == 'cancelled')
          throw ApiException(400, 'Lịch đã hủy, không thể thanh toán.');
        if (row['payment_method'] == 'cash')
          throw ApiException(400, 'Lịch tiền mặt được thu tại quầy.');
        await db.exec(
          "UPDATE appointments SET paid = 1, status = IF(status = 'pending', 'confirmed', status) WHERE id = :id",
          {'id': row['id']},
        );
        final updated = await _appointmentRow(row['id']!);
        return _ok({
          'ok': true,
          'message': 'Đã ghi nhận thanh toán.',
          'appointment': _appointmentJson(updated!)
        });
      });

  Future<Response> _guestCancel(Request request) => _guard(() async {
        final row = await _byCodePhone(await _body(request));
        if (!canModifyAppointment(dateOnly(row['appointment_date']),
            timeOnly(row['appointment_time']), row['status']!)) {
          throw ApiException(400,
              'Chỉ hủy trực tiếp trước giờ khám ít nhất 2 giờ. Hãy gửi yêu cầu hỗ trợ.');
        }
        await db.exec(
          '''UPDATE appointments SET status = 'cancelled',
             refund_status = CASE WHEN paid = 1 THEN 'pending' ELSE refund_status END
             WHERE id = :id''',
          {'id': row['id']},
        );
        return _ok({'ok': true, 'message': 'Đã hủy lịch khám.'});
      });

  Future<Response> _guestReschedule(Request request) => _guard(() async {
        final data = await _body(request);
        final row = await _byCodePhone(data);
        if (!canModifyAppointment(dateOnly(row['appointment_date']),
            timeOnly(row['appointment_time']), row['status']!)) {
          throw ApiException(400, 'Chỉ đổi lịch trước giờ khám ít nhất 2 giờ.');
        }
        final date = textOf(data['date']);
        final time = textOf(data['time']);
        final branchId = textOf(data['branchId'], row['branch_id']!);
        if (!timeSlots.contains(time) ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
          throw ApiException(400, 'Ngày hoặc giờ mới không hợp lệ.');
        }
        final doctorId = await _assignDoctor(
            branchId, textOf(data['doctorId']), date, time, row['id']);
        await db.exec(
          '''UPDATE appointments SET appointment_date = :date, appointment_time = :time,
             branch_id = :branch, doctor_id = :doctor WHERE id = :id''',
          {
            'date': date,
            'time': '$time:00',
            'branch': branchId,
            'doctor': doctorId,
            'id': row['id']
          },
        );
        final updated = await _appointmentRow(row['id']!);
        return _ok({'ok': true, 'appointment': _appointmentJson(updated!)});
      });

  Future<Response> _guestSupport(Request request) => _guard(() async {
        final data = await _body(request);
        final row = await _byCodePhone(data);
        if (row['status'] == 'cancelled' || row['status'] == 'completed') {
          throw ApiException(400, 'Lịch này không thể gửi yêu cầu hủy.');
        }
        final reason = textOf(data['reason']);
        if (reason.length < 5)
          throw ApiException(400, 'Nhập lý do cần hỗ trợ hủy lịch.');
        await db.exec(
          '''UPDATE appointments SET cancel_request_status = 'open', cancel_request_reason = :reason,
             cancel_request_at = NOW() WHERE id = :id''',
          {'reason': reason, 'id': row['id']},
        );
        return _ok(
            {'ok': true, 'message': 'Đã gửi yêu cầu hủy tới phòng khám.'});
      });

  Future<Response> _consult(Request request) => _guard(() async {
        final data = await _body(request);
        final name = textOf(data['fullName']);
        final phone = canonicalPhone(textOf(data['phone']));
        if (name.length < 2 || !isValidVnPhone(phone))
          throw ApiException(400, 'Nhập họ tên và số điện thoại hợp lệ.');
        await db.exec(
          'INSERT INTO consults (id, full_name, phone, note) VALUES (:id, :name, :phone, :note)',
          {
            'id': 'cs-${randomToken(4)}',
            'name': name,
            'phone': phone,
            'note': textOf(data['note'])
          },
        );
        return _ok({
          'ok': true,
          'message': 'Đã gửi yêu cầu tư vấn. Phòng khám sẽ liên hệ bạn.'
        });
      });

  Future<Response> _register(Request request) => _guard(() async {
        final data = await _body(request);
        final name = textOf(data['fullName']);
        final email = textOf(data['email']).toLowerCase();
        final phone = canonicalPhone(textOf(data['phone']));
        final password = textOf(data['password']);
        final gender = textOf(data['gender'], 'other');
        if (name.length < 2) throw ApiException(400, 'Vui lòng nhập họ tên.');
        if (!isValidEmail(email))
          throw ApiException(400, 'Email không hợp lệ.');
        if (!isValidVnPhone(phone))
          throw ApiException(400, 'Số điện thoại Việt Nam không hợp lệ.');
        if (password.length < 6)
          throw ApiException(400, 'Mật khẩu cần ít nhất 6 ký tự.');
        final exists = await db
            .one('SELECT id FROM users WHERE email = :email', {'email': email});
        if (exists != null)
          throw ApiException(409, 'Email này đã được đăng ký.');
        final code = (100000 + DateTime.now().millisecondsSinceEpoch % 900000)
            .toString();
        await db.exec(
          '''INSERT INTO users (id, full_name, email, phone, password_hash, role, gender, date_of_birth, address, verified, verify_code)
             VALUES (:id, :name, :email, :phone, :hash, 'user', :gender, :dob, :address, 0, :code)''',
          {
            'id': 'user-${randomToken(4)}',
            'name': name,
            'email': email,
            'phone': phone,
            'hash': hashPassword(password),
            'gender':
                ['male', 'female', 'other'].contains(gender) ? gender : 'other',
            'dob': textOf(data['dateOfBirth']).isEmpty
                ? null
                : textOf(data['dateOfBirth']),
            'address': textOf(data['address']),
            'code': code,
          },
        );
        return _ok({
          'ok': true,
          'message': 'Đã tạo tài khoản. Nhập mã xác thực để kích hoạt.',
          'email': email,
          'verifyCode': code,
        }, 201);
      });

  Future<Response> _verify(Request request) => _guard(() async {
        final data = await _body(request);
        final email = textOf(data['email']).toLowerCase();
        final code = textOf(data['code']);
        final user = await db.one(
            'SELECT id, verify_code, verified FROM users WHERE email = :email',
            {'email': email});
        if (user == null || user['verify_code'] != code)
          throw ApiException(400, 'Mã xác thực không đúng.');
        await db.exec(
            'UPDATE users SET verified = 1, verify_code = NULL WHERE id = :id',
            {'id': user['id']});
        return _ok({
          'ok': true,
          'message': 'Email đã được xác thực. Bạn có thể đăng nhập.'
        });
      });

  Future<Response> _login(Request request) => _guard(() async {
        final data = await _body(request);
        final email = textOf(data['email']).toLowerCase();
        final password = textOf(data['password']);
        final row = await db
            .one('SELECT * FROM users WHERE email = :email', {'email': email});
        if (row == null ||
            (row['password_hash'] ?? '').toLowerCase() !=
                hashPassword(password)) {
          throw ApiException(401, 'Email hoặc mật khẩu không đúng.');
        }
        if (row['locked'] == '1') {
          throw ApiException(
              403, 'Tài khoản đã bị khóa. ${row['lock_reason'] ?? ''}'.trim());
        }
        if (row['verified'] != '1') {
          return _err(403, 'Email chưa được xác thực.');
        }
        final token = randomToken(24);
        await db.exec(
          'INSERT INTO sessions (token, user_id, expires_at) VALUES (:token, :user, DATE_ADD(NOW(), INTERVAL 7 DAY))',
          {'token': token, 'user': row['id']},
        );
        return _ok({'ok': true, 'token': token, 'user': _userJson(row)});
      });

  Future<Response> _logout(Request request) => _guard(() async {
        final header = request.headers['authorization'] ?? '';
        if (header.startsWith('Bearer ')) {
          await db.exec('DELETE FROM sessions WHERE token = :token',
              {'token': header.substring(7).trim()});
        }
        return _ok({'ok': true});
      });

  Future<Response> _forgot(Request request) => _guard(() async {
        final data = await _body(request);
        final email = textOf(data['email']).toLowerCase();
        final user = await db
            .one('SELECT id FROM users WHERE email = :email', {'email': email});
        if (user == null) throw ApiException(404, 'Không tìm thấy email này.');
        final token = randomToken(16);
        await db.exec(
          'UPDATE users SET reset_token = :token, reset_expire = DATE_ADD(NOW(), INTERVAL 30 MINUTE) WHERE id = :id',
          {'token': token, 'id': user['id']},
        );
        return _ok({
          'ok': true,
          'message':
              'Đã tạo liên kết đặt lại mật khẩu. Bản demo hiển thị liên kết ngay trên màn hình.',
          'resetToken': token,
          'email': email,
        });
      });

  Future<Response> _reset(Request request) => _guard(() async {
        final data = await _body(request);
        final token = textOf(data['token']);
        final password = textOf(data['password']);
        if (password.length < 6)
          throw ApiException(400, 'Mật khẩu cần ít nhất 6 ký tự.');
        final user = await db.one(
          'SELECT id FROM users WHERE reset_token = :token AND reset_expire > NOW()',
          {'token': token},
        );
        if (user == null)
          throw ApiException(400, 'Liên kết đặt lại mật khẩu đã hết hạn.');
        await db.exec(
          'UPDATE users SET password_hash = :hash, reset_token = NULL, reset_expire = NULL WHERE id = :id',
          {'hash': hashPassword(password), 'id': user['id']},
        );
        await db.exec(
            'DELETE FROM sessions WHERE user_id = :id', {'id': user['id']});
        return _ok(
            {'ok': true, 'message': 'Đã đổi mật khẩu. Hãy đăng nhập lại.'});
      });

  Future<Response> _me(Request request) =>
      _auth(request, (user) async => _ok({'user': user}));

  Future<Response> _updateMe(Request request) => _auth(request, (user) async {
        final data = await _body(request);
        final name = textOf(data['fullName']);
        final phone = canonicalPhone(textOf(data['phone']));
        final gender = textOf(data['gender'], 'other');
        final avatar = data['avatarUrl']?.toString();
        if (name.length < 2) throw ApiException(400, 'Vui lòng nhập họ tên.');
        if (!isValidVnPhone(phone))
          throw ApiException(400, 'Số điện thoại Việt Nam không hợp lệ.');
        if (avatar != null && avatar.length > 350000)
          throw ApiException(400, 'Ảnh đại diện vượt quá 350KB.');
        await db.exec(
          '''UPDATE users SET full_name = :name, phone = :phone, gender = :gender,
             date_of_birth = :dob, address = :address, avatar_url = :avatar WHERE id = :id''',
          {
            'name': name,
            'phone': phone,
            'gender':
                ['male', 'female', 'other'].contains(gender) ? gender : 'other',
            'dob': textOf(data['dateOfBirth']).isEmpty
                ? null
                : textOf(data['dateOfBirth']),
            'address': textOf(data['address']),
            'avatar': avatar,
            'id': user['id'],
          },
        );
        final row = await db
            .one('SELECT * FROM users WHERE id = :id', {'id': user['id']});
        return _ok({'ok': true, 'user': _userJson(row!)});
      });

  Future<Response> _changePassword(Request request) =>
      _auth(request, (user) async {
        final data = await _body(request);
        final current = textOf(data['currentPassword']);
        final next = textOf(data['newPassword']);
        if (next.length < 6)
          throw ApiException(400, 'Mật khẩu mới cần ít nhất 6 ký tự.');
        final row = await db.one(
            'SELECT password_hash FROM users WHERE id = :id',
            {'id': user['id']});
        if (row?['password_hash'] != hashPassword(current))
          throw ApiException(400, 'Mật khẩu hiện tại không đúng.');
        await db.exec('UPDATE users SET password_hash = :hash WHERE id = :id',
            {'hash': hashPassword(next), 'id': user['id']});
        return _ok({'ok': true, 'message': 'Đã đổi mật khẩu.'});
      });

  Future<List<Map<String, dynamic>>> _appointmentsWhere(
      String where, Map<String, dynamic> params) async {
    final rows = await db.query('''
      SELECT a.*, p.name AS package_name, p.tagline, b.name AS branch_name,
             d.full_name AS doctor_name, d.specialty
      FROM appointments a
      JOIN packages p ON p.id = a.package_id
      JOIN branches b ON b.id = a.branch_id
      LEFT JOIN doctors d ON d.id = a.doctor_id
      WHERE $where
      ORDER BY a.appointment_date DESC, a.appointment_time DESC''', params);
    return rows.map(_appointmentJson).toList();
  }

  Future<Response> _myAppointments(Request request) =>
      _auth(request, (user) async {
        final items = await _appointmentsWhere(
            'a.user_id = :id OR a.phone = :phone',
            {'id': user['id'], 'phone': user['phone']});
        return _ok({'appointments': items});
      });

  Future<Map<String, dynamic>> _recordJson(Map<String, String?> row) async {
    final items = await db.query(
      'SELECT * FROM prescription_items WHERE record_id = :id ORDER BY id',
      {'id': row['id']},
    );
    return {
      'id': row['id'],
      'appointmentId': row['appointment_id'],
      'code': row['code'],
      'patientName': row['patient_name'],
      'phone': row['phone'],
      'email': row['email'],
      'gender': row['gender'],
      'packageName': row['package_name'],
      'doctorName': (row['doctor_name'] == null || row['doctor_name']!.isEmpty)
          ? 'Bác sĩ đã nghỉ'
          : row['doctor_name'],
      'branchName': row['branch_name'],
      'date': dateOnly(row['appointment_date']),
      'time': timeOnly(row['appointment_time']),
      'diagnosis': row['diagnosis'] ?? '',
      'treatment': row['treatment'] ?? '',
      'notes': row['notes'] ?? '',
      'status': row['status'],
      'prescription': items
          .map((item) => {
                'id': intOf(item['id']),
                'name': item['medicine_name'],
                'dosage': item['dosage'] ?? '',
                'usage': item['usage_text'] ?? '',
                'days': intOf(item['days']),
                'quantity': item['quantity'] ?? '',
                'note': item['note'] ?? '',
              })
          .toList(),
    };
  }

  Future<Map<String, String?>?> _recordRow(String id) {
    return db.one('''
      SELECT r.*, a.code, a.patient_name, a.phone, a.email, a.gender, a.user_id,
             a.appointment_date, a.appointment_time, p.name AS package_name,
             d.full_name AS doctor_name, b.name AS branch_name
      FROM medical_records r
      JOIN appointments a ON a.id = r.appointment_id
      LEFT JOIN packages p ON p.id = r.package_id
      LEFT JOIN doctors d ON d.id = r.doctor_id
      LEFT JOIN branches b ON b.id = a.branch_id
      WHERE r.id = :id''', {'id': id});
  }

  Future<Response> _myRecords(Request request) => _auth(request, (user) async {
        final rows = await db.query('''
          SELECT r.*, a.code, a.patient_name, a.phone, a.email, a.gender, a.user_id,
                 a.appointment_date, a.appointment_time, p.name AS package_name,
                 d.full_name AS doctor_name, b.name AS branch_name
          FROM medical_records r
          JOIN appointments a ON a.id = r.appointment_id
          LEFT JOIN packages p ON p.id = r.package_id
          LEFT JOIN doctors d ON d.id = r.doctor_id
          LEFT JOIN branches b ON b.id = a.branch_id
          WHERE a.user_id = :id OR a.phone = :phone
          ORDER BY a.appointment_date DESC''',
            {'id': user['id'], 'phone': user['phone']});
        final records = <Map<String, dynamic>>[];
        for (final row in rows) {
          records.add(await _recordJson(row));
        }
        return _ok({'records': records});
      });

  Future<bool> _owns(
      Map<String, dynamic> user, Map<String, String?> row) async {
    return row['user_id'] == user['id'] || row['phone'] == user['phone'];
  }

  Future<Response> _cancelOwn(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _appointmentRow(id);
        if (row == null || !await _owns(user, row))
          throw ApiException(404, 'Không tìm thấy lịch khám.');
        final date = dateOnly(row['appointment_date']);
        final time = timeOnly(row['appointment_time']);
        if (!canModifyAppointment(date, time, row['status']!)) {
          throw ApiException(400,
              'Chỉ hủy trực tiếp trước giờ khám ít nhất 2 giờ. Hãy gửi yêu cầu hỗ trợ.');
        }
        await db.exec(
          '''UPDATE appointments SET status = 'cancelled',
             refund_status = CASE WHEN paid = 1 THEN 'pending' ELSE refund_status END
             WHERE id = :id''',
          {'id': id},
        );
        return _ok({'ok': true, 'message': 'Đã hủy lịch khám.'});
      });

  Future<Response> _reschedule(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _appointmentRow(id);
        if (row == null || !await _owns(user, row))
          throw ApiException(404, 'Không tìm thấy lịch khám.');
        if (!canModifyAppointment(dateOnly(row['appointment_date']),
            timeOnly(row['appointment_time']), row['status']!)) {
          throw ApiException(400, 'Chỉ đổi lịch trước giờ khám ít nhất 2 giờ.');
        }
        final data = await _body(request);
        final date = textOf(data['date']);
        final time = textOf(data['time']);
        final branchId = textOf(data['branchId'], row['branch_id']!);
        if (!timeSlots.contains(time) ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
          throw ApiException(400, 'Ngày hoặc giờ mới không hợp lệ.');
        }
        final slot = slotDateTime(date, time);
        if (slot == null || slot.isBefore(DateTime.now()))
          throw ApiException(400, 'Khung giờ này đã qua.');
        final doctorId = await _assignDoctor(branchId,
            textOf(data['doctorId'], row['doctor_id']!), date, time, id);
        await db.exec(
          '''UPDATE appointments SET appointment_date = :date, appointment_time = :time,
             branch_id = :branch, doctor_id = :doctor WHERE id = :id''',
          {
            'date': date,
            'time': '$time:00',
            'branch': branchId,
            'doctor': doctorId,
            'id': id
          },
        );
        final updated = await _appointmentRow(id);
        return _ok({'ok': true, 'appointment': _appointmentJson(updated!)});
      });

  Future<Response> _supportCancel(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _appointmentRow(id);
        if (row == null || !await _owns(user, row))
          throw ApiException(404, 'Không tìm thấy lịch khám.');
        if (row['status'] == 'cancelled' || row['status'] == 'completed') {
          throw ApiException(400, 'Lịch này không thể gửi yêu cầu hủy.');
        }
        final data = await _body(request);
        final reason = textOf(data['reason']);
        if (reason.length < 5)
          throw ApiException(400, 'Nhập lý do cần hỗ trợ hủy lịch.');
        await db.exec(
          '''UPDATE appointments SET cancel_request_status = 'open', cancel_request_reason = :reason,
             cancel_request_at = NOW() WHERE id = :id''',
          {'reason': reason, 'id': id},
        );
        return _ok(
            {'ok': true, 'message': 'Đã gửi yêu cầu hủy tới phòng khám.'});
      });

  Future<Response> _pay(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _appointmentRow(id);
        if (row == null || !await _owns(user, row))
          throw ApiException(404, 'Không tìm thấy lịch khám.');
        if (row['status'] == 'cancelled')
          throw ApiException(400, 'Lịch đã hủy, không thể thanh toán.');
        if (row['payment_method'] == 'cash')
          throw ApiException(400, 'Lịch tiền mặt được thu tại quầy.');
        await db.exec(
          "UPDATE appointments SET paid = 1, status = IF(status = 'pending', 'confirmed', status) WHERE id = :id",
          {'id': id},
        );
        return _ok({'ok': true, 'message': 'Đã ghi nhận thanh toán.'});
      });

  Future<Response> _record(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _recordRow(id);
        if (row == null) throw ApiException(404, 'Không tìm thấy hồ sơ.');
        final allowed = user['role'] == 'doctor'
            ? user['doctorId'] != null && row['doctor_id'] == user['doctorId']
            : user['role'] == 'admin' ||
                row['user_id'] == user['id'] ||
                row['phone'] == user['phone'];
        if (!allowed) throw ApiException(403, 'Bạn không được xem hồ sơ này.');
        return _ok({'record': await _recordJson(row)});
      });

  Future<Response> _patients(Request request) => _auth(request, (user) async {
        final rows = await db.query('''
          SELECT a.phone, a.patient_name, a.email, a.gender, a.user_id,
                 COUNT(*) AS visits, MAX(a.appointment_date) AS last_date
          FROM appointments a
          WHERE (:admin = 1 OR a.doctor_id = :doctor)
          GROUP BY a.phone, a.patient_name, a.email, a.gender, a.user_id
          ORDER BY last_date DESC''', {
          'admin': user['role'] == 'admin' ? 1 : 0,
          'doctor': user['doctorId']
        });
        return _ok({
          'patients': rows
              .map((row) => {
                    'phone': row['phone'],
                    'patientName': row['patient_name'],
                    'email': row['email'],
                    'gender': row['gender'],
                    'userId': row['user_id'],
                    'visits': intOf(row['visits']),
                    'lastDate': dateOnly(row['last_date']),
                  })
              .toList(),
        });
      }, roles: ['admin', 'doctor']);

  Future<Response> _clinicalAppointments(Request request) =>
      _auth(request, (user) async {
        final text = textOf(request.url.queryParameters['q']);
        final where = <String>['1 = 1'];
        final params = <String, dynamic>{};
        if (user['role'] == 'doctor') {
          where.add('a.doctor_id = :doctor');
          params['doctor'] = user['doctorId'];
        }
        if (text.isNotEmpty) {
          where.add(
              "(a.code LIKE :q OR a.patient_name LIKE :q OR a.phone LIKE :q)");
          params['q'] = '%$text%';
        }
        final items = await _appointmentsWhere(where.join(' AND '), params);
        return _ok({'appointments': items});
      }, roles: ['admin', 'doctor']);

  Future<Response> _today(Request request) => _auth(request, (user) async {
        final rows = await _appointmentsWhere(
            "a.appointment_date = CURDATE() AND a.status <> 'cancelled' AND (:admin = 1 OR a.doctor_id = :doctor)",
            {
              'admin': user['role'] == 'admin' ? 1 : 0,
              'doctor': user['doctorId']
            });
        return _ok({'appointments': rows});
      }, roles: ['admin', 'doctor']);

  Future<Response> _saveRecord(Request request) => _auth(request, (user) async {
        final data = await _body(request);
        final appointmentId = textOf(data['appointmentId']);
        final appointment = await _appointmentRow(appointmentId);
        if (appointment == null)
          throw ApiException(404, 'Không tìm thấy lịch khám.');
        if (user['role'] == 'doctor' &&
            (user['doctorId'] == null ||
                appointment['doctor_id'] != user['doctorId'])) {
          throw ApiException(
              403, 'Bạn chỉ được lập hồ sơ và kê đơn cho lịch khám của mình.');
        }
        if (appointment['status'] == 'cancelled')
          throw ApiException(400, 'Không thể lập hồ sơ cho lịch đã hủy.');
        final diagnosis = textOf(data['diagnosis']);
        final treatment = textOf(data['treatment']);
        final notes = textOf(data['notes']);
        final status = textOf(data['status'], 'examining');
        if (!['new', 'examining', 'completed'].contains(status))
          throw ApiException(400, 'Trạng thái hồ sơ không hợp lệ.');
        if (diagnosis.isEmpty) throw ApiException(400, 'Nhập chẩn đoán.');
        final rawItems = data['prescription'];
        final items = <Map<String, String>>[];
        if (rawItems is List) {
          for (final item in rawItems) {
            if (item is! Map) continue;
            final name = textOf(item['name']);
            if (name.isEmpty) continue;
            if (intOf(item['days']) < 1 ||
                textOf(item['dosage']).isEmpty ||
                textOf(item['usage']).isEmpty ||
                textOf(item['quantity']).isEmpty) {
              throw ApiException(400,
                  'Mỗi thuốc cần liều dùng, cách dùng, số lượng và số ngày hợp lệ.');
            }
            items.add({
              'name': name,
              'dosage': textOf(item['dosage']),
              'usage': textOf(item['usage']),
              'days': '${intOf(item['days'])}',
              'quantity': textOf(item['quantity']),
              'note': textOf(item['note']),
            });
          }
        }
        if (isDuplicateMedicine(items))
          throw ApiException(409, 'Thuốc này đã có trong đơn.');
        final existing = await db.one(
            'SELECT id FROM medical_records WHERE appointment_id = :id',
            {'id': appointmentId});
        final recordId = existing?['id'] ?? 'rec-${randomToken(4)}';
        if (existing == null) {
          await db.exec(
            '''INSERT INTO medical_records
               (id, appointment_id, patient_user_id, doctor_id, package_id, diagnosis, treatment, notes, status, updated_at)
               VALUES (:id, :apt, :userId, :doctor, :package, :diagnosis, :treatment, :notes, :status, NOW())''',
            {
              'id': recordId,
              'apt': appointmentId,
              'userId': appointment['user_id'],
              'doctor': user['doctorId'] ?? appointment['doctor_id'],
              'package': appointment['package_id'],
              'diagnosis': diagnosis,
              'treatment': treatment,
              'notes': notes,
              'status': status,
            },
          );
        } else {
          await db.exec(
            '''UPDATE medical_records SET diagnosis = :diagnosis, treatment = :treatment, notes = :notes,
               status = :status, doctor_id = :doctor, updated_at = NOW() WHERE id = :id''',
            {
              'diagnosis': diagnosis,
              'treatment': treatment,
              'notes': notes,
              'status': status,
              'doctor': user['doctorId'] ?? appointment['doctor_id'],
              'id': recordId,
            },
          );
          await db.exec('DELETE FROM prescription_items WHERE record_id = :id',
              {'id': recordId});
        }
        for (final item in items) {
          await db.exec(
            '''INSERT INTO prescription_items (record_id, medicine_name, dosage, usage_text, days, quantity, note)
               VALUES (:record, :name, :dosage, :usage, :days, :quantity, :note)''',
            {
              'record': recordId,
              'name': item['name'],
              'dosage': item['dosage'],
              'usage': item['usage'],
              'days': intOf(item['days']),
              'quantity': item['quantity'],
              'note': item['note'],
            },
          );
        }
        if (status == 'completed') {
          await db.exec(
              "UPDATE appointments SET status = 'completed' WHERE id = :id AND status <> 'cancelled'",
              {'id': appointmentId});
        }
        await _log(user, 'Lưu hồ sơ', '${appointment['code']} - $status');
        final saved = await _recordRow(recordId);
        return _ok({'ok': true, 'record': await _recordJson(saved!)});
      }, roles: ['admin', 'doctor']);

  Future<Response> _deleteRecord(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _recordRow(id);
        if (row == null) throw ApiException(404, 'Không tìm thấy hồ sơ.');
        await db.exec('DELETE FROM medical_records WHERE id = :id', {'id': id});
        await db.exec(
          "UPDATE appointments SET status = 'confirmed' WHERE id = :id AND status = 'completed'",
          {'id': row['appointment_id']},
        );
        await _log(user, 'Xóa hồ sơ', row['code'] ?? id);
        return _ok({'ok': true});
      }, roles: ['admin']);

  Future<Response> _overview(Request request) => _auth(request, (user) async {
        final today = await db.one(
            "SELECT COUNT(*) AS c FROM appointments WHERE appointment_date = CURDATE() AND status <> 'cancelled'");
        final records = await db.one(
            "SELECT COUNT(*) AS c FROM medical_records WHERE status = 'completed'");
        final month = await db.one('''
          SELECT COALESCE(SUM($_netRevenue), 0) AS amount FROM appointments
          WHERE YEAR(appointment_date) = YEAR(CURDATE()) AND MONTH(appointment_date) = MONTH(CURDATE())''');
        final todayMoney = await db.one('''
          SELECT COALESCE(SUM($_netRevenue), 0) AS amount FROM appointments
          WHERE appointment_date = CURDATE()''');
        final recent = await _appointmentsWhere('1 = 1', {});
        final logs = await db
            .query('SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 8');
        return _ok({
          'todayAppointments': intOf(today?['c']),
          'completedRecords': intOf(records?['c']),
          'monthRevenue': intOf(month?['amount']),
          'todayRevenue': intOf(todayMoney?['amount']),
          'recent': recent.take(8).toList(),
          'logs': logs.map(_logJson).toList(),
        });
      }, roles: ['admin']);

  Map<String, dynamic> _logJson(Map<String, String?> row) => {
        'id': row['id'],
        'actorName': row['actor_name'],
        'action': row['action'],
        'detail': row['detail'],
        'createdAt': row['created_at'],
      };

  Future<Response> _revenue(Request request) => _auth(request, (user) async {
        final month = request.url.queryParameters['month'];
        final now = DateTime.now();
        if (month != null &&
            !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) {
          throw ApiException(400, 'Tháng không hợp lệ.');
        }
        final start = month == null
            ? DateTime(now.year, now.month)
            : DateTime.parse('$month-01');
        final end = DateTime(start.year, start.month + 1);
        final rows = await db.query('''
          SELECT appointment_date AS revenue_date,
                 SUM($_netRevenue) AS amount,
                 COUNT(*) AS appointment_count
          FROM appointments
          WHERE paid = 1 AND appointment_date >= :start AND appointment_date < :end
          GROUP BY appointment_date
          ORDER BY appointment_date''', {
          'start': dateOnly(start.toIso8601String()),
          'end': dateOnly(end.toIso8601String())
        });

        final monthRows = await db.query('''
          SELECT DATE_FORMAT(appointment_date, '%Y-%m') AS revenue_month,
                 SUM($_netRevenue) AS amount,
                 COUNT(*) AS appointment_count
          FROM appointments
          WHERE paid = 1 AND appointment_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
          GROUP BY DATE_FORMAT(appointment_date, '%Y-%m')
          ORDER BY revenue_month''');

        return _ok({
          'days': rows
              .map((row) => {
                    'date': dateOnly(row['revenue_date']),
                    'amount': intOf(row['amount']),
                    'count': intOf(row['appointment_count']),
                  })
              .toList(),
          'months': monthRows
              .map((row) => {
                    'month': row['revenue_month'],
                    'amount': intOf(row['amount']),
                    'count': intOf(row['appointment_count']),
                  })
              .toList(),
        });
      }, roles: ['admin']);

  Future<Response> _adminAppointments(Request request) =>
      _auth(request, (user) async {
        final query = request.url.queryParameters;
        final text = textOf(query['q']);
        final branch = textOf(query['branchId']);
        final status = textOf(query['status']);
        final where = <String>['1 = 1'];
        final params = <String, dynamic>{};
        if (text.isNotEmpty) {
          where.add(
              "(a.code LIKE :q OR a.patient_name LIKE :q OR a.phone LIKE :q)");
          params['q'] = '%$text%';
        }
        if (branch.isNotEmpty) {
          where.add('a.branch_id = :branch');
          params['branch'] = branch;
        }
        if (status.isNotEmpty) {
          where.add('a.status = :status');
          params['status'] = status;
        }
        final items = await _appointmentsWhere(where.join(' AND '), params);
        return _ok({'appointments': items});
      }, roles: ['admin']);

  Future<Response> _adminCancel(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _appointmentRow(id);
        if (row == null) throw ApiException(404, 'Không tìm thấy lịch khám.');
        await db.exec(
          '''UPDATE appointments SET status = 'cancelled', cancel_request_status = IF(cancel_request_status = 'open', 'approved', cancel_request_status),
             refund_status = CASE WHEN paid = 1 THEN 'pending' ELSE refund_status END WHERE id = :id''',
          {'id': id},
        );
        await _log(user, 'Hủy lịch', row['code'] ?? id);
        return _ok({'ok': true, 'message': 'Đã hủy lịch khám.'});
      }, roles: ['admin']);

  Future<Response> _adminDeleteAppointment(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _appointmentRow(id);
        if (row == null) throw ApiException(404, 'Không tìm thấy lịch khám.');
        if (row['status'] != 'cancelled' && row['status'] != 'completed') {
          throw ApiException(
              400, 'Chỉ xóa lịch đã hủy hoặc đã hoàn thành khám.');
        }
        await db.exec(
            'DELETE FROM prescription_items WHERE record_id IN (SELECT id FROM medical_records WHERE appointment_id = :id)',
            {'id': id});
        await db.exec('DELETE FROM medical_records WHERE appointment_id = :id',
            {'id': id});
        await db.exec('DELETE FROM appointments WHERE id = :id', {'id': id});
        await _log(user, 'Xóa lịch', '${row['code']} (${row['status']})');
        return _ok({'ok': true, 'message': 'Đã xóa lịch khám thành công.'});
      }, roles: ['admin']);

  Future<Response> _adminSetAppointmentStatus(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _appointmentRow(id);
        if (row == null) throw ApiException(404, 'Không tìm thấy lịch khám.');
        final data = await _body(request);
        final status = textOf(data['status']);
        if (!['pending', 'confirmed', 'completed', 'cancelled']
            .contains(status)) {
          throw ApiException(400, 'Trạng thái không hợp lệ.');
        }

        if (status == 'cancelled') {
          await db.exec(
            '''UPDATE appointments SET status = 'cancelled',
               cancel_request_status = IF(cancel_request_status = 'open', 'approved', cancel_request_status),
               refund_status = CASE WHEN paid = 1 THEN 'pending' ELSE refund_status END
               WHERE id = :id''',
            {'id': id},
          );
        } else {
          await db.exec(
              'UPDATE appointments SET status = :status WHERE id = :id',
              {'status': status, 'id': id});
        }
        await _log(
            user, 'Đổi trạng thái lịch khám', '${row['code']} -> $status');
        return _ok({
          'ok': true,
          'message': 'Đã cập nhật trạng thái lịch khám thành công.'
        });
      }, roles: ['admin']);

  Future<Response> _adminPay(Request request, String id) =>
      _auth(request, (user) async {
        await db.exec(
          "UPDATE appointments SET paid = 1, status = IF(status = 'pending', 'confirmed', status) WHERE id = :id AND status <> 'cancelled'",
          {'id': id},
        );
        await _log(user, 'Xác nhận thanh toán', id);
        return _ok({'ok': true, 'message': 'Đã xác nhận thanh toán.'});
      }, roles: ['admin']);

  Future<Response> _rejectCancel(Request request, String id) =>
      _auth(request, (user) async {
        await db.exec(
          "UPDATE appointments SET cancel_request_status = 'rejected' WHERE id = :id",
          {'id': id},
        );
        await _log(user, 'Từ chối hủy', id);
        return _ok({'ok': true, 'message': 'Đã từ chối yêu cầu hủy.'});
      }, roles: ['admin']);

  Future<Response> _refund(Request request, String id) =>
      _auth(request, (user) async {
        final row = await _appointmentRow(id);
        if (row == null) throw ApiException(404, 'Không tìm thấy lịch khám.');
        final json = _appointmentJson(row);
        if (!isRefundable(json))
          throw ApiException(400, 'Lịch này không ở trạng thái chờ hoàn tiền.');
        await db.exec(
          '''UPDATE appointments SET refund_status = 'done', refund_amount = amount, refunded_at = NOW()
             WHERE id = :id''',
          {'id': id},
        );
        await _log(user, 'Hoàn tiền', row['code'] ?? id);
        return _ok({'ok': true, 'message': 'Đã hoàn tiền.'});
      }, roles: ['admin']);

  Future<Response> _createDoctor(Request request) =>
      _auth(request, (user) async {
        final data = await _body(request);
        final name = textOf(data['fullName']);
        final specialty = textOf(data['specialty']);
        final branchId = textOf(data['branchId']);
        final email = textOf(data['email']).toLowerCase();
        final avatar = data['avatarUrl']?.toString();
        final createAccount = data['createAccount'] == true;
        var phone = canonicalPhone(textOf(data['phone']));
        var password = textOf(data['password']);

        if (name.length < 2 || specialty.isEmpty || !isValidEmail(email)) {
          throw ApiException(400, 'Nhập đủ tên, chuyên khoa và email bác sĩ.');
        }
        if (avatar != null && avatar.length > 350000)
          throw ApiException(400, 'Ảnh đại diện vượt quá 350KB.');
        final branch = await db
            .one('SELECT id FROM branches WHERE id = :id', {'id': branchId});
        if (branch == null) throw ApiException(400, 'Cơ sở không tồn tại.');

        final doctorId = 'doc-${randomToken(3)}';

        String? userId;
        final existing = await db
            .one("SELECT id FROM users WHERE email = :email", {'email': email});
        if (existing != null) {
          userId = existing['id'];
          await db.exec(
              "UPDATE users SET role = 'doctor', doctor_id = :doc WHERE id = :id",
              {'doc': doctorId, 'id': userId});
        } else if (createAccount) {
          if (phone.isEmpty)
            phone = '09' +
                (10000000 + DateTime.now().millisecondsSinceEpoch % 90000000)
                    .toString();
          if (password.isEmpty) password = 'Doctor@123';
          userId = 'user-${randomToken(4)}';
          await db.exec(
            '''INSERT INTO users (id, full_name, email, phone, password_hash, role, doctor_id, verified)
               VALUES (:id, :name, :email, :phone, :hash, 'doctor', :doc, 1)''',
            {
              'id': userId,
              'name': name,
              'email': email,
              'phone': phone,
              'hash': hashPassword(password),
              'doc': doctorId,
            },
          );
        }

        await db.exec(
          '''INSERT INTO doctors (id, user_id, branch_id, full_name, specialty, email, avatar_url, bio)
             VALUES (:id, :userId, :branch, :name, :specialty, :email, :avatar, :bio)''',
          {
            'id': doctorId,
            'userId': userId,
            'branch': branchId,
            'name': name,
            'specialty': specialty,
            'email': email,
            'avatar': avatar,
            'bio': textOf(data['bio']),
          },
        );
        await _log(user, 'Thêm bác sĩ', '$name ($email)');
        return _ok({'ok': true, 'id': doctorId, 'userId': userId}, 201);
      }, roles: ['admin']);

  Future<Response> _createDoctorAccount(Request request, String id) =>
      _auth(request, (user) async {
        final doctor =
            await db.one('SELECT * FROM doctors WHERE id = :id', {'id': id});
        if (doctor == null) throw ApiException(404, 'Không tìm thấy bác sĩ.');
        final data = await _body(request);
        var phone = canonicalPhone(textOf(data['phone']));
        var password = textOf(data['password']);
        if (password.isEmpty) password = 'Doctor@123';
        if (password.length < 6)
          throw ApiException(400, 'Mật khẩu cần ít nhất 6 ký tự.');

        final email = doctor['email']!.toLowerCase();
        final name = doctor['full_name']!;

        final existing = await db.one(
            'SELECT id, role FROM users WHERE email = :email',
            {'email': email});
        String userId;
        if (existing != null) {
          userId = existing['id']!;
          await db.exec(
            "UPDATE users SET role = 'doctor', doctor_id = :doc, password_hash = :hash, verified = 1 WHERE id = :id",
            {'doc': id, 'hash': hashPassword(password), 'id': userId},
          );
        } else {
          if (phone.isEmpty)
            phone = '09' +
                (10000000 + DateTime.now().millisecondsSinceEpoch % 90000000)
                    .toString();
          if (!isValidVnPhone(phone))
            throw ApiException(400, 'Số điện thoại không hợp lệ.');
          userId = 'user-${randomToken(4)}';
          await db.exec(
            '''INSERT INTO users (id, full_name, email, phone, password_hash, role, doctor_id, verified)
               VALUES (:id, :name, :email, :phone, :hash, 'doctor', :doc, 1)''',
            {
              'id': userId,
              'name': name,
              'email': email,
              'phone': phone,
              'hash': hashPassword(password),
              'doc': id,
            },
          );
        }
        await db.exec('UPDATE doctors SET user_id = :userId WHERE id = :id',
            {'userId': userId, 'id': id});
        await _log(user, 'Cấp tài khoản bác sĩ', '$name ($email)');
        return _ok({
          'ok': true,
          'message':
              'Đã cấp tài khoản cho bác sĩ $name thành công (Mật khẩu: $password).',
          'userId': userId
        });
      }, roles: ['admin']);

  Future<Response> _updateDoctor(Request request, String id) =>
      _auth(request, (user) async {
        final data = await _body(request);
        final doctor =
            await db.one('SELECT * FROM doctors WHERE id = :id', {'id': id});
        if (doctor == null) throw ApiException(404, 'Không tìm thấy bác sĩ.');
        final password = textOf(data['password']);
        if (password.isNotEmpty && password.length < 6)
          throw ApiException(400, 'Mật khẩu cần ít nhất 6 ký tự.');
        final email = textOf(data['email']).toLowerCase();
        final account = await db.one(
          "SELECT id FROM users WHERE role = 'doctor' AND (id = :user OR doctor_id = :doctor) LIMIT 1",
          {'user': doctor['user_id'], 'doctor': id},
        );
        if (account != null || password.isNotEmpty) {
          final duplicate = await db.one(
              'SELECT id FROM users WHERE email = :email', {'email': email});
          if (duplicate != null && duplicate['id'] != account?['id']) {
            throw ApiException(
                409, 'Email đã được sử dụng bởi tài khoản khác.');
          }
        }
        final avatar = data['avatarUrl']?.toString();
        if (avatar != null && avatar.length > 350000)
          throw ApiException(400, 'Ảnh đại diện vượt quá 350KB.');
        await db.exec(
          '''UPDATE doctors SET full_name = :name, specialty = :specialty, branch_id = :branch,
             email = :email, bio = :bio, avatar_url = :avatar WHERE id = :id''',
          {
            'name': textOf(data['fullName']),
            'specialty': textOf(data['specialty']),
            'branch': textOf(data['branchId']),
            'email': textOf(data['email']).toLowerCase(),
            'bio': textOf(data['bio']),
            'avatar': avatar,
            'id': id,
          },
        );
        if (account != null) {
          await db.exec(
              'UPDATE users SET full_name = :name, email = :email WHERE id = :id',
              {
                'name': textOf(data['fullName']),
                'email': email,
                'id': account['id']
              });
          if (password.isNotEmpty) {
            await db.exec(
                'UPDATE users SET password_hash = :hash, reset_token = NULL, reset_expire = NULL WHERE id = :id',
                {'hash': hashPassword(password), 'id': account['id']});
          }
        } else if (password.isNotEmpty) {
          final userId = 'user-${randomToken(4)}';
          await db.exec(
            '''INSERT INTO users (id, full_name, email, phone, password_hash, role, doctor_id, verified)
               VALUES (:id, :name, :email, '', :hash, 'doctor', :doc, 1)''',
            {
              'id': userId,
              'name': textOf(data['fullName']),
              'email': email,
              'hash': hashPassword(password),
              'doc': id
            },
          );
          await db.exec('UPDATE doctors SET user_id = :user WHERE id = :id',
              {'user': userId, 'id': id});
        }
        await _log(user, 'Cập nhật bác sĩ', textOf(data['fullName']));
        return _ok({'ok': true});
      }, roles: ['admin']);

  Future<Response> _deleteDoctor(Request request, String id) =>
      _auth(request, (user) async {
        final future = await db.one(
          '''SELECT COUNT(*) AS c FROM appointments
             WHERE doctor_id = :id AND status IN ('pending', 'confirmed') AND appointment_date >= CURDATE()''',
          {'id': id},
        );
        if (!canDeleteDoctor(hasFutureAppointment: intOf(future?['c']) > 0)) {
          throw ApiException(
              400, 'Bác sĩ còn lịch chưa hoàn thành, chưa thể xóa.');
        }
        await db.exec('UPDATE users SET doctor_id = NULL WHERE doctor_id = :id',
            {'id': id});
        await db.exec(
            'UPDATE medical_records SET doctor_id = NULL WHERE doctor_id = :id',
            {'id': id});
        await db.exec(
            'UPDATE appointments SET doctor_id = NULL WHERE doctor_id = :id',
            {'id': id});
        final count =
            await db.exec('DELETE FROM doctors WHERE id = :id', {'id': id});
        if (count == 0) throw ApiException(404, 'Không tìm thấy bác sĩ.');
        await _log(user, 'Xóa bác sĩ', id);
        return _ok({'ok': true});
      }, roles: ['admin']);

  Future<Response> _users(Request request) => _auth(request, (user) async {
        final rows = user['role'] == 'doctor'
            ? await db.query(
                '''SELECT u.* FROM users u WHERE u.role = 'user' AND EXISTS (
                 SELECT 1 FROM appointments a WHERE a.user_id = u.id AND a.doctor_id = :doctor
               ) ORDER BY u.created_at DESC''', {'doctor': user['doctorId']})
            : await db.query('SELECT * FROM users ORDER BY created_at DESC');
        return _ok({'users': rows.map(_userJson).toList()});
      }, roles: ['admin', 'doctor']);

  Future<Response> _createPatient(Request request) =>
      _auth(request, (user) async {
        final data = await _body(request);
        final name = textOf(data['fullName']);
        final email = textOf(data['email']).toLowerCase();
        final phone = canonicalPhone(textOf(data['phone']));
        var password = textOf(data['password']);
        final gender = textOf(data['gender'], 'other');
        final dob = textOf(data['dateOfBirth']).isEmpty
            ? null
            : textOf(data['dateOfBirth']);
        final address = textOf(data['address']);

        if (name.length < 2)
          throw ApiException(400, 'Vui lòng nhập họ tên bệnh nhân.');
        if (!isValidEmail(email))
          throw ApiException(400, 'Email không hợp lệ.');
        if (!isValidVnPhone(phone))
          throw ApiException(400, 'Số điện thoại Việt Nam không hợp lệ.');
        if (password.isEmpty) {
          password = 'User@123';
        } else if (password.length < 6) {
          throw ApiException(400, 'Mật khẩu cần ít nhất 6 ký tự.');
        }

        final exists = await db
            .one('SELECT id FROM users WHERE email = :email', {'email': email});
        if (exists != null)
          throw ApiException(409, 'Email này đã được đăng ký.');

        final newId = 'user-${randomToken(4)}';
        await db.exec(
          '''INSERT INTO users (id, full_name, email, phone, password_hash, role, gender, date_of_birth, address, verified)
             VALUES (:id, :name, :email, :phone, :hash, 'user', :gender, :dob, :address, 1)''',
          {
            'id': newId,
            'name': name,
            'email': email,
            'phone': phone,
            'hash': hashPassword(password),
            'gender':
                ['male', 'female', 'other'].contains(gender) ? gender : 'other',
            'dob': dob,
            'address': address,
          },
        );
        await _log(user, 'Tạo tài khoản bệnh nhân', '$name ($email)');
        return _ok({
          'ok': true,
          'message': 'Đã tạo tài khoản bệnh nhân thành công.',
          'id': newId
        });
      }, roles: ['admin', 'doctor']);

  Future<int> _adminCount() async {
    final row =
        await db.one("SELECT COUNT(*) AS c FROM users WHERE role = 'admin'");
    return intOf(row?['c']);
  }

  Future<Response> _setRole(Request request, String id) =>
      _auth(request, (user) async {
        if (id == user['id'])
          throw ApiException(400, 'Không thể đổi vai trò của chính mình.');
        final data = await _body(request);
        final role = textOf(data['role']);
        if (!['admin', 'doctor', 'user'].contains(role))
          throw ApiException(400, 'Vai trò không hợp lệ.');
        final target =
            await db.one('SELECT * FROM users WHERE id = :id', {'id': id});
        if (target == null)
          throw ApiException(404, 'Không tìm thấy tài khoản.');
        if (target['role'] == 'admin' &&
            role != 'admin' &&
            await _adminCount() <= 1) {
          throw ApiException(400, 'Không thể đổi vai trò admin cuối cùng.');
        }
        await db.exec(
          "UPDATE users SET role = :role, doctor_id = IF(:role = 'doctor', doctor_id, NULL) WHERE id = :id",
          {'role': role, 'id': id},
        );
        await _log(user, 'Đổi vai trò', '${target['email']} -> $role');
        return _ok({'ok': true});
      }, roles: ['admin']);

  Future<Response> _lock(Request request, String id) =>
      _auth(request, (user) async {
        final data = await _body(request);
        final reason = textOf(data['reason']);
        if (!canLockAccount(isSelf: id == user['id'], reason: reason)) {
          throw ApiException(
              400,
              id == user['id']
                  ? 'Không thể tự khóa tài khoản đang đăng nhập.'
                  : 'Nhập lý do khóa.');
        }
        final count = await db.exec(
          'UPDATE users SET locked = 1, lock_reason = :reason WHERE id = :id',
          {'reason': reason, 'id': id},
        );
        if (count == 0) throw ApiException(404, 'Không tìm thấy tài khoản.');
        await db.exec('DELETE FROM sessions WHERE user_id = :id', {'id': id});
        await _log(user, 'Khóa tài khoản', reason);
        return _ok({'ok': true});
      }, roles: ['admin']);

  Future<Response> _unlock(Request request, String id) =>
      _auth(request, (user) async {
        await db.exec(
            'UPDATE users SET locked = 0, lock_reason = NULL WHERE id = :id',
            {'id': id});
        await _log(user, 'Mở khóa tài khoản', id);
        return _ok({'ok': true});
      }, roles: ['admin']);

  Future<Response> _deleteUser(Request request, String id) =>
      _auth(request, (user) async {
        final target =
            await db.one('SELECT * FROM users WHERE id = :id', {'id': id});
        if (target == null)
          throw ApiException(404, 'Không tìm thấy tài khoản.');
        final future = await db.one(
          '''SELECT COUNT(*) AS c FROM appointments
             WHERE user_id = :id AND status IN ('pending', 'confirmed') AND appointment_date >= CURDATE()''',
          {'id': id},
        );
        if (!canDeleteAccount(
          isSelf: id == user['id'],
          role: target['role']!,
          adminCount: await _adminCount(),
          hasFutureAppointment: intOf(future?['c']) > 0,
        )) {
          throw ApiException(400, 'Không thể xóa tài khoản này.');
        }
        await db.exec('UPDATE doctors SET user_id = NULL WHERE user_id = :id',
            {'id': id});
        await db.exec(
            'UPDATE appointments SET user_id = NULL WHERE user_id = :id',
            {'id': id});
        await db.exec('DELETE FROM users WHERE id = :id', {'id': id});
        await _log(user, 'Xóa tài khoản', target['email'] ?? id);
        return _ok({'ok': true});
      }, roles: ['admin']);

  Future<Response> _logs(Request request) => _auth(request, (user) async {
        final rows = await db.query(
            'SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 100');
        return _ok({'logs': rows.map(_logJson).toList()});
      }, roles: ['admin', 'doctor']);

  Future<Response> _medicines(Request request) => _auth(request, (user) async {
        final groups =
            await db.query('SELECT name FROM disease_groups ORDER BY name');
        final meds = await db
            .query('SELECT * FROM medicines ORDER BY disease_group, name');
        return _ok({
          'groups': groups.map((row) => row['name']).toList(),
          'medicines': meds
              .map((row) => {
                    'id': row['id'],
                    'group': row['disease_group'],
                    'name': row['name'],
                    'dosage': row['dosage'],
                    'usage': row['usage_text'],
                  })
              .toList(),
        });
      }, roles: ['admin', 'doctor']);

  Future<Response> _addGroup(Request request) => _auth(request, (user) async {
        final data = await _body(request);
        final name = textOf(data['name']);
        if (name.length < 2) throw ApiException(400, 'Nhập tên nhóm bệnh.');
        await db.exec('INSERT IGNORE INTO disease_groups (name) VALUES (:name)',
            {'name': name});
        await _log(user, 'Thêm nhóm bệnh', name);
        return _ok({'ok': true});
      }, roles: ['admin']);

  Future<Response> _addMedicine(Request request) =>
      _auth(request, (user) async {
        final data = await _body(request);
        final name = textOf(data['name']);
        final group = textOf(data['group']);
        final dosage = textOf(data['dosage']);
        final usage = textOf(data['usage']);
        if (name.isEmpty || group.isEmpty || dosage.isEmpty)
          throw ApiException(400, 'Nhập nhóm bệnh, tên thuốc và hàm lượng.');
        await db.exec('INSERT IGNORE INTO disease_groups (name) VALUES (:name)',
            {'name': group});
        await db.exec(
          '''INSERT INTO medicines (id, disease_group, name, dosage, usage_text)
             VALUES (:id, :group, :name, :dosage, :usage)''',
          {
            'id': 'med-${randomToken(3)}',
            'group': group,
            'name': name,
            'dosage': dosage,
            'usage': usage
          },
        );
        await _log(user, 'Thêm thuốc', '$name $dosage');
        return _ok({'ok': true});
      }, roles: ['admin']);

  Future<Response> _detachMedicine(Request request, String id) =>
      _auth(request, (user) async {
        await db.exec(
            "UPDATE medicines SET disease_group = 'Chưa phân loại' WHERE id = :id",
            {'id': id});
        return _ok({'ok': true, 'message': 'Đã gỡ thuốc khỏi nhóm bệnh.'});
      }, roles: ['admin']);

  Future<Response> _deleteMedicine(Request request, String id) =>
      _auth(request, (user) async {
        await db.exec('DELETE FROM medicines WHERE id = :id', {'id': id});
        await _log(user, 'Xóa thuốc', id);
        return _ok({'ok': true});
      }, roles: ['admin']);
}
