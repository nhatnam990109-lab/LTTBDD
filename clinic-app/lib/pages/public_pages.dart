import 'package:cliniccare/api.dart';
import 'package:cliniccare/format.dart';
import 'package:cliniccare/session.dart';
import 'package:cliniccare/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.section});
  final String? section;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final specialtyKey = GlobalKey();
  final doctorKey = GlobalKey();
  final name = TextEditingController();
  final phone = TextEditingController();
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jump());
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jump());
  }

  void _jump() {
    final key = widget.section == 'doctors'
        ? doctorKey
        : widget.section == 'specialty'
        ? specialtyKey
        : null;
    final target = key?.currentContext;
    if (target != null)
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
      );
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _consult() async {
    try {
      final result = await session.api.post('/api/consults', {
        'fullName': name.text,
        'phone': phone.text,
        'note': note.text,
      });
      if (!mounted) return;
      toast('${result['message']}');
      name.clear();
      phone.clear();
      note.clear();
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return PublicShell(
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          if (!session.ready)
            return const Center(child: CircularProgressIndicator());
          return ListView(
            children: [
              if (session.bootError != null)
                PageWidth(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.bootError!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Trong MySQL Workbench, mở sql/cliniccare.sql và bấm Execute. Sau đó ghi mật khẩu root vào clinic-api/config.json rồi chạy API.',
                        ),
                      ],
                    ),
                  ),
                ),
              _hero(wide),
              PageWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chuyên khoa',
                      key: null,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      key: specialtyKey,
                      child: const Text(
                        'Đội ngũ bác sĩ theo từng chuyên khoa, khám đúng người đúng việc.',
                        style: TextStyle(color: muted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        _Specialty('Tim mạch', Icons.favorite),
                        _Specialty('Nội tổng quát', Icons.health_and_safety),
                        _Specialty('Sản phụ khoa', Icons.pregnant_woman),
                        _Specialty('Xét nghiệm', Icons.biotech),
                        _Specialty('Dinh dưỡng', Icons.restaurant),
                        _Specialty('Tai mũi họng', Icons.hearing),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Gói khám',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: navy,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/packages'),
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: session.packages
                          .take(4)
                          .map(
                            (item) => _PackageCard(
                              item: item,
                              width: wide ? 260 : double.infinity,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Đội ngũ bác sĩ',
                      key: doctorKey,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: session.doctors
                          .map((doctor) => _DoctorCard(doctor: doctor))
                          .toList(),
                    ),
                    const SizedBox(height: 36),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: session.branches.map((branch) {
                        return SizedBox(
                          width: wide ? 340 : double.infinity,
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${branch['name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: navy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${branch['address']}',
                                  style: const TextStyle(color: muted),
                                ),
                                Text(
                                  'Mở cửa ${branch['openingHours']}',
                                  style: const TextStyle(color: muted),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SiteFooter(),
            ],
          );
        },
      ),
    );
  }

  Widget _hero(bool wide) {
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE5F5F6),
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Text(
            'Phòng khám đa khoa',
            style: TextStyle(
              color: teal,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 40,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
            children: [
              const TextSpan(text: 'Chăm sóc sức khỏe '),
              TextSpan(
                text: 'chuẩn quốc tế',
                style: TextStyle(
                  color: teal,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(text: ', tận tâm vì bạn'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Đặt lịch theo gói, chọn cơ sở và bác sĩ, theo dõi kết quả ngay trên một website.',
          style: TextStyle(color: muted, fontSize: 16),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(
              onPressed: () => context.go('/booking'),
              child: const Text('Đặt lịch ngay'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/packages'),
              child: const Text('Xem gói khám'),
            ),
          ],
        ),
      ],
    );
    const side = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch làm việc',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: navy,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text('Thứ 2 – Chủ nhật, 07:00 – 20:00'),
          SizedBox(height: 8),
          Text('Hotline 1900 6688'),
          SizedBox(height: 8),
          Text(
            'Thanh toán tiền mặt, chuyển khoản hoặc quét mã minh họa MoMo tại quầy.',
          ),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: PageWidth(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: intro),
                  const SizedBox(width: 24),
                  const Expanded(child: side),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, const SizedBox(height: 16), side],
              ),
      ),
    );
  }
}

