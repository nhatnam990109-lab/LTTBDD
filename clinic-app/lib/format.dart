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

String formatDate(String? iso) {
  if (iso == null || iso.length < 10) return iso ?? '';
  final parts = iso.substring(0, 10).split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String canonicalPhone(String raw) {
  var value = raw.replaceAll(RegExp(r'[\s.\-]'), '');
  if (value.startsWith('+84')) value = '0${value.substring(3)}';
  if (value.startsWith('84') && value.length == 11) value = '0${value.substring(2)}';
  return value;
}

bool isValidVnPhone(String raw) => RegExp(r'^0[35789]\d{8}$').hasMatch(canonicalPhone(raw));

bool isValidEmail(String raw) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(raw.trim());

bool canModifyAppointment(Map<String, dynamic> appointment, [DateTime? now]) {
  final status = appointment['status'];
  if (status != 'pending' && status != 'confirmed') return false;
  final slot = DateTime.tryParse('${appointment['date']}T${appointment['time']}:00');
  if (slot == null) return false;
  return !slot.isBefore((now ?? DateTime.now()).add(const Duration(hours: 2)));
}

bool isDuplicateMedicine(List<Map<String, String>> items) {
  final seen = <String>{};
  for (final item in items) {
    final key = '${item['name']!.trim().toLowerCase()}|${item['dosage']!.trim().toLowerCase()}';
    if (!seen.add(key)) return true;
  }
  return false;
}

String statusLabel(String? status) {
  return switch (status) {
    'pending' => 'Chờ xác nhận',
    'confirmed' => 'Đã xác nhận',
    'completed' => 'Đã khám',
    'cancelled' => 'Đã hủy',
    'new' => 'Mới',
    'examining' => 'Đang khám',
    _ => status ?? '',
  };
}

String paymentLabel(String? method) {
  return switch (method) {
    'momo' => 'MoMo',
    'cash' => 'Tiền mặt',
    'transfer' => 'Chuyển khoản',
    _ => method ?? '',
  };
}

String genderLabel(String? gender) {
  return switch (gender) {
    'male' => 'Nam',
    'female' => 'Nữ',
    'other' => 'Khác',
    _ => 'Khác',
  };
}

String roleLabel(String? role) {
  return switch (role) {
    'admin' => 'Quản trị',
    'doctor' => 'Bác sĩ',
    _ => 'Bệnh nhân',
  };
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'CC';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return {};
}

List<Map<String, dynamic>> asList(Object? value) {
  if (value is! List) return [];
  return value.map(asMap).toList();
}

List<String> asStrings(Object? value) {
  if (value is! List) return [];
  return value.map((item) => '$item').toList();
}
