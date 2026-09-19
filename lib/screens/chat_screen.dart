import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Chat')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet — say hello!'))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          final isUser = m['sender'] == 'user';
                          final String message = (m['message'] ?? '').toString();
                          final String? attachmentUrl = m['attachment'] as String?;
                          final String attachmentType = (m['attachment_type'] ?? '').toString();
                          final String attachmentName = (m['attachment_name'] ?? 'Document.pdf').toString();
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.isNotEmpty) Text(message, style: TextStyle(color: isUser ? Colors.white : null)),
                                  if (attachmentUrl != null) ...[
                                    if (message.isNotEmpty) const SizedBox(height: 6),
                                    if (attachmentType == 'image')
                                      GestureDetector(
                                        onTap: () => _openImageViewer(attachmentUrl),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            attachmentUrl,
                                            width: 180,
                                            height: 180,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (ctx, child, progress) => progress == null
                                                ? child
                                                : const SizedBox(width: 180, height: 180, child: Center(child: CircularProgressIndicator())),
                                            errorBuilder: (ctx, error, stack) => const SizedBox(
                                              width: 180, height: 180,
                                              child: Center(child: Icon(Icons.broken_image_outlined)),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      InkWell(
                                        onTap: () => launchUrl(Uri.parse(attachmentUrl), mode: LaunchMode.externalApplication),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: (isUser ? Colors.white : Colors.black).withOpacity(.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
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
                                  const SizedBox(height: 2),
                                  Text(m['created_at'].toString().substring(5, 16),
                                      style: TextStyle(fontSize: 10, color: isUser ? Colors.white70 : Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Column(
              children: [
                if (_pendingFile != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_pendingFile!.path.split('/').last, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _pendingFile = null),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        tooltip: 'Attach a photo, screenshot, or PDF',
                        onPressed: _sending ? null : _pickAttachment,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageCtrl,
                          decoration: const InputDecoration(hintText: 'Type a message...', border: OutlineInputBorder()),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton(
                        icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                        onPressed: _sending ? null : _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
