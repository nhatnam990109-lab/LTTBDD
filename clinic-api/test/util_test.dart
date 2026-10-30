import 'package:clinic_api/util.dart';
import 'package:test/test.dart';

void main() {
  test('định dạng tiền Việt Nam', () {
    expect(formatVnd(846000), '846.000đ');
    expect(formatVnd(8995000), '8.995.000đ');
    expect(formatVnd(0), '0đ');
  });

  test('số điện thoại Việt Nam', () {
    expect(isValidVnPhone('0912345678'), isTrue);
    expect(canonicalPhone('+84912345678'), '0912345678');
    expect(canonicalPhone('84 912 345 678'), '0912345678');
    expect(isValidVnPhone('0123456789'), isFalse);
    expect(isValidVnPhone('091234567'), isFalse);
  });

  test('email', () {
    expect(isValidEmail('user@cliniccare.vn'), isTrue);
    expect(isValidEmail('khong-dung'), isFalse);
  });

  test('mã lịch và hủy trước 2 giờ', () {
    final code = 'CC-${randomCode(6)}';
    expect(RegExp(r'^CC-[A-Z2-9]{6}$').hasMatch(code), isTrue);
    expect(canModifyAppointment('2026-10-21', '16:00', 'confirmed', DateTime(2026, 10, 21, 13, 0)), isTrue);
    expect(canModifyAppointment('2026-10-21', '16:00', 'confirmed', DateTime(2026, 10, 21, 15, 0)), isFalse);
    expect(canModifyAppointment('2026-10-21', '16:00', 'cancelled', DateTime(2026, 10, 21, 8, 0)), isFalse);
  });

  test('không tự khóa, tự xóa hoặc xóa admin cuối', () {
    expect(canLockAccount(isSelf: true, reason: 'Lý do'), isFalse);
    expect(canLockAccount(isSelf: false, reason: '  '), isFalse);
    expect(canLockAccount(isSelf: false, reason: 'Không đến khám'), isTrue);
    expect(canDeleteAccount(isSelf: true, role: 'user', adminCount: 2, hasFutureAppointment: false), isFalse);
    expect(canDeleteAccount(isSelf: false, role: 'admin', adminCount: 1, hasFutureAppointment: false), isFalse);
    expect(canDeleteAccount(isSelf: false, role: 'user', adminCount: 1, hasFutureAppointment: true), isFalse);
    expect(canDeleteAccount(isSelf: false, role: 'user', adminCount: 1, hasFutureAppointment: false), isTrue);
  });

  test('bác sĩ còn lịch và thuốc trùng', () {
    expect(canDeleteDoctor(hasFutureAppointment: true), isFalse);
    expect(canDeleteDoctor(hasFutureAppointment: false), isTrue);
    expect(
      isDuplicateMedicine([
        {'name': 'Paracetamol', 'dosage': '500mg'},
        {'name': ' paracetamol ', 'dosage': '500MG'},
      ]),
      isTrue,
    );
    expect(
      isDuplicateMedicine([
        {'name': 'Paracetamol', 'dosage': '500mg'},
        {'name': 'Vitamin D3', 'dosage': '1000IU'},
      ]),
      isFalse,
    );
  });

  test('doanh thu và hoàn tiền', () {
    final rows = [
      {'paid': true, 'status': 'completed', 'amount': 846000},
      {'paid': true, 'status': 'cancelled', 'amount': 785000, 'refundStatus': 'pending'},
      {'paid': true, 'status': 'cancelled', 'amount': 500000, 'refundStatus': 'done', 'refundAmount': 500000},
      {'paid': false, 'status': 'confirmed', 'amount': 1121000},
    ];
    expect(sumRevenue(rows), 846000 + 785000);
    expect(isRefundable({'paid': true, 'status': 'cancelled', 'refundStatus': 'pending'}), isTrue);
    expect(isRefundable({'paid': true, 'status': 'cancelled', 'refundStatus': 'done'}), isFalse);
    expect(isRefundable({'paid': false, 'status': 'cancelled', 'refundStatus': null}), isFalse);
  });
}
