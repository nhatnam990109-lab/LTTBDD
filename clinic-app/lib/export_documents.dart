import 'package:cliniccare/format.dart';

String recordDocument(Map<String, dynamic> record) {
  final rows = asList(record['prescription']).map((item) {
    return '<tr><td>${_esc(item['name'])}</td><td>${_esc(item['dosage'])}</td><td>${_esc(item['usage'])}</td><td>${_esc(item['quantity'])}</td><td>${_esc(item['note'])}</td></tr>';
  }).join();
  return '''
<!DOCTYPE html><html lang="vi"><head><meta charset="utf-8"><title>Hồ sơ ${record['code']}</title>
<style>body{font-family:"Be Vietnam Pro",Arial,sans-serif;color:#16354D;padding:32px}h1{color:#123B5D}table{border-collapse:collapse;width:100%}td,th{border:1px solid #D5E0EA;padding:8px;text-align:left}</style>
</head><body>
<h1>ClinicCare - Hồ sơ khám</h1>
<p>Mã lịch: <b>${_esc(record['code'])}</b> · ${formatDate('${record['date']}')} ${_esc(record['time'])}</p>
<p>Bệnh nhân: ${_esc(record['patientName'])} · ${_esc(record['phone'])}</p>
<p>Gói: ${_esc(record['packageName'])} · Bác sĩ: ${_esc(record['doctorName'])}</p>
<p><b>Chẩn đoán:</b> ${_esc(record['diagnosis'])}</p>
<p><b>Hướng xử trí:</b> ${_esc(record['treatment'])}</p>
<p><b>Ghi chú:</b> ${_esc(record['notes'])}</p>
<table><thead><tr><th>Thuốc</th><th>Hàm lượng</th><th>Cách dùng</th><th>Số lượng</th><th>Ghi chú</th></tr></thead><tbody>$rows</tbody></table>
</body></html>''';
}

String tableDocument(String title, List<String> headers, List<List<String>> rows) {
  final head = headers.map((item) => '<th>${_esc(item)}</th>').join();
  final body = rows.map((row) => '<tr>${row.map((cell) => '<td>${_esc(cell)}</td>').join()}</tr>').join();
  return '''<!DOCTYPE html><html lang="vi"><head><meta charset="utf-8"><title>$title</title></head>
<body><h1>${_esc(title)}</h1><table border="1" cellspacing="0" cellpadding="6"><thead><tr>$head</tr></thead><tbody>$body</tbody></table></body></html>''';
}

String _esc(Object? value) {
  return '${value ?? ''}'
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
