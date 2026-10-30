import 'dart:convert';

import 'package:cliniccare/api.dart';
import 'package:cliniccare/format.dart';
import 'package:cliniccare/session.dart';
import 'package:cliniccare/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.from});

  final String? from;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => busy = true);
    try {
      final user = await session.login(email.text, password.text);
      if (!mounted) return;
      final role = user['role'];
      final backToBooking = widget.from != null && widget.from!.startsWith('/booking') && !widget.from!.startsWith('//');
      if (role == 'admin') {
        context.go('/dashboard/overview');
      } else if (role == 'doctor') {
        context.go('/records');
      } else {
        context.go(backToBooking ? widget.from! : '/');
      }
    } on ApiException catch (error) {
      toast(error.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return PublicShell(
      child: ListView(
        children: [
          PageWidth(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đăng nhập', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
                      const SizedBox(height: 12),
                      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 10),
                      PasswordField(controller: password, label: 'Mật khẩu', onSubmitted: (_) => _login()),
                      const SizedBox(height: 14),
                      FilledButton(onPressed: busy ? null : _login, child: const Text('Đăng nhập')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(onPressed: () => context.go('/register'), child: const Text('Tạo tài khoản')),
                          TextButton(onPressed: () => context.go('/forgot-password'), child: const Text('Quên mật khẩu')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  String gender = 'female';
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (password.text != confirm.text) {
      toast('Mật khẩu nhập lại chưa khớp.');
      return;
    }
    setState(() => busy = true);
    try {
      final result = await session.api.post('/api/auth/register', {
        'fullName': name.text,
        'email': email.text,
        'phone': phone.text,
        'password': password.text,
        'gender': gender,
      });
      if (!mounted) return;
      context.go('/verify-email?email=${result['email']}&code=${result['verifyCode']}');
    } on ApiException catch (error) {
      toast(error.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return PublicShell(
      child: ListView(
        children: [
          PageWidth(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppCard(
                  child: Column(
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: Text('Đăng ký', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy))),
                      const SizedBox(height: 12),
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Họ tên')),
                      const SizedBox(height: 10),
                      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 10),
                      TextField(controller: phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
                      const SizedBox(height: 10),
                      PasswordField(controller: password, label: 'Mật khẩu'),
                      const SizedBox(height: 10),
                      PasswordField(controller: confirm, label: 'Nhập lại mật khẩu'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: gender,
                        items: const [
                          DropdownMenuItem(value: 'female', child: Text('Nữ')),
                          DropdownMenuItem(value: 'male', child: Text('Nam')),
                          DropdownMenuItem(value: 'other', child: Text('Khác')),
                        ],
                        onChanged: (value) => setState(() => gender = value ?? 'other'),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(onPressed: busy ? null : _submit, child: const Text('Tạo tài khoản')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key, required this.email, this.code});
  final String email;
  final String? code;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  late final email = TextEditingController(text: widget.email);
  late final code = TextEditingController(text: widget.code ?? '');

  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      final result = await session.api.post('/api/auth/verify', {'email': email.text, 'code': code.text});
      toast('${result['message']}');
      if (mounted) context.go('/login');
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthCard(
      title: 'Xác thực email',
      child: Column(
        children: [
          const Text('Bản demo hiển thị mã ngay trên màn hình vì chưa gắn máy chủ email.', style: TextStyle(color: muted)),
          const SizedBox(height: 10),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Mã xác thực')),
          const SizedBox(height: 12),
          FilledButton(onPressed: _submit, child: const Text('Xác thực')),
        ],
      ),
    );
  }
}

class ForgotPage extends StatefulWidget {
  const ForgotPage({super.key});

  @override
  State<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends State<ForgotPage> {
  final email = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      final result = await session.api.post('/api/auth/forgot', {'email': email.text});
      if (!mounted) return;
      context.go('/reset-password?token=${result['resetToken']}&email=${result['email']}');
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthCard(
      title: 'Quên mật khẩu',
      child: Column(
        children: [
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email đã đăng ký')),
          const SizedBox(height: 12),
          FilledButton(onPressed: _submit, child: const Text('Tạo liên kết đặt lại')),
        ],
      ),
    );
  }
}

class ResetPage extends StatefulWidget {
  const ResetPage({super.key, required this.token, this.email});
  final String token;
  final String? email;

  @override
  State<ResetPage> createState() => _ResetPageState();
}

class _ResetPageState extends State<ResetPage> {
  final password = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (password.text != confirm.text) {
      toast('Mật khẩu nhập lại chưa khớp.');
      return;
    }
    try {
      final result = await session.api.post('/api/auth/reset', {'token': widget.token, 'password': password.text});
      toast('${result['message']}');
      if (mounted) context.go('/login');
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthCard(
      title: 'Đặt lại mật khẩu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email: ${widget.email ?? ''}', style: const TextStyle(color: muted)),
          const SizedBox(height: 8),
          const Text('Liên kết demo có hiệu lực 30 phút.', style: TextStyle(color: muted)),
          const SizedBox(height: 10),
          PasswordField(controller: password, label: 'Mật khẩu mới'),
          const SizedBox(height: 10),
          PasswordField(controller: confirm, label: 'Nhập lại mật khẩu'),
          const SizedBox(height: 12),
          FilledButton(onPressed: widget.token.isEmpty ? null : _submit, child: const Text('Lưu mật khẩu')),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final name = TextEditingController(text: '${session.user?['fullName'] ?? ''}');
  late final phone = TextEditingController(text: '${session.user?['phone'] ?? ''}');
  late final address = TextEditingController(text: '${session.user?['address'] ?? ''}');
  late final dob = TextEditingController(text: '${session.user?['dateOfBirth'] ?? ''}');
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  late String gender = '${session.user?['gender'] ?? 'other'}';
  String? avatar = session.user?['avatarUrl'] as String?;
  List<Map<String, dynamic>> records = [];

  @override
  void initState() {
    super.initState();
    _records();
  }

  Future<void> _records() async {
    try {
      final data = await session.api.get('/api/me/records');
      if (mounted) setState(() => records = asList(data['records']));
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    if (bytes.length > 350000) {
      toast('Ảnh đại diện vượt quá 350KB.');
      return;
    }
    setState(() => avatar = 'data:image/png;base64,${base64Encode(bytes)}');
  }

  Future<void> _save() async {
    try {
      final result = await session.api.put('/api/me', {
        'fullName': name.text,
        'phone': phone.text,
        'gender': gender,
        'dateOfBirth': dob.text,
        'address': address.text,
        'avatarUrl': avatar,
      });
      await session.refreshUser(asMap(result['user']));
      toast('Đã lưu hồ sơ cá nhân.');
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  Future<void> _password() async {
    try {
      final result = await session.api.put('/api/me/password', {
        'currentPassword': currentPassword.text,
        'newPassword': newPassword.text,
      });
      toast('${result['message']}');
      currentPassword.clear();
      newPassword.clear();
    } on ApiException catch (error) {
      toast(error.message);
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    dob.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    super.dispose();
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
                const Text('Hồ sơ cá nhân', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: navy)),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: avatar == null ? null : MemoryImage(base64Decode(avatar!.split(',').last)),
                            child: avatar == null ? Text(initials(name.text)) : null,
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(onPressed: _pickAvatar, child: const Text('Đổi ảnh')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Họ tên')),
                      const SizedBox(height: 10),
                      TextField(controller: phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
                      const SizedBox(height: 10),
                      TextField(controller: dob, decoration: const InputDecoration(labelText: 'Ngày sinh (yyyy-mm-dd)')),
                      const SizedBox(height: 10),
                      TextField(controller: address, decoration: const InputDecoration(labelText: 'Địa chỉ')),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: gender,
                        items: const [
                          DropdownMenuItem(value: 'female', child: Text('Nữ')),
                          DropdownMenuItem(value: 'male', child: Text('Nam')),
                          DropdownMenuItem(value: 'other', child: Text('Khác')),
                        ],
                        onChanged: (value) => setState(() => gender = value ?? 'other'),
                      ),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: _save, child: const Text('Lưu hồ sơ'))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.w800, color: navy))),
                      const SizedBox(height: 10),
                      PasswordField(controller: currentPassword, label: 'Mật khẩu hiện tại'),
                      const SizedBox(height: 10),
                      PasswordField(controller: newPassword, label: 'Mật khẩu mới'),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: _password, child: const Text('Đổi mật khẩu'))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Kết quả của tôi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
                const SizedBox(height: 8),
                if (records.isEmpty) const Text('Chưa có hồ sơ khám.', style: TextStyle(color: muted)),
                ...records.map((record) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${record['code']} · ${record['packageName']}'),
                          subtitle: Text('${formatDate('${record['date']}')} · ${record['diagnosis']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/results?id=${record['id']}'),
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PublicShell(
      child: ListView(
        children: [
          PageWidth(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)),
                      const SizedBox(height: 12),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
