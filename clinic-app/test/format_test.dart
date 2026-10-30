import 'package:cliniccare/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('định dạng tiền và ngày', () {
    expect(formatVnd(846000), '846.000đ');
    expect(formatVnd(8995000), '8.995.000đ');
    expect(formatDate('2026-10-21'), '21/10/2026');
  });

  test('số điện thoại và email', () {
    expect(canonicalPhone('+84 912 345 678'), '0912345678');
    expect(isValidVnPhone('0912345678'), isTrue);
    expect(isValidVnPhone('0123456789'), isFalse);
    expect(isValidEmail('user@cliniccare.vn'), isTrue);
  });

  test('hủy lịch trước 2 giờ và thuốc trùng', () {
    final appointment = {'status': 'confirmed', 'date': '2026-10-21', 'time': '16:00'};
    expect(canModifyAppointment(appointment, DateTime(2026, 10, 21, 13)), isTrue);
    expect(canModifyAppointment(appointment, DateTime(2026, 10, 21, 15)), isFalse);
    expect(
      isDuplicateMedicine([
        {'name': 'Paracetamol', 'dosage': '500mg'},
        {'name': ' paracetamol ', 'dosage': '500MG'},
      ]),
      isTrue,
    );
  });
}
