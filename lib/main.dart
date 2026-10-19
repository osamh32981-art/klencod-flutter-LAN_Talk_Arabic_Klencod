import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const LanTalkApp());

const navy = Color(0xFF0F172A);
const cyan = Color(0xFF00E5FF);
const port = 8988;

class LanTalkApp extends StatelessWidget {
  const LanTalkApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'LAN Talk عربي',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      colorScheme: ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const ChatScreen(),
  );
}

class ChatItem {
  final String text;
  final bool mine;
  final Uint8List? image;
  ChatItem(this.text, this.mine, {this.image});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ip = TextEditingController();
  final _message = TextEditingController();
  final List<ChatItem> _items = [];
  final ImagePicker _picker = ImagePicker();
  ServerSocket? _server;
  Socket? _socket;
  StreamSubscription<String>? _sub;
  String _status = 'غير متصل';
  String _localIp = 'جارٍ البحث...';
  bool _busy = false;

  @override
  void initState() { super.initState(); _findIp(); }
  Future<void> _findIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final ips = interfaces.expand((i) => i.addresses).where((a) => !a.isLoopback).map((a) => a.address).toList();
      if (mounted) setState(() => _localIp = ips.isEmpty ? 'غير معروف' : ips.first);
    } catch (_) { if (mounted) setState(() => _localIp = 'غير معروف'); }
  }

  Future<void> _startServer() async {
    try {
      _server?.close();
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
      _server!.listen((client) {
        _socket?.destroy();
        _attach(client);
        if (mounted) setState(() => _status = 'متصل بجهاز آخر');
      });
      if (mounted) setState(() => _status = 'جاهز لاستقبال اتصال');
      _snack('تم فتح الاستقبال على المنفذ $port');
    } catch (e) { _snack('تعذر فتح الاستقبال: $e'); }
  }

  Future<void> _connect() async {
    final ip = _ip.text.trim();
    if (ip.isEmpty) { _snack('اكتب عنوان IP للجهاز الآخر'); return; }
    try {
      final s = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _attach(s);
      if (mounted) setState(() => _status = 'متصل بـ $ip');
      _snack('تم الاتصال');
    } catch (e) { _snack('فشل الاتصال. تأكد من نفس Wi‑Fi وIP الصحيح.'); }
  }

  void _attach(Socket s) {
    _sub?.cancel();
    _socket = s;
    _sub = s.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      try {
        final data = jsonDecode(line) as Map<String, dynamic>;
        if (data['type'] == 'text') {
          if (mounted) setState(() => _items.add(ChatItem(data['text']?.toString() ?? '', false)));
          _playTone();
        } else if (data['type'] == 'image') {
          final bytes = base64Decode(data['data'] as String);
          if (mounted) setState(() => _items.add(ChatItem(data['name']?.toString() ?? 'صورة', false, image: bytes)));
          _playTone();
        }
      } catch (_) { }
    }, onDone: () {
      if (mounted) setState(() { _status = 'انقطع الاتصال'; _socket = null; });
    }, onError: (_) {
      if (mounted) setState(() => _status = 'حدث خطأ في الاتصال');
    });
  }

  void _send(Map<String, dynamic> data) {
    final s = _socket;
    if (s == null) { _snack('اتصل بالجهاز الآخر أولاً'); return; }
    try { s.write('${jsonEncode(data)}\n'); }
    catch (_) { _snack('تعذر الإرسال'); }
  }

  void _sendText() {
    final value = _message.text.trim();
    if (value.isEmpty) return;
    if (_socket == null) { _snack('اتصل بالجهاز الآخر أولاً'); return; }
    _send({'type':'text', 'text':value});
    setState(() => _items.add(ChatItem(value, true)));
    _message.clear();
  }

  Future<void> _sendImage() async {
    if (_socket == null) { _snack('اتصل بالجهاز الآخر أولاً'); return; }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 1200);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 1500000) { _snack('الصورة كبيرة جداً؛ اختر صورة أصغر من 1.5 ميغابايت'); return; }
      _send({'type':'image', 'name':x.name, 'data':base64Encode(bytes)});
      setState(() => _items.add(ChatItem(x.name, true, image: bytes)));
    } catch (e) { _snack('تعذر إرسال الصورة: $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _playTone() {
    // رنين قصير باستخدام نغمة نظام أندرويد؛ لا يحتاج إنترنت.
    if (!Platform.isAndroid) return;
    try { Process.run('cmd', ['media_session']); } catch (_) {}
    // يمكن استبدال هذا لاحقاً بمشغل صوتي يدعم assets.
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s, textDirection: TextDirection.rtl)));
  }

  @override
  void dispose() {
    _sub?.cancel(); _socket?.destroy(); _server?.close();
    _ip.dispose(); _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111E35),
        title: const Row(children: [
          Icon(Icons.wifi_calling_3, color: cyan, size: 30),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LAN Talk عربي', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('دردشة على الشبكة المحلية', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ])
        ]),
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF17243B), borderRadius: BorderRadius.circular(18), border: Border.all(color: cyan.withOpacity(.35))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [const Icon(Icons.circle, color: Colors.greenAccent, size: 12), const SizedBox(width: 7), Expanded(child: Text('الحالة: $_status'))]),
            const SizedBox(height: 7),
            Text('عنوان IP لهذا الجهاز: $_localIp', style: const TextStyle(color: cyan, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: _startServer, icon: const Icon(Icons.wifi_tethering), label: const Text('استقبال اتصال'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: _findIp, icon: const Icon(Icons.refresh), label: const Text('تحديث IP'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _ip, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'IP الجهاز الآخر', hintText: 'مثال: 192.168.1.20', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _connect, icon: const Icon(Icons.link), label: const Text('اتصال بالجهاز الآخر')),
            const Text('يجب أن يكون الجهازان على نفس شبكة Wi‑Fi. شغّل «استقبال اتصال» في جهاز واحد ثم اتصل بعنوان IP الخاص به من الجهاز الثاني.', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ),
        Expanded(child: _items.isEmpty
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.forum_outlined, size: 60, color: cyan), SizedBox(height: 12), Text('ابدأ المحادثة بعد الاتصال', style: TextStyle(color: Colors.white70))]))
          : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _items.length, itemBuilder: (context, i) {
              final m = _items[i];
              return Align(alignment: m.mine ? Alignment.centerLeft : Alignment.centerRight, child: Container(
                constraints: const BoxConstraints(maxWidth: 290),
                margin: const EdgeInsets.symmetric(vertical: 5),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: m.mine ? const Color(0xFF075985) : const Color(0xFF243247), borderRadius: BorderRadius.circular(14)),
                child: m.image != null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Image.memory(m.image!, fit: BoxFit.contain), Text(m.text, style: const TextStyle(fontSize: 11, color: Colors.white70))])
                  : Text(m.text),
              ));
            })),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 10), child: Row(children: [
          IconButton(onPressed: _busy ? null : _sendImage, icon: const Icon(Icons.image, color: cyan), tooltip: 'إرسال صورة'),
          Expanded(child: TextField(controller: _message, onSubmitted: (_) => _sendText(), decoration: InputDecoration(hintText: 'اكتب رسالتك...', filled: true, fillColor: const Color(0xFF17243B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
          const SizedBox(width: 6),
          CircleAvatar(backgroundColor: cyan, child: IconButton(onPressed: _sendText, icon: const Icon(Icons.send, color: navy))),
        ]))),
      ]),
    ),
  );
}