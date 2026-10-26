import 'package:flutter/material.dart' hide Text;
import '../l10n.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A general-purpose in-app browser. Used for Fund Wallet checkout
/// (Paystack/Monnify), and reusable for any other website page you
/// want to show without leaving the app — e.g. Privacy Policy. Best
/// suited to PUBLIC pages: pages that require being logged into the
/// website won't recognize the app's login, since the app uses a
/// separate token-based session from the website's cookie session.
class CheckoutWebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  const CheckoutWebViewScreen({super.key, required this.url, this.title = 'Complete Payment'});

  @override
  State<CheckoutWebViewScreen> createState() => _CheckoutWebViewScreenState();
}

class _CheckoutWebViewScreenState extends State<CheckoutWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final startUri = Uri.tryParse(widget.url);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        // Payment pages must stay on HTTPS. Anything else (http:, file:,
        // javascript:, intent: ...) is refused for the main page; frames
        // inside the page (e.g. a bank's 3-D Secure box) are left alone.
        onNavigationRequest: (NavigationRequest request) {
          if (!request.isMainFrame) return NavigationDecision.navigate;
          final target = Uri.tryParse(request.url);
          return (target != null && target.scheme == 'https')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ));
    if (startUri != null && startUri.scheme == 'https') {
      _controller.loadRequest(startUri);
    } else {
      _loading = false; // never open a non-HTTPS payment page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, true), // treat closing as "check the result"
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