class _Specialty extends StatelessWidget {
  const _Specialty(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: teal),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.item, required this.width});
  final Map<String, dynamic> item;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['badge'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${item['badge']}',
                  style: const TextStyle(
                    color: teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            Text(
              '${item['name']}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: navy,
              ),
            ),
            Text('${item['tagline']}', style: const TextStyle(color: muted)),
            const SizedBox(height: 8),
            Text(
              formatVnd(item['price'] as int? ?? 0),
              style: const TextStyle(
                color: teal,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${item['summary']}',
              style: const TextStyle(color: muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => showPackageTests(context, item),
                  child: const Text('Chi tiết'),
                ),
                FilledButton(
                  onPressed: () => context.go('/booking?package=${item['id']}'),
                  child: const Text('Đặt gói này'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor});
  final Map<String, dynamic> doctor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE5F5F6),
              foregroundColor: teal,
              child: Text(initials('${doctor['fullName']}')),
            ),
            const SizedBox(height: 10),
            Text(
              '${doctor['fullName']}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: navy),
            ),
            Text(
              '${doctor['specialty']} · ${doctor['branchName']}',
              style: const TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '${doctor['bio']}',
              style: const TextStyle(color: muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/booking?doctor=${doctor['id']}'),
              child: const Text('Đặt với bác sĩ'),
            ),
          ],
        ),
      ),
    );
  }
}

