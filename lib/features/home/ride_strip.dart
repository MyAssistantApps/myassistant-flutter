import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_tokens.dart';
import '../../services/api_service.dart';
import '../../services/app_feedback.dart';
import '../../widgets/neon_cards.dart';

/// A cab booked by voice, as the server reports it (GET /rides/active).
class ActiveRide {
  ActiveRide.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num?)?.toInt() ?? 0,
        provider = '${j['providerLabel'] ?? j['provider'] ?? 'Cab'}',
        test = j['test'] == true,
        pickup = '${j['pickup'] ?? ''}',
        drop = '${j['drop'] ?? ''}',
        fare = (j['fare'] as num?)?.toDouble(),
        status = '${j['status'] ?? 'searching'}',
        driverName = '${(j['driver'] as Map?)?['name'] ?? ''}',
        driverPhone = '${(j['driver'] as Map?)?['phone'] ?? ''}',
        vehicle = [
          (j['vehicle'] as Map?)?['colour'],
          (j['vehicle'] as Map?)?['model'],
        ].whereType<String>().where((s) => s.isNotEmpty).join(' '),
        plate = '${(j['vehicle'] as Map?)?['plate'] ?? ''}',
        otp = '${j['otp'] ?? ''}',
        etaMin = (j['etaMin'] as num?)?.toInt();

  final int id;
  final String provider, pickup, drop, status, driverName, driverPhone, vehicle, plate, otp;
  final bool test;
  final double? fare;
  final int? etaMin;

  String get statusLine => switch (status) {
        'searching' => 'Finding a driver',
        'accepted' => etaMin != null ? 'Driver on the way · $etaMin min' : 'Driver on the way',
        'arriving' => 'Your cab is arriving',
        'in_progress' => 'On the way to $drop',
        _ => status,
      };
}

/// Keeps the booked ride fresh while one is active; quiet otherwise.
class RideService {
  RideService._();
  static final RideService instance = RideService._();

  final ValueNotifier<ActiveRide?> ride = ValueNotifier(null);
  Timer? _poll;

  Future<void> refresh() async {
    final j = await ApiService.getJson('/rides/active');
    final r = j?['ride'];
    ride.value = r is Map ? ActiveRide.fromJson(r.cast<String, dynamic>()) : null;
    _poll?.cancel();
    if (ride.value != null) {
      _poll = Timer(const Duration(seconds: 15), refresh);
    }
  }

  Future<bool> cancel() async {
    final r = ride.value;
    if (r == null) return false;
    final ok = await ApiService.postJson('/rides/${r.id}/cancel', const {}) != null;
    await refresh();
    return ok;
  }
}

/// YOUR RIDE at the top of Home (owner, 2026-11-21): who is coming, in
/// which car, the OTP to give the driver, and a Cancel.
class RideStrip extends StatefulWidget {
  const RideStrip({super.key});

  @override
  State<RideStrip> createState() => _RideStripState();
}

class _RideStripState extends State<RideStrip> {
  @override
  void initState() {
    super.initState();
    RideService.instance.refresh();
  }

  Future<void> _cancel(ActiveRide r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel This Ride?'),
        content: Text('${r.provider} to ${r.drop}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel Ride')),
        ],
      ),
    );
    if (yes != true) return;
    HapticFeedback.mediumImpact();
    final ok = await RideService.instance.cancel();
    AppFeedback.show(ok ? 'Your ride has been cancelled.' : 'Unable to cancel the ride. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveRide?>(
      valueListenable: RideService.instance.ride,
      builder: (context, r, _) {
        if (r == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            glow: Neon.violet,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [Neon.violet, Neon.accentC]),
                  ),
                  child: const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r.test ? 'Test Ride · ' : ''}${r.provider} to ${r.drop}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(14.5, FontWeight.w800).copyWith(color: Neon.textHi)),
                    Text(r.statusLine,
                        style: NeonType.manrope(12.5, FontWeight.w600).copyWith(color: Neon.violet)),
                  ]),
                ),
                if (r.otp.isNotEmpty)
                  Semantics(
                    label: 'OTP ${r.otp.split('').join(' ')}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Neon.violet.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Text('OTP',
                            style: NeonType.manrope(10, FontWeight.w700).copyWith(color: Neon.textLo)),
                        Text(r.otp,
                            style: NeonType.manrope(20, FontWeight.w900)
                                .copyWith(color: Neon.textHi, letterSpacing: 2)),
                      ]),
                    ),
                  ),
              ]),
              if (r.driverName.isNotEmpty || r.plate.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  [
                    if (r.driverName.isNotEmpty) r.driverName,
                    if (r.vehicle.isNotEmpty) r.vehicle,
                    if (r.plate.isNotEmpty) r.plate,
                  ].join(' · '),
                  style: NeonType.manrope(13, FontWeight.w600).copyWith(color: Neon.textHi),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _cancel(r),
                  child: Text('Cancel Ride', style: TextStyle(color: Neon.error, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
