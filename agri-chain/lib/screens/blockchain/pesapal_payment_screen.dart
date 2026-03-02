import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Embeds PesaPal's hosted checkout page inside the app.
/// Returns the payment result when the callback URL is detected.
///
/// Android fix: PesaPal uses HTTP 302 redirects to the callback URL.
/// Android WebView may skip `onNavigationRequest` for server-initiated
/// redirects, so we also check in `onPageStarted` and `onUrlChange`.
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
  bool _callbackHandled = false; // guard against double-pop

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _loading = true);
            // Android: catch 302 redirects here before onPageFinished fires
            _tryHandleCallback(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _loading = false);
            _tryHandleCallback(url);
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              _tryHandleCallback(change.url!);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_tryHandleCallback(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description} (${error.errorCode})');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  /// Returns true and pops if the URL matches the PesaPal callback pattern.
  /// Safe to call multiple times — uses [_callbackHandled] guard.
  bool _tryHandleCallback(String url) {
    if (_callbackHandled) return true;

    final isCallback = url.contains('/payments/callback') ||
        url.contains('OrderTrackingId');

    if (isCallback) {
      _callbackHandled = true;
      final uri = Uri.tryParse(url);
      final trackingId = uri?.queryParameters['OrderTrackingId'] ?? '';
      final reference = uri?.queryParameters['OrderMerchantReference'] ?? '';

      if (mounted) {
        // Small delay so onNavigationRequest can return NavigationDecision.prevent
        // before the pop, avoiding a WebView lifecycle crash on some Android versions.
        Future.microtask(() {
          if (mounted) {
            Navigator.pop(context, {
              'completed': true,
              'trackingId': trackingId,
              'reference': reference,
            });
          }
        });
      }
      return true;
    }
    return false;
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
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading PesaPal checkout...'),
                    SizedBox(height: 8),
                    Text(
                      'Please wait while the payment page loads.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