class PackagesPage extends StatelessWidget {
  const PackagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicShell(
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) => ListView(
          children: [
            PageWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gói khám',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Giá niêm yết bằng đồng, đã gồm các chỉ số trong gói.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: session.packages
                        .map((item) => _PackageCard(item: item, width: 320))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'So sánh nhanh',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Gói')),
                          DataColumn(label: Text('Chỉ số')),
                          DataColumn(label: Text('Giá')),
                        ],
                        rows: session.packages.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text('${item['name']}')),
                              DataCell(Text('${item['testCount']}')),
                              DataCell(
                                Text(formatVnd(item['price'] as int? ?? 0)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SiteFooter(),
          ],
        ),
      ),
    );
  }
}

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, this.packageId, this.doctorId});
  final String? packageId;
  final String? doctorId;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int step = 0;
  String? packageId;
  String? branchId;
  String doctorId = 'any';
  DateTime date = DateTime.now();
  String? time;
  String payment = 'momo';
  String gender = 'female';
  List<Map<String, dynamic>> slots = [];
  bool busy = false;
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    packageId =
        widget.packageId ??
        (session.packages.isNotEmpty
            ? session.packages.first['id'] as String?
            : null);
    final doctor = session.doctorById(widget.doctorId);
    if (doctor != null) {
      doctorId = '${doctor['id']}';
      branchId = '${doctor['branchId']}';
    } else if (session.branches.isNotEmpty) {
      branchId = '${session.branches.first['id']}';
    }
    final user = session.user;
    if (user != null) {
      name.text = '${user['fullName']}';
      phone.text = '${user['phone']}';
      email.text = '${user['email']}';
      gender = '${user['gender'] ?? 'other'}';
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    if (branchId == null) return;
    setState(() => busy = true);
    try {
      final data = await session.api.get('/api/slots', {
        'branchId': branchId!,
        'date': isoDate(date),
        if (doctorId != 'any') 'doctorId': doctorId,
      });
      slots = asList(data['slots']);
      if (time != null &&
          slots.any((slot) => slot['time'] == time && slot['full'] == true))
        time = null;
    } on ApiException catch (error) {
      toast(error.message);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _submit() async {
    setState(() => busy = true);
    try {
      final result = await session.api.post('/api/appointments', {
        'patientName': name.text,
        'phone': phone.text,
        'email': email.text,
        'gender': gender,
        'note': note.text,
        'packageId': packageId,
        'branchId': branchId,
        'doctorId': doctorId,
        'date': isoDate(date),
        'time': time,
        'paymentMethod': payment,
      });
      final appointment = asMap(result['appointment']);
      if (!mounted) return;
      context.go(
        '/success?code=${appointment['code']}&phone=${appointment['phone']}',
      );
    } on ApiException catch (error) {
      toast(error.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['Chọn gói', 'Thông tin', 'Lịch và thanh toán'];
    return PublicShell(
      child: ListView(
        children: [
          PageWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đặt lịch khám',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(labels.length, (index) {
                    final active = index <= step;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? teal : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? teal : line),
                        ),
                        child: Text(
                          '${index + 1}. ${labels[index]}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: active ? Colors.white : muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: step == 0
                      ? _stepPackage()
                      : step == 1
                      ? _stepInfo()
                      : _stepSchedule(),
                ),
              ],
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }

  Widget _stepPackage() {
    return Column(
      children: [
        ...session.packages.map((item) {
          final selected = item['id'] == packageId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => packageId = '${item['id']}'),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? teal : line,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item['name']} · ${item['tagline']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      formatVnd(item['price'] as int? ?? 0),
                      style: const TextStyle(
                        color: teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: packageId == null
                ? null
                : () => setState(() => step = 1),
            child: const Text('Tiếp tục'),
          ),
        ),
      ],
    );
  }

  Widget _stepInfo() {
    return Column(
      children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Họ tên'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: phone,
          decoration: const InputDecoration(labelText: 'Số điện thoại'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: email,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: gender,
          decoration: const InputDecoration(labelText: 'Giới tính'),
          items: const [
            DropdownMenuItem(value: 'female', child: Text('Nữ')),
            DropdownMenuItem(value: 'male', child: Text('Nam')),
            DropdownMenuItem(value: 'other', child: Text('Khác')),
          ],
          onChanged: (value) => setState(() => gender = value ?? 'other'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Triệu chứng / ghi chú'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => step = 0),
              child: const Text('Quay lại'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                if (name.text.trim().length < 2 ||
                    !isValidVnPhone(phone.text) ||
                    !isValidEmail(email.text)) {
                  toast('Kiểm tra lại họ tên, số điện thoại và email.');
                  return;
                }
                setState(() => step = 2);
                _loadSlots();
              },
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepSchedule() {
    final package = session.packageById(packageId);
    final branchDoctors = session.doctors
        .where((doctor) => doctor['branchId'] == branchId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('branch-$branchId'),
          initialValue: branchId,
          decoration: const InputDecoration(labelText: 'Cơ sở'),
          items: session.branches
              .map(
                (branch) => DropdownMenuItem(
                  value: '${branch['id']}',
                  child: Text('${branch['name']}'),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              branchId = value;
              doctorId = 'any';
              time = null;
            });
            _loadSlots();
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('doctor-$branchId-$doctorId'),
          initialValue: branchDoctors.any((doctor) => doctor['id'] == doctorId)
              ? doctorId
              : 'any',
          decoration: const InputDecoration(labelText: 'Bác sĩ'),
          items: [
            const DropdownMenuItem(value: 'any', child: Text('Bác sĩ bất kỳ')),
            ...branchDoctors.map(
              (doctor) => DropdownMenuItem(
                value: '${doctor['id']}',
                child: Text('${doctor['fullName']} · ${doctor['specialty']}'),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => doctorId = value ?? 'any');
            _loadSlots();
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ngày khám'),
          subtitle: Text(formatDate(isoDate(date))),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 60)),
            );
            if (picked == null) return;
            setState(() {
              date = picked;
              time = null;
            });
            _loadSlots();
          },
        ),
        if (busy) const LinearProgressIndicator(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) {
            final full = slot['full'] == true;
            final selected = slot['time'] == time;
            return ChoiceChip(
              label: Text(full ? '${slot['time']} · kín' : '${slot['time']}'),
              selected: selected,
              onSelected: full
                  ? null
                  : (_) => setState(() => time = '${slot['time']}'),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'momo', label: Text('MoMo')),
            ButtonSegment(value: 'transfer', label: Text('Chuyển khoản')),
            ButtonSegment(value: 'cash', label: Text('Tiền mặt')),
          ],
          selected: {payment},
          onSelectionChanged: (value) => setState(() => payment = value.first),
        ),
        const SizedBox(height: 12),
        Text(
          '${package?['name'] ?? ''} · ${formatVnd(package?['price'] as int? ?? 0)}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: navy),
        ),
        const SizedBox(height: 4),
        Text(
          '$genderLabelPatient · ${formatDate(isoDate(date))} ${time ?? ''}',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => step = 1),
              child: const Text('Quay lại'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: busy || time == null ? null : _submit,
              child: const Text('Xác nhận đặt lịch'),
            ),
          ],
        ),
      ],
    );
  }

  String get genderLabelPatient => '${name.text} · ${genderLabel(gender)}';
}

