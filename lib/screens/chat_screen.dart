import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService();
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;
  File? _pendingFile;
  Timer? _poll;

  static const int _maxAttachmentBytes = 5 * 1024 * 1024; // 5MB — same limit as the website

  @override
  void initState() {
    super.initState();
    _load();
    // Simple polling keeps this dependency-free — swap for a socket/push
    // channel later if you want truly real-time delivery.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final res = await _api.fetchChat();
    if (!mounted) return;
    setState(() {
      _messages = res['success'] == true ? res['messages'] : [];
      _loading = false;
    });
    if (!silent) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    if (await file.length() > _maxAttachmentBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File is too large. Maximum size is 5MB.')));
      return;
    }
    setState(() => _pendingFile = file);
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty && _pendingFile == null) return;
    setState(() => _sending = true);
    final attachment = _pendingFile;
    _messageCtrl.clear();
    setState(() => _pendingFile = null);
    final res = await _api.sendChatMessage(text, attachment: attachment);
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Could not send message.')));
      return;
    }
    await _load();
  }

  Widget _bubble(Map m) {
    final cs = Theme.of(context).colorScheme;
    final isUser = m['sender'] == 'user';
    final String message = (m['message'] ?? '').toString();
    final String? attachmentUrl = m['attachment'] as String?;
    final String attachmentType = (m['attachment_type'] ?? '').toString();
    final String attachmentName = (m['attachment_name'] ?? 'Document.pdf').toString();
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        gradient: isUser ? LinearGradient(colors: [cs.primary, cs.primary.withOpacity(0.82)]) : null,
        color: isUser ? null : cs.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 5),
          bottomRight: Radius.circular(isUser ? 5 : 20),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isNotEmpty) Text(message, style: TextStyle(color: isUser ? Colors.white : null, height: 1.3)),
          if (attachmentUrl != null) ...[
            if (message.isNotEmpty) const SizedBox(height: 6),
            if (attachmentType == 'image')
              GestureDetector(
                onTap: () => _openImageViewer(attachmentUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    attachmentUrl,
                    width: 190,
                    height: 190,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) => progress == null
                        ? child
                        : const SizedBox(width: 190, height: 190, child: Center(child: CircularProgressIndicator())),
                    errorBuilder: (ctx, error, stack) => const SizedBox(width: 190, height: 190, child: Center(child: Icon(Icons.broken_image_outlined))),
                  ),
                ),
              )
            else
              InkWell(
                onTap: () => launchUrl(Uri.parse(attachmentUrl), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: (isUser ? Colors.white : Colors.black).withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 18, color: isUser ? Colors.white : null),
                      const SizedBox(width: 6),
                      Flexible(child: Text(attachmentName, overflow: TextOverflow.ellipsis, style: TextStyle(color: isUser ? Colors.white : null, fontSize: 12.5))),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerRight,
            child: Text(m['created_at'].toString().substring(5, 16), style: TextStyle(fontSize: 10, color: isUser ? Colors.white70 : Colors.grey)),
          ),
        ],
      ),
    );
    if (isUser) return Align(alignment: Alignment.centerRight, child: bubble);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(radius: 15, backgroundColor: cs.primaryContainer, child: Icon(Icons.support_agent, size: 18, color: cs.primary)),
        const SizedBox(width: 8),
        Flexible(child: bubble),
      ],
    );
  }

  Widget _quickChip(String label, String send) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        shape: StadiumBorder(side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.4))),
        backgroundColor: Theme.of(context).colorScheme.surface,
        onPressed: _sending ? null : () { _messageCtrl.text = send; _send(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: cs.primary,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [cs.primary, const Color(0xFF0B7D55)]))),
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.support_agent, color: Colors.white)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('KATSINASUB Support', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('We reply as soon as possible', style: TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        color: cs.primaryContainer.withOpacity(0.22),
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(radius: 38, backgroundColor: cs.primaryContainer, child: Icon(Icons.chat_bubble_outline, size: 36, color: cs.primary)),
                                const SizedBox(height: 14),
                                const Text('Say hello!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                const Text('Ask us anything about your account, wallet or an order. Tap a button below to start quickly.', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) => _bubble(_messages[i] as Map),
                        ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _quickChip('Menu', 'menu'),
                  _quickChip('Check a transaction', '1'),
                  _quickChip('Fund my wallet', '2'),
                  _quickChip('Rewards', '10'),
                  _quickChip('Talk to a person', '9'),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(color: cs.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))]),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    if (_pendingFile != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_pendingFile!.path.split('/').last, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
                            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _pendingFile = null)),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
                      child: Row(
                        children: [
                          IconButton(icon: Icon(Icons.attach_file, color: cs.primary), tooltip: tr('Attach a photo, screenshot, or PDF'), onPressed: _sending ? null : _pickAttachment),
                          Expanded(
                            child: TextField(
                              controller: _messageCtrl,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: tr('Type a message...'),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest.withOpacity(0.6),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _sending ? null : _send,
                            borderRadius: BorderRadius.circular(26),
                            child: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [cs.primary, const Color(0xFF0B7D55)])),
                              child: _sending
                                  ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send_rounded, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer(String url) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      backgroundColor: Colors.black,
      body: Center(child: InteractiveViewer(child: Image.network(url))),
    )));
  }
}
