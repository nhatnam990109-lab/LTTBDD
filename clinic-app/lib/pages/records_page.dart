import 'package:cliniccare/api.dart';
import 'package:cliniccare/export.dart';
import 'package:cliniccare/format.dart';
import 'package:cliniccare/session.dart';
import 'package:cliniccare/widgets.dart';
import 'package:flutter/material.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, this.initialAppointment});
  final Map<String, dynamic>? initialAppointment;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<Map<String, dynamic>> today = [];
  List<Map<String, dynamic>> found = [];
  List<Map<String, dynamic>> medicines = [];
  Map<String, dynamic>? selected;
  Map<String, dynamic>? record;
  final search = TextEditingController();
  final diagnosis = TextEditingController();
  final treatment = TextEditingController();
  final notes = TextEditingController();
  String status = 'examining';
  List<Map<String, String>> prescription = [];
  bool loading = true;
  bool searched = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _boot();
    if (mounted && widget.initialAppointment != null) await _open(widget.initialAppointment!);
  }

  @override
  void dispose() {
    search.dispose();
    diagnosis.dispose();
    treatment.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final queue = await session.api.get('/api/clinical/today');
      final catalog = await session.api.get('/api/admin/medicines');
      today = asList(queue['appointments']);
      medicines = asList(catalog['medicines']);
    } on ApiException catch (error) {
      toast(error.message);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _search() async {
    try {
      final data = await session.api.get('/api/clinical/appointments', {'q': search.text.trim()});
      if (mounted) setState(() {
        found = asList(data['appointments']);
        searched = true;
      });
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  Future<void> _open(Map<String, dynamic> appointment) async {
    selected = appointment;
    diagnosis.text = '';
    treatment.text = '';
    notes.text = '';
    status = 'examining';
    prescription = [];
    record = null;
    try {
      final lookup = await session.api.get('/api/appointments/lookup', {
        'code': '${appointment['code']}',
        'phone': '${appointment['phone']}',
      });
      final recordId = lookup['recordId'];
      if (recordId != null) {
        final data = await session.api.get('/api/records/$recordId');
        record = asMap(data['record']);
        diagnosis.text = '${record!['diagnosis'] ?? ''}';
        treatment.text = '${record!['treatment'] ?? ''}';
        notes.text = '${record!['notes'] ?? ''}';
        status = '${record!['status'] ?? 'examining'}';
        prescription = asList(record!['prescription']).map((item) => {
              'name': '${item['name']}',
              'dosage': '${item['dosage']}',
              'usage': '${item['usage']}',
              'days': '${item['days'] ?? ''}',
              'quantity': '${item['quantity']}',
              'note': '${item['note']}',
            }).toList();
      }
    } on ApiException catch (error) {
      toast(error.message);
    }
    if (mounted) setState(() {});
  }

  void _addMedicine(Map<String, dynamic> medicine) {
    final next = [
      ...prescription,
      {
        'name': '${medicine['name']}',
        'dosage': '${medicine['dosage']}',
        'usage': '${medicine['usage']}',
        'days': '5',
        'quantity': '1 hộp',
        'note': '',
      },
    ];
    if (isDuplicateMedicine(next)) {
      toast('Thuốc này đã có trong đơn.');
      return;
    }
    setState(() => prescription = next);
    _editMedicine(next.length - 1);
  }

  Future<void> _save() async {
    if (selected == null) return;
    try {
      final data = await session.api.post('/api/clinical/records', {
        'appointmentId': selected!['id'],
        'diagnosis': diagnosis.text,
        'treatment': treatment.text,
        'notes': notes.text,
        'status': status,
        'prescription': prescription,
      });
      record = asMap(data['record']);
      toast('Đã lưu hồ sơ khám.');
      await _boot();
      if (mounted) setState(() {});
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  Future<void> _editMedicine(int index) async {
    final item = prescription[index];
    final fields = {
      'dosage': TextEditingController(text: item['dosage']),
      'usage': TextEditingController(text: item['usage']),
      'days': TextEditingController(text: item['days']),
      'quantity': TextEditingController(text: item['quantity']),
      'note': TextEditingController(text: item['note']),
    };
    const labels = {'dosage': 'Liều dùng', 'usage': 'Cách dùng', 'days': 'Số ngày', 'quantity': 'Số lượng', 'note': 'Ghi chú'};
    final saved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('${item['name']}'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: fields.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(controller: entry.value, decoration: InputDecoration(labelText: labels[entry.key]),
            keyboardType: entry.key == 'days' ? TextInputType.number : TextInputType.text),
        )).toList(),
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Đóng')),
        FilledButton(onPressed: () {
          final days = int.tryParse(fields['days']!.text.trim());
          if (days == null || days < 1 || fields['dosage']!.text.trim().isEmpty ||
              fields['usage']!.text.trim().isEmpty || fields['quantity']!.text.trim().isEmpty) {
            toast('Nhập liều dùng, cách dùng, số lượng và số ngày hợp lệ.');
            return;
          }
          Navigator.pop(context, true);
        }, child: const Text('Lưu')),
      ],
    ));
    if (saved == true && mounted) setState(() {
      prescription[index] = {...item, for (final entry in fields.entries) entry.key: entry.value.text.trim()};
    });
    // Wait for the closing dialog animation before releasing its controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in fields.values) { controller.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final queue = searched ? found : today;
    return PortalShell(
      section: 'records',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: wide ? 340 : double.infinity,
                    height: wide ? null : 320,
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hàng chờ hôm nay', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: search,
                            decoration: const InputDecoration(labelText: 'Tìm mã, tên, số điện thoại'),
                            onSubmitted: (_) => _search(),
                          ),
                          const SizedBox(height: 8),
                          Wrap(children: [
                            TextButton(onPressed: _search, child: const Text('Tìm lịch')),
                            TextButton(onPressed: () => setState(() => searched = false), child: const Text('Hôm nay')),
                          ]),
                          Expanded(
                            child: ListView(
                              children: queue.map((item) {
                                final active = selected?['id'] == item['id'];
                                return ListTile(
                                  selected: active,
                                  title: Text('${item['patientName']}'),
                                  subtitle: Text('${formatDate('${item['date']}')} ${item['time']} · ${item['code']}'),
                                  onTap: item['status'] == 'cancelled' ? null : () => _open(item),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16, height: 16),
                  Expanded(child: _form()),
                ],
              ),
            ),
    );
  }

  Widget _form() {
    if (selected == null) {
      return const AppCard(child: Text('Chọn một lịch khám để lập hồ sơ và kê đơn thuốc.'));
    }
    return ListView(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${selected!['patientName']} · ${selected!['code']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
              Text('${selected!['packageName']} · ${formatDate('${selected!['date']}')} ${selected!['time']}'),
              const SizedBox(height: 10),
              TextField(controller: diagnosis, maxLines: 2, decoration: const InputDecoration(labelText: 'Chẩn đoán')),
              const SizedBox(height: 8),
              TextField(controller: treatment, maxLines: 2, decoration: const InputDecoration(labelText: 'Hướng xử trí')),
              const SizedBox(height: 8),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Ghi chú')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('${selected?['id']}-$status'),
                initialValue: status,
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('Mới')),
                  DropdownMenuItem(value: 'examining', child: Text('Đang khám')),
                  DropdownMenuItem(value: 'completed', child: Text('Đã khám')),
                ],
                onChanged: (value) => setState(() => status = value ?? 'examining'),
              ),
              const SizedBox(height: 12),
              const Text('Đơn thuốc', style: TextStyle(fontWeight: FontWeight.w800)),
              const Text('Chọn thuốc để kê đơn. Bấm vào thuốc trong đơn để chỉnh liều, cách dùng, số ngày và số lượng.', style: TextStyle(color: muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: medicines.map((item) => ActionChip(label: Text('${item['name']} ${item['dosage']}'), onPressed: () => _addMedicine(item))).toList(),
              ),
              ...prescription.asMap().entries.map((entry) => ListTile(
                    title: Text('${entry.value['name']} ${entry.value['dosage']}'),
                    subtitle: Text('${entry.value['usage']} · ${entry.value['days']} ngày · ${entry.value['quantity']}\n${entry.value['note'] ?? ''}'),
                    onTap: () => _editMedicine(entry.key),
                    trailing: IconButton(
                      onPressed: () => setState(() => prescription.removeAt(entry.key)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(onPressed: _save, child: const Text('Lưu hồ sơ')),
                  FilledButton(onPressed: () {
                    setState(() => status = 'completed');
                    _save();
                  }, child: const Text('Hoàn tất khám và lưu đơn')),
                  if (record != null) ...[
                    OutlinedButton(onPressed: () => printHtml(recordDocument(record!)), child: const Text('In PDF')),
                    OutlinedButton(onPressed: () => exportHtml('ho-so-${record!['code']}.xls', 'application/vnd.ms-excel', recordDocument(record!)), child: const Text('Excel')),
                    OutlinedButton(onPressed: () => exportHtml('ho-so-${record!['code']}.doc', 'application/msword', recordDocument(record!)), child: const Text('Word')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
