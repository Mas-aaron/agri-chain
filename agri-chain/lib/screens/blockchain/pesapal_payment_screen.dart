import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Embeds PesaPal's hosted checkout page inside the app.
/// Returns the payment result when the callback URL is detected.
class PesapalPaymentScreen extends StatefulWidget {
  final String checkoutUrl;
  final String callbackDomain; // e.g. "101.44.10.153"

  const PesapalPaymentScreen({
    super.key,
    required this.checkoutUrl,
    this.callbackDomain = "101.44.10.153",
  });

  @override
  State<PesapalPaymentScreen> createState() => _PesapalPaymentScreenState();
}

class _PesapalPaymentScreenState extends State<PesapalPaymentScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _loading = false);

            // Detect when PesaPal redirects to our callback URL
            if (url.contains(widget.callbackDomain) &&
                url.contains("/payments/callback")) {
              // Extract tracking ID from URL params
              final uri = Uri.tryParse(url);
              final trackingId =
                  uri?.queryParameters['OrderTrackingId'] ?? '';
              final reference =
                  uri?.queryParameters['OrderMerchantReference'] ?? '';

              // Return result to payment flow
              Navigator.pop(context, {
                'completed': true,
                'trackingId': trackingId,
                'reference': reference,
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, {'completed': false}),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading PesaPal checkout...'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
