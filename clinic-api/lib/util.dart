import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const timeSlots = [
  '07:30', '08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00',
  '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00',
  '17:30', '18:30', '19:30',
];

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

class ApiException implements Exception {
  ApiException(this.code, this.message);
  final int code;
  final String message;
}

String hashPassword(String password) {
  return sha256.convert(utf8.encode('cliniccare:$password')).toString();
}

String randomToken(int bytes) {
  final random = Random.secure();
  final data = List<int>.generate(bytes, (_) => random.nextInt(256));
  return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String randomCode(int length) {
  final random = Random.secure();
  return List.generate(length, (_) => _alphabet[random.nextInt(_alphabet.length)]).join();
}

String formatVnd(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$bufferđ';
}

String canonicalPhone(String raw) {
  var value = raw.replaceAll(RegExp(r'[\s.\-]'), '');
  if (value.startsWith('+84')) value = '0${value.substring(3)}';
  if (value.startsWith('84') && value.length == 11) value = '0${value.substring(2)}';
  return value;
}

bool isValidVnPhone(String raw) {
  return RegExp(r'^0[35789]\d{8}$').hasMatch(canonicalPhone(raw));
}

bool isValidEmail(String raw) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(raw.trim());
}

DateTime? slotDateTime(String date, String time) {
  final day = date.length >= 10 ? date.substring(0, 10) : date;
  final clock = time.length >= 5 ? time.substring(0, 5) : time;
  return DateTime.tryParse('${day}T$clock:00');
}

bool canModifyAppointment(String date, String time, String status, [DateTime? now]) {
  if (status != 'pending' && status != 'confirmed') return false;
  final slot = slotDateTime(date, time);
  if (slot == null) return false;
  final current = now ?? DateTime.now();
  return !slot.isBefore(current.add(const Duration(hours: 2)));
}

bool canDeleteAccount({
  required bool isSelf,
  required String role,
  required int adminCount,
  required bool hasFutureAppointment,
}) {
  if (isSelf) return false;
  if (role == 'admin' && adminCount <= 1) return false;
  if (hasFutureAppointment) return false;
  return true;
}

bool canLockAccount({required bool isSelf, required String reason}) {
  return !isSelf && reason.trim().isNotEmpty;
}

bool canDeleteDoctor({required bool hasFutureAppointment}) {
  return !hasFutureAppointment;
}

bool isDuplicateMedicine(List<Map<String, String>> items) {
  final seen = <String>{};
  for (final item in items) {
    final key = '${item['name']!.trim().toLowerCase()}|${item['dosage']!.trim().toLowerCase()}';
    if (!seen.add(key)) return true;
  }
  return false;
}

int sumRevenue(List<Map<String, Object?>> rows) {
  var total = 0;
  for (final row in rows) {
    final paid = row['paid'] == true || row['paid'] == 1 || row['paid'] == '1';
    if (!paid) continue;
    final amount = intOf(row['amount']);
    final refunded = row['refundStatus'] == 'done' || row['refund_status'] == 'done';
    if (!refunded) {
      total += amount;
      continue;
    }
    final refund = row.containsKey('refundAmount')
        ? intOf(row['refundAmount'])
        : row.containsKey('refund_amount')
            ? intOf(row['refund_amount'])
            : amount;
    final net = amount - refund;
    if (net > 0) total += net;
  }
  return total;
}

bool isRefundable(Map<String, Object?> row) {
  final paid = row['paid'] == true || row['paid'] == 1;
  return paid && row['status'] == 'cancelled' && row['refundStatus'] != 'done';
}

String textOf(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  return '$value'.trim();
}

int intOf(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

String dateOnly(String? value) {
  if (value == null || value.isEmpty) return '';
  return value.length >= 10 ? value.substring(0, 10) : value;
}

String timeOnly(String? value) {
  if (value == null || value.isEmpty) return '';
  return value.length >= 5 ? value.substring(0, 5) : value;
}
