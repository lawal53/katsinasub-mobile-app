import 'package:flutter/material.dart';
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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
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
