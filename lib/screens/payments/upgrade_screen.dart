// lib/screens/payments/upgrade_screen.dart
//
// Upgrade to Pro screen — displays plan options, initiates Paystack payment
// via a WebView, verifies on redirect, then refreshes entitlements.
//
// Flow:
//  1. Screen loads → GET /payments/config (prices + public key)
//  2. Student taps a plan → POST /payments/initiate → gets authorization_url
//  3. WebView opens Paystack checkout page
//  4. Student pays → Paystack redirects to deep-link callback_url
//  5. App intercepts redirect → GET /payments/verify/{reference}
//  6. On success → reload AiProvider plan → show success → pop screen
//
// Test cards (Paystack test mode):
//   Card:    4084 0840 8408 4081
//   CVV:     408
//   Expiry:  01/99
//   OTP:     123456

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/api_client.dart';
import '../../providers/ai_provider.dart';

// ── Deep-link the app uses as Paystack callback ───────────────────────────────
// Paystack will redirect to this URL after payment. We intercept it in the
// WebView navigation delegate to know payment is complete.
const _kCallbackUrl = 'https://cssimplified.app/payment/callback';

// ══════════════════════════════════════════════════════════════════════════════
// Upgrade Screen
// ══════════════════════════════════════════════════════════════════════════════

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  Map<String, dynamic>? _config;
  bool   _loadingConfig = true;
  bool   _paying        = false;
  String? _error;

  static const _kAccent = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final data = await ApiClient.getPaymentConfig();
      setState(() { _config = data; _loadingConfig = false; });
    } catch (e) {
      setState(() { _error = 'Could not load plans. Please try again.'; _loadingConfig = false; });
    }
  }

  Future<void> _startPayment(String planId) async {
    setState(() { _paying = true; _error = null; });
    try {
      final data = await ApiClient.initiatePayment(
        planId:      planId,
        callbackUrl: _kCallbackUrl,
      );
      final authUrl   = data['authorization_url'] as String;
      final reference = data['reference']         as String;

      if (!mounted) return;
      setState(() => _paying = false);

      if (kIsWeb) {
        // On web, open in a new tab — WebView not available
        final uri = Uri.parse(authUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          // After returning, verify manually
          if (mounted) _verifyPayment(reference);
        }
      } else {
        // On mobile, open in-app WebView
        if (!mounted) return;
        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => _PaystackWebView(
              authUrl:   authUrl,
              reference: reference,
            ),
          ),
        );
        if (verified == true && mounted) {
          await _onPaymentSuccess();
        }
      }
    } catch (e) {
      setState(() { _paying = false; _error = 'Payment could not start. Please try again.'; });
    }
  }

  Future<void> _verifyPayment(String reference) async {
    setState(() { _paying = true; });
    try {
      final data   = await ApiClient.verifyPayment(reference);
      final status = data['status'] as String?;
      if (status == 'success' && mounted) {
        await _onPaymentSuccess();
      } else {
        setState(() {
          _paying = false;
          _error  = data['message'] as String? ?? 'Payment could not be verified.';
        });
      }
    } catch (e) {
      setState(() { _paying = false; _error = 'Verification failed. Please try again.'; });
    }
  }

  Future<void> _onPaymentSuccess() async {
    // Reload plan entitlements so gates unlock immediately
    await context.read<AiProvider>().loadPlan();
    if (!mounted) return;
    setState(() => _paying = false);
    _showSuccessSheet();
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context:      context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(onDone: () {
        Navigator.pop(context);  // close sheet
        Navigator.pop(context);  // close upgrade screen
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final scheme  = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _kAccent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A45C8), _kAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⭐', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        const Text('Upgrade to Pro',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text(
                          'Unlock AI Lecturer, unlimited AI Tutor,\n'
                          'and all Exam Prep AI tools.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── What you get ────────────────────────────────────────
                  _SectionTitle('What you get with Pro'),
                  const SizedBox(height: 12),
                  ..._proFeatures.map((f) => _FeatureRow(
                      emoji: f.$1, title: f.$2, subtitle: f.$3)),

                  const SizedBox(height: 28),
                  _SectionTitle('Choose your plan'),
                  const SizedBox(height: 12),

                  // ── Plan cards ──────────────────────────────────────────
                  if (_loadingConfig)
                    const Center(child: CircularProgressIndicator())
                  else if (_config == null)
                    _ErrorBox(_error ?? 'Could not load plans.')
                  else
                    _buildPlanCards(isDark),

                  // ── Error ────────────────────────────────────────────────
                  if (_error != null && !_loadingConfig) ...[
                    const SizedBox(height: 12),
                    _ErrorBox(_error!),
                  ],

                  const SizedBox(height: 16),

                  // ── Test mode notice ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Text('🧪', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Test mode active. Use card 4084 0840 8408 4081, '
                            'CVV 408, Expiry 01/99, OTP 123456.',
                            style: TextStyle(fontSize: 11, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Security note ────────────────────────────────────────
                  Center(
                    child: Text(
                      '🔒 Secure payment via Paystack · Cancel anytime',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCards(bool isDark) {
    final plans = (_config!['plans'] as Map?)?.cast<String, dynamic>() ?? {};

    return Column(
      children: [
        // Semester pass — featured / recommended
        if (plans.containsKey('pro_semester'))
          _PlanCard(
            planId:      'pro_semester',
            title:       'Semester Pass',
            subtitle:    plans['pro_semester']['description'] as String,
            price:       'NGN ${(plans['pro_semester']['amount_ngn'] as num).toStringAsFixed(0)}',
            duration:    '5 months',
            badge:       '🔥 Best Value',
            featured:    true,
            loading:     _paying,
            onTap:       () => _startPayment('pro_semester'),
          ),
        const SizedBox(height: 10),
        // Monthly
        if (plans.containsKey('pro_monthly'))
          _PlanCard(
            planId:      'pro_monthly',
            title:       'Monthly',
            subtitle:    plans['pro_monthly']['description'] as String,
            price:       'NGN ${(plans['pro_monthly']['amount_ngn'] as num).toStringAsFixed(0)}',
            duration:    '1 month',
            featured:    false,
            loading:     _paying,
            onTap:       () => _startPayment('pro_monthly'),
          ),
      ],
    );
  }
}

// ── Pro features list ─────────────────────────────────────────────────────────

const _proFeatures = [
  ('🎓', 'Full AI Lecturer Courses',    'All chapters + final exam for any course'),
  ('🤖', 'Unlimited AI Tutor',          'No daily question limits, ever'),
  ('📝', 'AI Exam Practice Questions',  'Generate unlimited practice sets'),
  ('⏱',  'AI Quiz Me',                 'Timed quizzes with instant scoring'),
  ('📖', 'AI Revision Notes',          'Night-before exam cheat sheets'),
  ('🎯', 'Exam Focus Areas',           'Know exactly what to study'),
  ('📷', 'Image Question Solver',      'Snap a photo of any question'),
  ('📥', 'Unlimited Offline Access',   'Download everything, study anywhere'),
];

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
}

class _FeatureRow extends StatelessWidget {
  final String emoji, title, subtitle;
  const _FeatureRow({required this.emoji, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(subtitle, style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45)),
          ],
        )),
        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String     planId, title, subtitle, price, duration;
  final String?    badge;
  final bool       featured, loading;
  final VoidCallback onTap;

  const _PlanCard({
    required this.planId, required this.title, required this.subtitle,
    required this.price, required this.duration, required this.featured,
    required this.loading, required this.onTap, this.badge,
  });

  static const _kAccent = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: featured
            ? _kAccent.withOpacity(0.08)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: featured ? _kAccent : (isDark ? Colors.white12 : Colors.black12),
          width: featured ? 2 : 1,
        ),
      ),
      child: Column(children: [
        if (badge != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Text(badge!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: featured ? _kAccent
                            : Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(duration, style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(price,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: featured ? _kAccent
                          : Theme.of(context).colorScheme.onSurface)),
              SizedBox(
                width: 120,
                height: 42,
                child: ElevatedButton(
                  onPressed: loading ? null : onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: featured ? _kAccent : Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: loading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Choose',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: const TextStyle(color: Colors.red, fontSize: 12))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Paystack WebView (mobile only)
// ══════════════════════════════════════════════════════════════════════════════

class _PaystackWebView extends StatefulWidget {
  final String authUrl;
  final String reference;
  const _PaystackWebView({required this.authUrl, required this.reference});

  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  late final WebViewController _ctrl;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          // Intercept our callback URL
          if (req.url.startsWith(_kCallbackUrl)) {
            _handleCallback(req.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  Future<void> _handleCallback(String url) async {
    if (_verifying) return;
    setState(() => _verifying = true);

    // Extract reference from URL params if Paystack includes it
    String reference = widget.reference;
    try {
      final uri    = Uri.parse(url);
      final refParam = uri.queryParameters['reference'] ??
                       uri.queryParameters['trxref'];
      if (refParam != null) reference = refParam;
    } catch (_) {}

    try {
      final data   = await ApiClient.verifyPayment(reference);
      final status = data['status'] as String?;
      if (mounted) {
        Navigator.pop(context, status == 'success');
      }
    } catch (_) {
      if (mounted) Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Secure Payment'),
      backgroundColor: const Color(0xFF6C63FF),
      foregroundColor: Colors.white,
      actions: [
        if (_verifying)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ),
          ),
      ],
    ),
    body: WebViewWidget(controller: _ctrl),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Success bottom sheet
// ══════════════════════════════════════════════════════════════════════════════

class _SuccessSheet extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessSheet({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated checkmark
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('You\'re now Pro!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Your Pro access is now active. Enjoy unlimited AI Tutor, '
            'full AI Lecturer courses, and all Exam Prep tools.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Start Exploring Pro Features',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
