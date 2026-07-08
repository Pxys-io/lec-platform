import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:screen_protector/screen_protector.dart';

class PanicModeScreen extends StatefulWidget {
  final String url;
  final String? token;
  final String? deviceId;

  const PanicModeScreen({
    super.key,
    required this.url,
    this.token,
    this.deviceId,
  });

  @override
  State<PanicModeScreen> createState() => _PanicModeScreenState();
}

class _PanicModeScreenState extends State<PanicModeScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
    
    final uri = Uri.parse(widget.url).replace(
      queryParameters: {
        if (widget.token != null) 'token': widget.token!,
        if (widget.deviceId != null) 'deviceId': widget.deviceId!,
      },
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.prevent,
        ),
      )
      ..loadRequest(uri);
  }

  Future<void> _enableSecureMode() async {
    await ScreenProtector.preventScreenshotOn();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
