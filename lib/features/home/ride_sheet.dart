import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/neon_tokens.dart';
import '../../services/api_service.dart';
import '../../services/app_feedback.dart';
import '../../widgets/glow_cta.dart';

/// WHERE TO? (owner, 2026-11-21). Tapping Uber or Ola on Home no longer
/// opens a blank app: the user says where they are going, the server
/// resolves it (POST /go/ride), and the provider opens on its confirm
/// screen with pickup (here) and drop-off already set. Uber and Ola keep
/// the payment and the final confirm, as their terms require.
class RideSheet extends StatefulWidget {
  const RideSheet({super.key, required this.provider, required this.label, required this.openApp});
  final String provider; // uber | ola
  final String label;
  /// Opens the provider's app as it was (no destination).
  final Future<void> Function() openApp;

  static Future<void> show(BuildContext context,
          {required String provider, required String label, required Future<void> Function() openApp}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Neon.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => RideSheet(provider: provider, label: label, openApp: openApp),
      );

  @override
  State<RideSheet> createState() => _RideSheetState();
}

class _RideSheetState extends State<RideSheet> {
  final _to = TextEditingController();
  bool _busy = false;

  static const _quick = ['Airport', 'Railway Station', 'Bus Stand', 'Nearest Hospital'];

  @override
  void dispose() {
    _to.dispose();
    super.dispose();
  }

  Future<void> _go([String? where]) async {
    final dest = (where ?? _to.text).trim();
    if (dest.isEmpty) {
      AppFeedback.show('Please enter where you want to go.', context: context);
      return;
    }
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final r = await ApiService.postJson('/go/ride', {'provider': widget.provider, 'destination': dest});
    if (!mounted) return;
    setState(() => _busy = false);
    // An older server (or none): the documented link built here, with the
    // address for the provider to search.
    final url = r?['url'] as String? ?? rideLink(widget.provider, dest);
    Navigator.of(context).pop();
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) AppFeedback.show('Unable to open ${widget.label}. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Neon.textLo.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: [Neon.violet, Neon.accentC]),
                    boxShadow: [BoxShadow(color: Neon.violet.withValues(alpha: 0.35), blurRadius: 16)],
                  ),
                  child: const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Where To?',
                        style: NeonType.manrope(19, FontWeight.w800).copyWith(color: Neon.textHi)),
                    Text('${widget.label} opens with your trip ready to confirm.',
                        style: NeonType.manrope(13, FontWeight.w500).copyWith(color: Neon.textLo)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _to,
                autofocus: true,
                textInputAction: TextInputAction.go,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _go(),
                decoration: InputDecoration(
                  hintText: 'A place, an address or a landmark',
                  prefixIcon: const Icon(Icons.place_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final q in _quick)
                  ActionChip(label: Text(q), onPressed: _busy ? null : () => _go(q)),
              ]),
              const SizedBox(height: 14),
              GlowCta(
                label: 'Book with ${widget.label}',
                icon: Icons.arrow_forward_rounded,
                busy: _busy,
                busyLabel: 'Preparing Your Ride',
                onPressed: _busy ? null : () => _go(),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await widget.openApp();
                      },
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                child: Text('Just Open ${widget.label}', style: TextStyle(color: Neon.textLo)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The provider's documented link from a typed destination alone: pickup is
/// "my location", drop-off an address the provider searches.
String rideLink(String provider, String destination) {
  final d = Uri.encodeComponent(destination);
  if (provider == 'ola') {
    return 'https://book.olacabs.com/?utm_source=myassistant&drop_name=$d';
  }
  return 'https://m.uber.com/ul/?action=setPickup&pickup=my_location'
      '&dropoff[formatted_address]=$d&dropoff[nickname]=$d';
}