class SuccessPage extends StatefulWidget {
  const SuccessPage({super.key, required this.code, required this.phone});
  final String code;
  final String phone;

  @override
  State<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> {
  Map<String, dynamic>? appointment;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await session.api.get('/api/appointments/lookup', {
        'code': widget.code,
        'phone': widget.phone,
      });
      if (mounted) setState(() => appointment = asMap(data['appointment']));
    } on ApiException catch (error) {
      if (mounted) setState(() => this.error = error.message);
    }
  }

  Future<void> _pay() async {
    setState(() => busy = true);
    try {
      final data = await session.api.post('/api/appointments/confirm-payment', {
        'code': widget.code,
        'phone': widget.phone,
      });
      toast('${data['message']}');
      if (mounted) setState(() => appointment = asMap(data['appointment']));
    } on ApiException catch (error) {
      toast(error.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = appointment;
    return PublicShell(
      child: ListView(
        children: [
          PageWidth(
            child: AppCard(
              child: item == null
                  ? Text(error ?? 'Đang tải lịch khám...')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đặt lịch thành công',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mã lịch ${item['code']}',
                          style: const TextStyle(
                            fontSize: 20,
                            color: teal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: '${item['code']}'),
                            );
                            toast('Đã sao chép mã lịch.');
                          },
                          child: const Text('Sao chép mã'),
                        ),
                        const SizedBox(height: 8),
                        Text('${item['patientName']} · ${item['packageName']}'),
                        Text(
                          '${item['branchName']} · ${formatDate('${item['date']}')} ${item['time']}',
                        ),
                        Text(
                          '${item['doctorName']} · ${paymentLabel('${item['paymentMethod']}')}',
                        ),
                        Text(
                          item['paid'] == true
                              ? 'Đã thanh toán'
                              : 'Chưa thanh toán',
                        ),
                        const SizedBox(height: 12),
                        if (item['paymentMethod'] != 'cash') ...[
                          FakeQr(seed: '${item['code']}'),
                          const SizedBox(height: 8),
                          Text('Nội dung chuyển khoản: ${item['code']}'),
                          Text(
                            item['paymentMethod'] == 'momo'
                                ? 'MoMo: 0906 688 190'
                                : 'Vietcombank 0123456789',
                          ),
                          const Text('Chủ tài khoản: PHONG KHAM CLINICCARE'),
                          const Text(
                            'Mã minh họa để đối soát tại quầy. Không trừ tiền MoMo thật.',
                            style: TextStyle(color: muted),
                          ),
                          const SizedBox(height: 8),
                          if (item['paid'] != true)
                            FilledButton(
                              onPressed: busy ? null : _pay,
                              child: const Text('Tôi đã thanh toán'),
                            ),
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go(
                            '/history?code=${item['code']}&phone=${item['phone']}',
                          ),
                          child: const Text('Xem trong tra cứu'),
                        ),
                      ],
                    ),
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.code, this.phone});
  final String? code;
  final String? phone;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final code = TextEditingController(text: widget.code ?? '');
  late final phone = TextEditingController(
    text: widget.phone ?? session.user?['phone']?.toString() ?? '',
  );
  List<Map<String, dynamic>> mine = [];
  Map<String, dynamic>? found;
  Map<String, dynamic>? record;
  String? recordId;

  @override
  void initState() {
    super.initState();
    _loadMine();
    if ((widget.code ?? '').isNotEmpty && (widget.phone ?? '').isNotEmpty)
      _lookup();
  }

  @override
  void dispose() {
    code.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    if (session.user == null) return;
    try {
      final data = await session.api.get('/api/me/appointments');
      if (mounted) setState(() => mine = asList(data['appointments']));
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  Future<void> _lookup() async {
    setState(() {
      found = null;
      record = null;
      recordId = null;
    });
    try {
      final data = await session.api.get('/api/appointments/lookup', {
        'code': code.text.trim(),
        'phone': phone.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        found = asMap(data['appointment']);
        recordId = data['recordId'] as String?;
        final recordData = data['record'];
        record = recordData is Map ? asMap(recordData) : null;
      });
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  Future<void> _cancel(Map<String, dynamic> item) async {
    final direct = canModifyAppointment(item);
    if (direct) {
      final ok = await confirmDialog(
        context,
        'Hủy lịch',
        'Hủy lịch ${item['code']}?',
      );
      if (!ok) return;
      await _act(
        session.user == null
            ? '/api/appointments/guest-cancel'
            : '/api/appointments/${item['id']}/cancel',
        item,
        guestBody: true,
      );
      return;
    }
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yêu cầu hỗ trợ hủy'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Lý do'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final path = session.user == null
        ? '/api/appointments/guest-support'
        : '/api/appointments/${item['id']}/support-cancel';
    try {
      final body = {
        'reason': reason.text,
        'code': item['code'],
        'phone': item['phone'],
      };
      final result = await session.api.post(path, body);
      toast('${result['message']}');
      await _loadMine();
      await _lookup();
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  Future<void> _act(
    String path,
    Map<String, dynamic> item, {
    bool guestBody = false,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final body = {'code': item['code'], 'phone': item['phone'], ...?extra};
      final result = await session.api.post(
        path,
        guestBody || session.user == null ? body : extra,
      );
      toast('${result['message'] ?? 'Đã cập nhật lịch khám.'}');
      await _loadMine();
      if (code.text.isNotEmpty) await _lookup();
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  Future<void> _reschedule(Map<String, dynamic> item) async {
    var date = DateTime.tryParse('${item['date']}') ?? DateTime.now();
    var time = '${item['time']}';
    var branchId = '${item['branchId']}';
    var doctorId = '${item['doctorId']}';
    List<Map<String, dynamic>> slots = [];
    Future<void> load(StateSetter setLocal) async {
      final data = await session.api.get('/api/slots', {
        'branchId': branchId,
        'date': isoDate(date),
        'doctorId': doctorId,
      });
      setLocal(() => slots = asList(data['slots']));
    }

    var started = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          if (!started) {
            started = true;
            load(setLocal);
          }
          return AlertDialog(
            title: const Text('Đổi lịch'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(formatDate(isoDate(date))),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked == null) return;
                      date = picked;
                      await load(setLocal);
                    },
                  ),
                  Wrap(
                    spacing: 6,
                    children: slots.map((slot) {
                      final full =
                          slot['full'] == true && slot['time'] != item['time'];
                      return ChoiceChip(
                        label: Text('${slot['time']}'),
                        selected: slot['time'] == time,
                        onSelected: full
                            ? null
                            : (_) => setLocal(() => time = '${slot['time']}'),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Đóng'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final path = session.user == null
        ? '/api/appointments/guest-reschedule'
        : '/api/appointments/${item['id']}/reschedule';
    await _act(
      path,
      item,
      guestBody: true,
      extra: {
        'date': isoDate(date),
        'time': time,
        'branchId': branchId,
        'doctorId': doctorId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PublicShell(
      child: ListView(
        children: [
          PageWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tra cứu lịch khám',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: code,
                          decoration: const InputDecoration(
                            labelText: 'Mã lịch',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _lookup,
                        child: const Text('Tra cứu'),
                      ),
                    ],
                  ),
                ),
                if (found != null) ...[
                  const SizedBox(height: 12),
                  _AppointmentCard(
                    item: found!,
                    onCancel: () => _cancel(found!),
                    onReschedule: () => _reschedule(found!),
                    onResult: recordId == null
                        ? null
                        : () => context.go('/results?id=$recordId'),
                  ),
                  if (record != null) ...[
                    const SizedBox(height: 12),
                    _MedicalRecordCard(record: record!),
                  ],
                ],
                if (session.user != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Lịch của tôi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (mine.isEmpty)
                    const Text(
                      'Bạn chưa có lịch khám.',
                      style: TextStyle(color: muted),
                    ),
                  ...mine.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AppointmentCard(
                        item: item,
                        onCancel: () => _cancel(item),
                        onReschedule: () => _reschedule(item),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.item,
    required this.onCancel,
    required this.onReschedule,
    this.onResult,
  });
  final Map<String, dynamic> item;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;
  final VoidCallback? onResult;

  @override
  Widget build(BuildContext context) {
    final open = item['status'] == 'pending' || item['status'] == 'confirmed';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${item['code']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(width: 8),
              StatusChip('${item['status']}'),
              const Spacer(),
              Text(
                formatVnd(item['amount'] as int? ?? 0),
                style: const TextStyle(
                  color: teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${item['patientName']} · ${item['packageName']}'),
          Text(
            '${item['branchName']} · ${formatDate('${item['date']}')} ${item['time']} · ${item['doctorName']}',
          ),
          Text(
            '${paymentLabel('${item['paymentMethod']}')} · ${item['paid'] == true ? 'Đã thanh toán' : 'Chưa thanh toán'}',
          ),
          if (item['cancelRequestStatus'] == 'open')
            const Text(
              'Đang chờ phòng khám xử lý yêu cầu hủy.',
              style: TextStyle(color: Color(0xFFB54708)),
            ),
          if (open)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: onReschedule,
                  child: Text(
                    canModifyAppointment(item)
                        ? 'Đổi lịch'
                        : 'Chưa đủ điều kiện đổi',
                  ),
                ),
                TextButton(
                  onPressed: onCancel,
                  child: Text(
                    canModifyAppointment(item) ? 'Hủy lịch' : 'Xin hỗ trợ hủy',
                  ),
                ),
                if (onResult != null)
                  TextButton(
                    onPressed: onResult,
                    child: const Text('Xem kết quả'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MedicalRecordCard extends StatelessWidget {
  const _MedicalRecordCard({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final prescription = asList(record['prescription']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hồ sơ khám',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),
          const SizedBox(height: 8),
          _recordField('Chẩn đoán', record['diagnosis']),
          _recordField('Hướng xử trí', record['treatment']),
          _recordField('Ghi chú', record['notes']),
          if (prescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Đơn thuốc',
              style: TextStyle(fontWeight: FontWeight.w700, color: navy),
            ),
            ...prescription.map((medicine) {
              final details =
                  [
                        medicine['dosage'],
                        medicine['usage'],
                        if (medicine['days'] != null && medicine['days'] != 0)
                          '${medicine['days']} ngày',
                        medicine['quantity'],
                        medicine['note'],
                      ]
                      .where(
                        (value) => value != null && '$value'.trim().isNotEmpty,
                      )
                      .join(' · ');
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${medicine['name']}${details.isEmpty ? '' : ' — $details'}',
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _recordField(String label, dynamic value) {
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('$label: $text'),
    );
  }
}

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, required this.id});
  final String id;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  Map<String, dynamic>? record;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await session.api.get('/api/records/${widget.id}');
      if (mounted) setState(() => record = asMap(data['record']));
    } on ApiException catch (error) {
      if (mounted) setState(() => this.error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = record;
    return PublicShell(
      child: ListView(
        children: [
          PageWidth(
            child: AppCard(
              child: item == null
                  ? Text(error ?? 'Đang tải kết quả...')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kết quả ${item['code']}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: navy,
                          ),
                        ),
                        Text(
                          '${item['patientName']} · ${formatDate('${item['date']}')} ${item['time']}',
                        ),
                        const SizedBox(height: 8),
                        Text('Chẩn đoán: ${item['diagnosis']}'),
                        Text('Hướng xử trí: ${item['treatment']}'),
                        Text('Ghi chú: ${item['notes']}'),
                        const SizedBox(height: 10),
                        const Text(
                          'Đơn thuốc',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        ...asList(item['prescription']).map(
                          (medicine) => Text(
                            '• ${medicine['name']} ${medicine['dosage']} — ${medicine['usage']}',
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}

void showPackageTests(BuildContext context, Map<String, dynamic> item) {
  final tests =
      (item['tests'] as List?)?.map((test) => '$test').toList() ??
      const <String>[];
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${item['name']}'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              '${item['testCount']} chỉ số · ${formatVnd(item['price'] as int? ?? 0)}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 8),
            ...tests.map(
              (test) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• $test'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            context.go('/booking?package=${item['id']}');
          },
          child: const Text('Đặt gói này'),
        ),
      ],
    ),
  );
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicShell(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '404',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            const Text('Không tìm thấy trang này.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    );
  }
}
