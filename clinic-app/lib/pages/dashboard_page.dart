import 'dart:convert';

import 'package:cliniccare/api.dart';
import 'package:cliniccare/export.dart';
import 'package:cliniccare/format.dart';
import 'package:cliniccare/session.dart';
import 'package:cliniccare/widgets.dart';
import 'package:cliniccare/pages/records_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

const clinicSpecialties = [
  'Tim mạch',
  'Nội tổng quát',
  'Sản phụ khoa',
  'Xét nghiệm',
  'Dinh dưỡng',
  'Tai mũi họng',
];

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.section});
  final String section;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error;
  final search = TextEditingController();
  String statusFilter = '';
  String branchFilter = '';
  DateTime revenueMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      data = switch (widget.section) {
        'doctors' => {'doctors': session.doctors},
        'appointments' || 'payments' => await session.api.get(session.isDoctor ? '/api/clinical/appointments' : '/api/admin/appointments', {
            if (search.text.trim().isNotEmpty) 'q': search.text.trim(),
            if (statusFilter.isNotEmpty) 'status': statusFilter,
            if (branchFilter.isNotEmpty) 'branchId': branchFilter,
          }),
        'accounts' => await session.api.get('/api/admin/users'),
        'medicines' => await session.api.get('/api/admin/medicines'),
        _ => {
            ...await session.api.get('/api/admin/overview'),
            'revenue': await session.api.get('/api/admin/revenue', {
              'month': '${revenueMonth.year}-${revenueMonth.month.toString().padLeft(2, '0')}',
            }),
          },
      };
    } on ApiException catch (error) {
      this.error = error.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    try {
      final result = await action();
      if (result['message'] != null) toast('${result['message']}');
      await session.boot();
      await _load();
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      section: widget.section,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(_title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
                    const SizedBox(height: 14),
                    switch (widget.section) {
                      'doctors' => _doctors(),
                      'appointments' => _appointments(false),
                      'payments' => _appointments(true),
                      'accounts' => _accounts(),
                      'medicines' => _medicines(),
                      _ => _overview(),
                    },
                  ],
                ),
    );
  }

  String get _title => switch (widget.section) {
        'doctors' => 'Bác sĩ',
        'appointments' => 'Lịch khám',
        'accounts' => 'Tài khoản',
        'medicines' => 'Danh mục thuốc',
        'payments' => 'Thanh toán và hoàn tiền',
        _ => 'Tổng quan',
      };

  Widget _overview() {
    final amounts = {for (final day in asList(asMap(data['revenue'])['days'])) '${day['date']}': day['amount'] as int? ?? 0};
    final days = List.generate(DateTime(revenueMonth.year, revenueMonth.month + 1, 0).day, (index) {
      final date = '${revenueMonth.year}-${revenueMonth.month.toString().padLeft(2, '0')}-${(index + 1).toString().padLeft(2, '0')}';
      return <String, dynamic>{'date': date, 'amount': amounts[date] ?? 0};
    });
    final total = days.fold<int>(0, (sum, day) => sum + (day['amount'] as int));
    final maxAmount = days.fold<int>(1, (max, day) {
      final amount = day['amount'] as int? ?? 0;
      return amount > max ? amount : max;
    });
    final stats = [
      _stat('Lịch hôm nay', '${data['todayAppointments'] ?? 0}', Icons.event_available, teal),
      _stat('Hồ sơ đã khám', '${data['completedRecords'] ?? 0}', Icons.assignment_turned_in, const Color(0xFF0F7B4C)),
      _stat('Doanh thu tháng', formatVnd(data['monthRevenue'] as int? ?? 0), Icons.payments, navy),
      _stat('Doanh thu hôm nay', formatVnd(data['todayRevenue'] as int? ?? 0), Icons.today, const Color(0xFFB54708)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980 ? 4 : constraints.maxWidth >= 640 ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats.map((card) => SizedBox(width: width, child: card)).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Tháng trước',
                    onPressed: () {
                      revenueMonth = DateTime(revenueMonth.year, revenueMonth.month - 1);
                      _load();
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Doanh thu tháng ${revenueMonth.month}/${revenueMonth.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
                  IconButton(
                    tooltip: 'Tháng sau',
                    onPressed: () {
                      revenueMonth = DateTime(revenueMonth.year, revenueMonth.month + 1);
                      _load();
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const Text('Số liệu đã trừ các khoản hoàn tiền cho khách.', style: TextStyle(color: muted)),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: constraints.maxWidth < days.length * 30 ? days.length * 30.0 : constraints.maxWidth,
                  height: 210,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.asMap().entries.map((entry) {
                      final day = entry.value;
                      final amount = day['amount'] as int;
                      return Expanded(child: Tooltip(
                        message: '${formatDate('${day['date']}')}\n${formatVnd(amount)}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: amount <= 0 ? 2 : 162 * amount / maxAmount,
                                decoration: BoxDecoration(color: amount <= 0 ? Colors.blueGrey.shade100 : teal, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                              ),
                              const SizedBox(height: 8),
                              Text('${entry.key + 1}', style: const TextStyle(fontSize: 11, color: muted)),
                            ],
                          ),
                        ),
                      ));
                    }).toList(),
                  ),
                ),
              )),
              const SizedBox(height: 16),
              Text('Tổng doanh thu tháng ${revenueMonth.month}/${revenueMonth.year}: ${formatVnd(total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: teal)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Lịch gần đây', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 8),
        _table(asList(data['recent'])),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctors() {
    final doctors = session.doctors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(onPressed: () => _doctorDialog(), icon: const Icon(Icons.add), label: const Text('Thêm bác sĩ')),
        ),
        const SizedBox(height: 14),
        if (doctors.isEmpty)
          const AppCard(child: Text('Chưa có bác sĩ.', style: TextStyle(color: muted)))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: doctors.map((doctor) {
                  final photo = _avatarOf(doctor['avatarUrl']);
                  return SizedBox(
                    width: width,
                    child: AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFFE5F5F6),
                            foregroundColor: teal,
                            backgroundImage: photo,
                            child: photo == null ? Text(initials('${doctor['fullName']}'), style: const TextStyle(fontWeight: FontWeight.w800)) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${doctor['fullName']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: navy)),
                                const SizedBox(height: 4),
                                Text('${doctor['specialty']}', style: const TextStyle(color: teal, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('${doctor['branchName']}', style: const TextStyle(color: muted)),
                                if ('${doctor['email'] ?? ''}'.isNotEmpty)
                                  Text('${doctor['email']}', style: const TextStyle(color: muted, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _action('Sửa', () => _doctorDialog(doctor), color: teal),
                              const SizedBox(height: 6),
                              if (doctor['hasAccount'] == true || doctor['userId'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF3),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF6CE9A6)),
                                  ),
                                  child: const Text('Đã có tài khoản', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF027A48))),
                                )
                              else
                                _action('Cấp tài khoản', () => _createDoctorAccountDialog(doctor), color: const Color(0xFFB54708), filled: true),
                              const SizedBox(height: 6),
                              _action('Xóa', () async {
                                final yes = await confirmDialog(context, 'Xóa bác sĩ', 'Xóa ${doctor['fullName']} khỏi danh sách bác sĩ?');
                                if (!yes) return;
                                await _run(() => session.api.delete('/api/admin/doctors/${doctor['id']}'));
                              }, color: const Color(0xFFB42318)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  ImageProvider? _avatarOf(Object? value) {
    if (value is! String || !value.startsWith('data:image')) return null;
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(value.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }

  Future<void> _doctorDialog([Map<String, dynamic>? doctor]) async {
    final name = TextEditingController(text: '${doctor?['fullName'] ?? ''}');
    final email = TextEditingController(text: '${doctor?['email'] ?? ''}');
    final phone = TextEditingController();
    final password = TextEditingController(text: doctor == null ? 'Doctor@123' : '');
    var createAccount = doctor == null;
    final bio = TextEditingController(text: '${doctor?['bio'] ?? ''}');
    final specialties = {...clinicSpecialties, ...session.doctors.map((item) => '${item['specialty']}')}.where((item) => item.trim().isNotEmpty).toList();
    var specialty = specialties.contains(doctor?['specialty']) ? '${doctor!['specialty']}' : specialties.first;
    var branchId = '${doctor?['branchId'] ?? session.branches.first['id']}';
    String? avatar = doctor?['avatarUrl'] as String?;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(doctor == null ? 'Thêm bác sĩ' : 'Sửa bác sĩ'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField('Họ tên *', name),
                  _dialogField('Email *', email),
                  if (doctor == null) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: createAccount,
                      onChanged: (val) => setLocal(() => createAccount = val),
                      title: const Text('Tạo tài khoản đăng nhập cho bác sĩ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: navy)),
                      subtitle: const Text('Cho phép bác sĩ đăng nhập hệ thống nội bộ', style: TextStyle(fontSize: 11, color: muted)),
                    ),
                    if (createAccount) ...[
                      _dialogField('Số điện thoại (để đăng nhập/liên hệ)', phone),
                      _dialogField('Mật khẩu đăng nhập (mặc định Doctor@123)', password),
                    ],
                  ],
                  if (doctor != null)
                    _dialogField('Mật khẩu đăng nhập mới (để trống để giữ nguyên)', password, obscureText: true),
                  if (doctor != null && doctor['hasAccount'] != true && doctor['userId'] == null)
                    const Text('Nhập mật khẩu để cấp tài khoản đăng nhập bằng email trên.', style: TextStyle(fontSize: 12, color: muted)),
                  _dialogField('Giới thiệu', bio, maxLines: 3),
                  _dialogLabel('Chuyên khoa'),
                  DropdownButtonFormField<String>(
                    initialValue: specialty,
                    items: specialties.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                    onChanged: (value) => setLocal(() => specialty = value ?? specialty),
                  ),
                  const SizedBox(height: 12),
                  _dialogLabel('Cơ sở'),
                  DropdownButtonFormField<String>(
                    initialValue: branchId,
                    items: session.branches.map((branch) => DropdownMenuItem(value: '${branch['id']}', child: Text('${branch['name']}'))).toList(),
                    onChanged: (value) => setLocal(() => branchId = value ?? branchId),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final files = await FilePicker.pickFiles(type: FileType.image);
                        if (files.isEmpty) return;
                        final bytes = await files.first.readAsBytes();
                        if (bytes.length > 350000) {
                          toast('Ảnh vượt quá 350KB.');
                          return;
                        }
                        setLocal(() => avatar = 'data:image/png;base64,${base64Encode(bytes)}');
                      },
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(avatar == null ? 'Chọn ảnh' : 'Đã chọn ảnh'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Đóng')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
                  toast('Vui lòng điền họ tên và email bác sĩ.');
                  return;
                }
                if (password.text.trim().isNotEmpty && password.text.trim().length < 6) {
                  toast('Mật khẩu cần ít nhất 6 ký tự.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final body = {
      'fullName': name.text.trim(),
      'specialty': specialty,
      'email': email.text.trim(),
      'bio': bio.text.trim(),
      'branchId': branchId,
      'avatarUrl': avatar,
      if (doctor != null && password.text.trim().isNotEmpty) 'password': password.text.trim(),
      if (doctor == null && createAccount) ...{
        'createAccount': true,
        'phone': phone.text.trim(),
        'password': password.text.trim().isEmpty ? 'Doctor@123' : password.text.trim(),
      },
    };
    await _run(() => doctor == null ? session.api.post('/api/admin/doctors', body) : session.api.put('/api/admin/doctors/${doctor['id']}', body));
  }

  Future<void> _createDoctorAccountDialog(Map<String, dynamic> doctor) async {
    final phone = TextEditingController();
    final password = TextEditingController(text: 'Doctor@123');
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cấp tài khoản: ${doctor['fullName']}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFB2DDFF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF175CD3), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Email đăng nhập: ${doctor['email']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF175CD3), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _dialogField('Số điện thoại (để liên hệ/xác thực)', phone),
              _dialogField('Mật khẩu đăng nhập (mặc định Doctor@123)', password),
              const Text('Sau khi cấp tài khoản, bác sĩ có thể dùng Email và Mật khẩu trên để đăng nhập vào phòng khám.', style: TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Đóng')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cấp tài khoản'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => session.api.post('/api/admin/doctors/${doctor['id']}/account', {
      'phone': phone.text.trim(),
      'password': password.text.trim().isEmpty ? 'Doctor@123' : password.text.trim(),
    }));
  }

  Widget _dialogLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: navy, fontSize: 13)),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController controller, {int maxLines = 1, bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dialogLabel(label),
          TextField(
            controller: controller,
            obscureText: obscureText,
            maxLines: maxLines,
            decoration: const InputDecoration(floatingLabelBehavior: FloatingLabelBehavior.never),
          ),
        ],
      ),
    );
  }

  Widget _appointments(bool payments) {
    if (session.isDoctor) {
      final appointments = asList(data['appointments']);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: search, decoration: InputDecoration(
          labelText: 'Tìm mã, tên hoặc số điện thoại',
          suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.search)),
        ), onSubmitted: (_) => _load()),
        const SizedBox(height: 12),
        if (appointments.isEmpty) const Text('Không có lịch khám phù hợp.'),
        ...appointments.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(child: ListTile(
            title: Text('${item['patientName']} · ${item['code']}'),
            subtitle: Text('${formatDate('${item['date']}')} ${item['time']} · ${statusLabel('${item['status']}')}'),
            trailing: item['status'] == 'cancelled' ? null : FilledButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecordsPage(initialAppointment: item)));
                if (mounted) await _load();
              },
              child: const Text('Khám / Kê đơn'),
            ),
          )),
        )),
      ]);
    }
    final items = asList(data['appointments']).where((item) {
      if (!payments) return true;
      final refundable = item['paid'] == true && item['status'] == 'cancelled' && item['refundStatus'] != 'done';
      return refundable || item['paid'] != true;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 220, child: TextField(controller: search, decoration: const InputDecoration(labelText: 'Mã, tên hoặc số điện thoại'), onSubmitted: (_) => _load())),
            DropdownButton<String>(
              value: statusFilter,
              items: const [
                DropdownMenuItem(value: '', child: Text('Mọi trạng thái')),
                DropdownMenuItem(value: 'pending', child: Text('Chờ xác nhận')),
                DropdownMenuItem(value: 'confirmed', child: Text('Đã xác nhận')),
                DropdownMenuItem(value: 'completed', child: Text('Đã khám')),
                DropdownMenuItem(value: 'cancelled', child: Text('Đã hủy')),
              ],
              onChanged: (value) {
                statusFilter = value ?? '';
                _load();
              },
            ),
            DropdownButton<String>(
              value: branchFilter,
              items: [
                const DropdownMenuItem(value: '', child: Text('Mọi cơ sở')),
                ...session.branches.map((branch) => DropdownMenuItem(value: '${branch['id']}', child: Text('${branch['name']}'))),
              ],
              onChanged: (value) {
                branchFilter = value ?? '';
                _load();
              },
            ),
            FilledButton(onPressed: _load, child: const Text('Tìm')),
            OutlinedButton(
              onPressed: () {
                final html = tableDocument(
                  'Lịch khám ClinicCare',
                  ['Mã', 'Bệnh nhân', 'Gói', 'Ngày', 'Trạng thái', 'Số tiền'],
                  items.map((item) => ['${item['code']}', '${item['patientName']}', '${item['packageName']}', '${item['date']} ${item['time']}', statusLabel('${item['status']}'), formatVnd(item['amount'] as int? ?? 0)]).toList(),
                );
                exportHtml('lich-kham.xls', 'application/vnd.ms-excel', html);
              },
              child: const Text('Xuất Excel'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _table(items, payments: payments),
      ],
    );
  }

  Widget _action(String label, VoidCallback onPressed, {Color color = teal, bool filled = false}) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final text = Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700));
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: shape,
        ),
        child: text,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: shape,
      ),
      child: text,
    );
  }

  Widget _table(List<Map<String, dynamic>> items, {bool payments = false}) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF7FAFC)),
          dataRowMinHeight: 72,
          dataRowMaxHeight: 120,
          horizontalMargin: 16,
          columnSpacing: 28,
          columns: const [
            DataColumn(label: Text('Mã')),
            DataColumn(label: Text('Bệnh nhân')),
            DataColumn(label: Text('Lịch')),
            DataColumn(label: Text('Trạng thái')),
            DataColumn(label: Text('Thao tác')),
          ],
          rows: items.map((item) {
            return DataRow(cells: [
              DataCell(Text('${item['code']}')),
              DataCell(Text('${item['patientName']}\n${item['phone']}')),
              DataCell(Text('${formatDate('${item['date']}')} ${item['time']}\n${item['doctorName']}')),
              DataCell(PopupMenuButton<String>(
                tooltip: 'Chọn trạng thái',
                onSelected: (value) {
                  if (value == item['status']) return;
                  _run(() => session.api.post('/api/admin/appointments/${item['id']}/status', {'status': value}));
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'completed', child: Text('Đã khám')),
                  PopupMenuItem(value: 'cancelled', child: Text('Đã hủy')),
                ],
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  StatusChip('${item['status']}'),
                  const Icon(Icons.arrow_drop_down, color: muted),
                ]),
              )),
              DataCell(Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item['paid'] != true && item['status'] != 'cancelled')
                    _action('Đã thu', () => _run(() => session.api.post('/api/admin/appointments/${item['id']}/pay')), filled: true),
                  if (item['status'] != 'cancelled' && item['status'] != 'completed')
                    _action('Hủy', () => _run(() => session.api.post('/api/admin/appointments/${item['id']}/cancel')), color: const Color(0xFFB42318)),
                  if (item['cancelRequestStatus'] == 'open')
                    _action('Từ chối hủy', () => _run(() => session.api.post('/api/admin/appointments/${item['id']}/reject-cancel')), color: navy),
                  if (item['paid'] == true && item['status'] == 'cancelled' && item['refundStatus'] != 'done')
                    _action('Hoàn tiền', () => _run(() => session.api.post('/api/admin/appointments/${item['id']}/refund')), color: const Color(0xFFB54708), filled: true),
                  if (item['status'] == 'cancelled')
                    _action('Xóa', () => _run(() => session.api.delete('/api/admin/appointments/${item['id']}')), color: const Color(0xFFB42318)),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _accounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _patientDialog(),
            icon: const Icon(Icons.person_add),
            label: const Text('Tạo tài khoản bệnh nhân'),
          ),
        ),
        const SizedBox(height: 14),
        ...asList(data['users']).map((user) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user['fullName']}', style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
                      const SizedBox(height: 2),
                      Text(
                        '${user['email']} · ${roleLabel('${user['role']}')}${user['phone'] != null && '${user['phone']}'.isNotEmpty ? ' · ${user['phone']}' : ''}${user['locked'] == true ? ' · đang khóa' : ''}',
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (session.isAdmin) ...[
                  DropdownButton<String>(
                    value: '${user['role']}',
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Quản trị')),
                      DropdownMenuItem(value: 'doctor', child: Text('Bác sĩ')),
                      DropdownMenuItem(value: 'user', child: Text('Bệnh nhân')),
                    ],
                    onChanged: (value) {
                      if (value == null || value == user['role']) return;
                      _run(() => session.api.post('/api/admin/users/${user['id']}/role', {'role': value}));
                    },
                  ),
                  const SizedBox(width: 8),
                  if (user['locked'] == true)
                    _action('Mở khóa', () => _run(() => session.api.post('/api/admin/users/${user['id']}/unlock')), filled: true)
                  else
                    _action('Khóa', () => _lock(user), color: const Color(0xFFB54708)),
                  const SizedBox(width: 8),
                  _action('Xóa', () => _run(() => session.api.delete('/api/admin/users/${user['id']}')), color: const Color(0xFFB42318)),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      roleLabel('${user['role']}'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: navy),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),

      ],
    );
  }

  Future<void> _patientDialog() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController(text: 'User@123');
    final dob = TextEditingController();
    final address = TextEditingController();
    var gender = 'male';

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tạo tài khoản bệnh nhân'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField('Họ và tên *', name),
                  _dialogField('Email *', email),
                  _dialogField('Số điện thoại *', phone),
                  _dialogField('Mật khẩu ban đầu (mặc định User@123)', password),
                  _dialogLabel('Giới tính'),
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Nam')),
                      DropdownMenuItem(value: 'female', child: Text('Nữ')),
                      DropdownMenuItem(value: 'other', child: Text('Khác')),
                    ],
                    onChanged: (value) => setLocal(() => gender = value ?? gender),
                  ),
                  const SizedBox(height: 12),
                  _dialogField('Ngày sinh (YYYY-MM-DD)', dob),
                  _dialogField('Địa chỉ', address, maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Đóng')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty || email.text.trim().isEmpty || phone.text.trim().isEmpty) {
                  toast('Vui lòng điền đủ Họ tên, Email và Số điện thoại.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final body = {
      'fullName': name.text.trim(),
      'email': email.text.trim(),
      'phone': phone.text.trim(),
      'password': password.text.trim(),
      'gender': gender,
      'dateOfBirth': dob.text.trim(),
      'address': address.text.trim(),
    };
    await _run(() => session.api.post('/api/admin/users', body));
  }

  Future<void> _lock(Map<String, dynamic> user) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khóa tài khoản'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Lý do')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Đóng')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Khóa')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => session.api.post('/api/admin/users/${user['id']}/lock', {'reason': reason.text}));
  }

  Widget _medicines() {
    final group = TextEditingController();
    final name = TextEditingController();
    final dosage = TextEditingController();
    final usage = TextEditingController();
    final groups = asStrings(data['groups']);
    var selected = groups.isEmpty ? '' : groups.first;
    return StatefulBuilder(
      builder: (context, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(width: 180, child: TextField(controller: group, decoration: const InputDecoration(labelText: 'Nhóm bệnh mới'))),
              FilledButton(onPressed: () => _run(() => session.api.post('/api/admin/disease-groups', {'name': group.text})), child: const Text('Thêm nhóm')),
              SizedBox(width: 180, child: TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên thuốc'))),
              SizedBox(width: 120, child: TextField(controller: dosage, decoration: const InputDecoration(labelText: 'Hàm lượng'))),
              SizedBox(width: 220, child: TextField(controller: usage, decoration: const InputDecoration(labelText: 'Cách dùng'))),
              DropdownButton<String>(
                value: selected.isEmpty ? null : selected,
                hint: const Text('Nhóm bệnh'),
                items: groups.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: (value) => setLocal(() => selected = value ?? ''),
              ),
              FilledButton(
                onPressed: () => _run(() => session.api.post('/api/admin/medicines', {
                      'name': name.text,
                      'dosage': dosage.text,
                      'usage': usage.text,
                      'group': selected,
                    })),
                child: const Text('Thêm thuốc'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...asList(data['medicines']).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item['name']} ${item['dosage']}', style: const TextStyle(fontWeight: FontWeight.w800, color: navy)),
                            const SizedBox(height: 2),
                            Text('${item['group']} · ${item['usage']}', style: const TextStyle(color: muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _action('Gỡ nhóm', () => _run(() => session.api.post('/api/admin/medicines/${item['id']}/detach')), color: navy),
                      const SizedBox(width: 8),
                      _action('Xóa', () => _run(() => session.api.delete('/api/admin/medicines/${item['id']}')), color: const Color(0xFFB42318)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
