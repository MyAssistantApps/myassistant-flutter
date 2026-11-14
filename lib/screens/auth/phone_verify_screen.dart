import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../widgets/glow_cta.dart';
import '../../services/auth_service.dart';
import '../../services/phone_verify_service.dart';

/// Mandatory step between signing in and reaching the assistant.
///
/// It is blocking on purpose. The whole point of a verified number is that
/// other people's agents can deliver to it; an account without one is
/// unreachable, so letting it through would create users who silently never
/// receive anything.
///
/// No SMS code (owner, 2026-09-29): Google confirms the number of the SIM
/// in this phone with its carrier (PhoneVerifyService). Where the carrier
/// does not take part (India), our caller rings the number and reads a
/// 6-digit code to type back (2026-11-14). The server's testing switch (a
/// typed number) shows only while the server still offers it.
///
/// Styled as part of ONE onboarding flow with the auth and naming screens:
/// plain ground, left-aligned headline, theme fields, ink primary button.
class PhoneVerifyScreen extends StatefulWidget {
  const PhoneVerifyScreen({super.key, this.service});

  /// Tests pass their own; the app uses [PhoneVerifyService.instance].
  final PhoneVerifyService? service;

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  late final PhoneVerifyService _svc =
      widget.service ?? PhoneVerifyService.instance;
  final _phone = TextEditingController();
  final _code = TextEditingController();

  /// The number a code was called to; non-null = waiting for the code.
  String? _calledTo;

  /// Seconds before "Call me again" is offered.
  int _cooldown = 0;
  Timer? _tick;

  /// Default matches the backend's DEFAULT_PHONE_REGION.
  final _dial = TextEditingController(text: '+91');

  /// Null while the phone and the server are asked what they allow.
  PhoneVerifyMethods? _methods;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (_methods != null || _error != null) {
      setState(() {
        _methods = null;
        _error = null;
      });
    }
    final m = await _svc.methods();
    if (mounted) setState(() => _methods = m);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _code.dispose();
    _phone.dispose();
    _dial.dispose();
    super.dispose();
  }

  String get _dialCode {
    final t = _dial.text.trim();
    return t.startsWith('+') ? t : '+$t';
  }

  String get _e164 => '$_dialCode${_phone.text.replaceAll(RegExp(r'\D'), '')}';

  Future<void> _viaSim() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await _svc.verifyWithSim();
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  Future<void> _typed() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) {
      setState(() => _error = 'Enter your phone number first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await _svc.devVerify(_e164);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  Future<void> _callMe() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (_calledTo == null && digits.length < 10) {
      setState(() => _error = 'Enter your 10-digit mobile number.');
      return;
    }
    final to = _calledTo ?? _e164;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await _svc.requestCall(to);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) {
        _calledTo = to;
        _code.clear();
        _startCooldown();
      }
    });
  }

  void _startCooldown() {
    _tick?.cancel();
    _cooldown = 45;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _submitCode() async {
    final to = _calledTo;
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    if (to == null) return;
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the call.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await _svc.verifyCallCode(to, code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) HapticFeedback.mediumImpact();
  }

  String get _lead {
    final m = _methods;
    if (m == null) return 'Checking your SIM…';
    if (m.sim) {
      return 'This is how friends and family reach you through their '
          'assistant. Google confirms the number of the SIM in this phone '
          'with your network — there is no code to type.';
    }
    if (!m.reached) return 'Could not reach the server. Check your connection.';
    if (m.call) {
      final to = _calledTo;
      return to == null
          ? 'This is how friends and family reach you through their assistant. '
              "We'll call your number and read out a 6-digit code."
          : "We're calling $to now. Answer, listen for the 6-digit code and "
              'type it below.';
    }
    if (m.typed) {
      return "Your network can't confirm numbers automatically yet. For "
          'testing, enter your number instead.';
    }
    return "Your network can't confirm numbers automatically yet, so this "
        'step is not available on this phone for now.';
  }

  @override
  Widget build(BuildContext context) {
    // Under Home's sky, the lit mark and one lit action (2026-09-30).
    return NeonScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BrandMark(icon: Icons.verified_user_rounded),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Verify your number',
                    style: GoogleFonts.interTight(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Neon.textHi,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _lead,
                    style: TextStyle(
                        color: Neon.textLo, fontSize: 15, height: 1.45),
                  ),
                  const SizedBox(height: 26),
                  if (_methods?.sim == false &&
                      ((_methods?.call == true && _calledTo == null) ||
                          (_methods?.call != true && _methods?.typed == true)))
                    Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: _dial,
                            keyboardType: TextInputType.phone,
                            decoration:
                                const InputDecoration(labelText: 'Code'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_methods?.sim == false && _calledTo != null)
                    TextField(
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        if (v.length == 6 && !_busy) _submitCode();
                      },
                      style: GoogleFonts.interTight(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 10,
                          color: Neon.textHi),
                      decoration: const InputDecoration(
                        labelText: '6-digit code',
                        counterText: '',
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Neon.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Neon.error, size: 19),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(
                                    color: Neon.errorInk,
                                    fontSize: 14,
                                    height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_busy || _methods == null)
                    const GlowCta(
                      label: '',
                      busy: true,
                      busyLabel: 'Checking your number',
                      onPressed: null,
                    )
                  else if (_methods!.sim)
                    GlowCta(
                      label: 'Confirm with my SIM',
                      onPressed: _viaSim,
                    )
                  else if (_methods!.call && _calledTo != null)
                    GlowCta(label: 'Verify', onPressed: _submitCode)
                  else if (_methods!.call)
                    GlowCta(label: 'Call me with a code', onPressed: _callMe)
                  else if (_methods!.typed)
                    GlowCta(
                      label: 'Use this number (testing)',
                      onPressed: _typed,
                    )
                  else
                    // The only way forward from here, so it is the primary
                    // button, not a link: offline it retries the server;
                    // on a network that cannot confirm it checks again (a
                    // new SIM, or the testing switch turned on).
                    GlowCta(
                      label: _methods!.reached ? 'Check again' : 'Try again',
                      onPressed: _check,
                    ),
                  if (_methods?.call == true &&
                      _methods?.sim == false &&
                      _calledTo != null)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _calledTo = null;
                                    _error = null;
                                  }),
                          child: const Text('Change number'),
                        ),
                        TextButton(
                          onPressed: _busy || _cooldown > 0 ? null : _callMe,
                          child: Text(_cooldown > 0
                              ? 'Call again in ${_cooldown}s'
                              : 'Call me again'),
                        ),
                      ],
                    ),
                  // While the server still has its testing switch on, a
                  // typed number stays possible — as the quiet option.
                  if (_methods?.call == true &&
                      _methods?.sim == false &&
                      _methods?.typed == true &&
                      _calledTo == null)
                    TextButton(
                      onPressed: _busy ? null : _typed,
                      child: Text('Testing: use this number without a call',
                          style: TextStyle(
                              color: Neon.textLo, fontSize: NeonType.footnote)),
                    ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed:
                        _busy ? null : () => AuthService.instance.signOut(),
                    child: Text('Sign out',
                        style: TextStyle(
                            color: Neon.textLo, fontSize: NeonType.footnote)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
