import 'package:cliniccare/format.dart';
import 'package:cliniccare/session.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const ink = Color(0xFF16354D);
const muted = Color(0xFF496276);
const teal = Color(0xFF087F8C);
const tealDark = Color(0xFF066570);
const navy = Color(0xFF123B5D);
const line = Color(0xFFE3EAF2);
const pageBg = Color(0xFFF4F7FB);

final messengerKey = GlobalKey<ScaffoldMessengerState>();

void toast(String message) {
  messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

Future<bool> confirmDialog(BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Đóng')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
      ],
    ),
  );
  return result == true;
}

class Logo extends StatelessWidget {
  const Logo({super.key, this.light = false, this.compact = false});
  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.monitor_heart, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ClinicCare', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18, height: 1.1)),
            if (!compact)
              Text('PHÒNG KHÁM VÌ DÂN', style: TextStyle(color: light ? Colors.white70 : muted, fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' || 'completed' => const Color(0xFF0F7B4C),
      'cancelled' => const Color(0xFFB42318),
      'pending' || 'examining' => const Color(0xFFB54708),
      _ => muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(statusLabel(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: child,
    );
  }
}

class PublicShell extends StatelessWidget {
  const PublicShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final path = GoRouterState.of(context).uri.path;
    return Scaffold(
      backgroundColor: pageBg,
      drawer: wide ? null : Drawer(child: _menu(context, path, true)),
      body: Column(
        children: [
          const _TopBar(),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: ListenableBuilder(
                  listenable: session,
                  builder: (context, _) => Row(
                    children: [
                      InkWell(onTap: () => context.go('/'), child: const Logo()),
                      const Spacer(),
                      if (wide) _menu(context, path, false) else Builder(
                        builder: (context) => IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu, color: navy)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, String path, bool vertical) {
    final items = [
      ('/', 'Trang chủ'),
      ('/packages', 'Gói khám'),
      ('/?section=specialty', 'Chuyên khoa'),
      ('/?section=doctors', 'Đội ngũ bác sĩ'),
      ('/history', 'Tra cứu'),
    ];
    final links = items.map((item) {
      final active = item.$1 == path;
      return TextButton(
        onPressed: () => context.go(item.$1),
        child: Text(item.$2, style: TextStyle(color: active ? teal : ink, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      );
    }).toList();
    final account = TextButton(
      onPressed: () => context.go(sessionUserPath()),
      child: Text(sessionName(), style: const TextStyle(color: ink, fontWeight: FontWeight.w600)),
    );
    final book = FilledButton(onPressed: () => context.go('/booking'), child: const Text('Đặt lịch khám'));
    final logout = TextButton.icon(
      onPressed: () async {
        await sessionLogout();
        if (context.mounted) context.go('/login');
      },
      icon: const Icon(Icons.logout, size: 18),
      label: const Text('Đăng xuất'),
    );
    if (vertical) {
      return ListView(padding: const EdgeInsets.all(16), children: [const Logo(), const SizedBox(height: 12), ...links, account, const SizedBox(height: 8), book, if (session.user != null) logout]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [...links, account, const SizedBox(width: 8), book, if (session.user != null) logout]);
  }
}

String sessionUserPath() {
  final role = session.user?['role'];
  if (role == 'admin') return '/dashboard/overview';
  if (role == 'doctor') return '/records';
  if (session.user != null) return '/profile';
  return '/login';
}

String sessionName() => session.user == null ? 'Tài khoản' : '${session.user!['fullName']}';

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.label, this.onSubmitted});
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool hidden = true;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: hidden,
    enableSuggestions: false,
    autocorrect: false,
    onSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        onPressed: () => setState(() => hidden = !hidden),
        icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: navy,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: const Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [
              Text('Hotline 1900 6688', style: TextStyle(color: Colors.white, fontSize: 12)),
              Text('Thứ 2 – CN  07:00 – 20:00', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('168 Nguyễn Trãi, Thanh Xuân, Hà Nội', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('cskh@cliniccare.vn', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: navy,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Logo(light: true),
              SizedBox(height: 10),
              Text('Chăm sóc sức khỏe chuẩn quốc tế, tận tâm vì bạn.', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 6),
              Text('Thanh Xuân · Cầu Giấy · Hải Châu', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 28)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PortalShell extends StatelessWidget {
  const PortalShell({super.key, required this.section, required this.child});
  final String section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final menu = _PortalMenu(section: section);
    return Scaffold(
      backgroundColor: pageBg,
      drawer: wide ? null : Drawer(child: menu),
      body: Row(
        children: [
          if (wide) SizedBox(width: 250, child: menu),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      if (!wide)
                        Builder(builder: (context) => IconButton(onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu))),
                      const Text('Khu vực nội bộ', style: TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 18)),
                      const Spacer(),
                      ListenableBuilder(
                        listenable: session,
                        builder: (context, _) => Text(sessionDisplay(), style: const TextStyle(color: muted)),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String sessionDisplay() {
  final user = session.user;
  if (user == null) return '';
  return '${user['fullName']} · ${roleLabel('${user['role']}')}';
}

class _PortalMenu extends StatelessWidget {
  const _PortalMenu({required this.section});
  final String section;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: navy,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        children: [
          const Logo(light: true),
          const SizedBox(height: 22),
          if (session.isAdmin) ...[
            _item(context, 'overview', 'Tổng quan', Icons.space_dashboard),
            _item(context, 'doctors', 'Bác sĩ', Icons.medical_services),
            _item(context, 'appointments', 'Lịch khám', Icons.event_note),
          ],
          if (session.isAdmin || session.isDoctor) ...[
            if (session.isDoctor) _item(context, 'appointments', 'Lịch khám của tôi', Icons.event_note),
            _item(context, 'accounts', 'Tài khoản', Icons.people),
          ],
          if (session.isAdmin) ...[
            _item(context, 'medicines', 'Thuốc', Icons.medication),
            _item(context, 'payments', 'Thanh toán', Icons.payments),
          ],
          _link(context, '/records', 'Hồ sơ khám', Icons.folder_shared, section == 'records'),
          const Divider(color: Colors.white24, height: 28),
          _link(context, '/', 'Về trang chủ', Icons.home, false),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white70),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
            onTap: () async {
              await sessionLogout();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, String id, String label, IconData icon) {
    return _link(context, '/dashboard/$id', label, icon, section == id);
  }

  Widget _link(BuildContext context, String path, String label, IconData icon, bool active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: active ? Colors.white.withValues(alpha: 0.12) : null,
        leading: Icon(icon, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onTap: () => context.go(path),
      ),
    );
  }
}

Future<void> sessionLogout() => session.logout();

class FakeQr extends StatelessWidget {
  const FakeQr({super.key, required this.seed});
  final String seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(148, 148),
      painter: _QrPainter(seed),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.seed);
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = navy;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    const cells = 21;
    final cell = size.width / cells;
    var hash = seed.codeUnits.fold<int>(0, (sum, code) => (sum * 33 + code) & 0x7fffffff);
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        hash = (hash * 1103515245 + 12345) & 0x7fffffff;
        final finder = (x < 6 && y < 6) || (x > 14 && y < 6) || (x < 6 && y > 14);
        final on = finder ? (x == 0 || y == 0 || x == 5 || y == 5 || (x > 1 && x < 4 && y > 1 && y < 4)) : hash % 3 != 0;
        if (on) canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell - 0.4, cell - 0.4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => oldDelegate.seed != seed;
}
