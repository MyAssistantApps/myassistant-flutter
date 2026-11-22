/// PREMIUM PLANS (2026-11-12) — the three paid tiers, the free trial and the
/// credit packs shown on the Premium screen.
///
/// Prices are in rupees and include GST. This is display data only: no
/// billing is wired yet, and when it is, the server's plan list (via
/// /ai/config) should replace these constants so prices can change
/// without a release.
library;

enum BillingPeriod { monthly, yearly }

class PremiumPlan {
  const PremiumPlan({
    required this.id,
    required this.name,
    required this.tagline,
    required this.monthly,
    required this.yearly,
    required this.credits,
    required this.highlights,
    required this.includes,
    this.badge,
  });

  final String id;
  final String name;
  final String tagline;

  /// Rupees per month, and per year.
  final int monthly;
  final int yearly;

  /// Credits added every month.
  final int credits;

  /// Three short lines for the plan card.
  final List<String> highlights;

  /// The full list shown under the cards for the selected plan.
  final List<String> includes;

  /// "Most popular" and the like.
  final String? badge;

  int priceFor(BillingPeriod p) => p == BillingPeriod.monthly ? monthly : yearly;

  /// What a year costs when paid monthly.
  int get yearOfMonthly => monthly * 12;

  /// Percent saved by paying yearly, rounded down.
  int get yearlySavingPercent =>
      ((yearOfMonthly - yearly) * 100 / yearOfMonthly).floor();
}

const freeTrialDays = 14;
const freeTrialCredits = 500;

const premiumPlans = <PremiumPlan>[
  PremiumPlan(
    id: 'plus',
    name: 'Plus',
    tagline: 'For everyday use',
    monthly: 199,
    yearly: 1999,
    credits: 1500,
    highlights: ['Unlimited chat', '60 min voice per day', '1,500 credits'],
    includes: [
      'Unlimited typed chat and photo questions',
      'Live voice conversation, 60 minutes per day',
      'Reminders, alarms, calendar and daily brief',
      'Play my morning, read aloud',
      'Messages, email read and reply, missed calls',
      'Shopping list, kitchen, news, stocks and weather',
      'Images, cards and posters (with credits)',
      '3 generated files per month: PPT, PDF, Word, Excel',
      '5 shortcuts and standing rules',
      '1,500 credits every month',
    ],
  ),
  PremiumPlan(
    id: 'pro',
    name: 'Pro',
    tagline: 'For advanced users',
    monthly: 499,
    yearly: 4999,
    credits: 5000,
    badge: 'Most Popular',
    highlights: ['Everything in Plus', 'Meetings and research', '5,000 credits'],
    includes: [
      'Everything in Plus',
      'Live voice conversation, 180 minutes per day',
      'AI calls on your behalf in six languages, with recordings',
      'Meeting recording: minutes, decisions, action items',
      'Deep research and arranging meetings',
      'Photo editing by voice, Style Studio, and short videos',
      'Video notes in your voice',
      'Live interpreter',
      'Record books and flight fare watch',
      'Hands-free wake word (coming soon)',
      'Unlimited shortcuts, 2 devices',
      '5,000 credits every month; unused credits carry over for one month',
    ],
  ),
  PremiumPlan(
    id: 'business',
    name: 'Business',
    tagline: 'For doctors, lawyers and consultants',
    monthly: 1499,
    yearly: 14999,
    credits: 15000,
    highlights: ['Everything in Pro', 'Clients and payments', '15,000 credits'],
    includes: [
      'Everything in Pro',
      'Live voice conversation, 300 minutes per day',
      'Clients and patients: pending dues, recalls, and records',
      'Collect payments with links: "collect ₹15,000 from Ravi"',
      'Indian law: statutes and case law, quoted',
      'Your own tool servers',
      'Posters with your brand colours and logo',
      'Unlimited documents, 3 devices',
      'Priority support',
      '15,000 credits every month; unused credits carry over for two months',
    ],
  ),
];

class CreditPack {
  const CreditPack(this.credits, this.price, {this.bonus});
  final int credits;
  final int price;
  final String? bonus;
}

const creditPacks = <CreditPack>[
  CreditPack(1000, 99),
  CreditPack(5000, 449, bonus: '+11%'),
  CreditPack(10000, 799, bonus: '+25%'),
];

/// ₹1,999 style: Indian grouping is the same as Western up to 99,999.
String rupees(int n) {
  final s = n.toString();
  if (s.length <= 3) return '₹$s';
  final head = s.substring(0, s.length - 3);
  final tail = s.substring(s.length - 3);
  final groups = <String>[];
  var h = head;
  while (h.length > 2) {
    groups.insert(0, h.substring(h.length - 2));
    h = h.substring(0, h.length - 2);
  }
  if (h.isNotEmpty) groups.insert(0, h);
  return '₹${groups.join(',')},$tail';
}

String grouped(int n) => rupees(n).substring(1);

/// Play Billing is not wired yet: plan buttons join the early-access list
/// instead of charging (premium_screen.dart `_joinEarlyAccess`). Flip when
/// purchases go live.
const bool kBillingLive = false;
