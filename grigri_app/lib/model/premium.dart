/// Premium (specs/premium.md): a subscription that lets me advertise on
/// Grigri and use the route finder. Everything else is the same for
/// everyone. Paid through Stripe on Android and the web, through the App
/// Store's in-app purchase on iOS.
enum PremiumPlan {
  monthly,
  yearly;

  static PremiumPlan? fromName(Object? name) => switch (name) {
    'monthly' => monthly,
    'yearly' => yearly,
    _ => null,
  };
}

/// Who sells a subscription, so the app knows where it's managed.
enum PremiumSource {
  stripe,
  apple;

  static PremiumSource? fromName(Object? name) => switch (name) {
    'stripe' => stripe,
    'apple' => apple,
    _ => null,
  };
}

/// My Premium, as the API keeps it from Stripe or the App Store.
class Premium {
  const Premium({
    this.active = false,
    this.plan,
    this.until,
    this.ending = false,
    this.source,
  });

  const Premium.none() : this();

  final bool active;
  final PremiumPlan? plan;

  /// Paid until.
  final DateTime? until;

  /// Cancelled: it ends at [until] and won't renew.
  final bool ending;

  /// Who sells it; null when it isn't a paid subscription (an admin, or
  /// granted by hand).
  final PremiumSource? source;

  static Premium fromJson(Object? json) {
    if (json is! Map) return const Premium.none();
    return Premium(
      active: json['active'] == true,
      plan: PremiumPlan.fromName(json['plan']),
      until: DateTime.tryParse('${json['until']}')?.toLocal(),
      ending: json['ending'] == true,
      source: PremiumSource.fromName(json['source']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Premium &&
      other.active == active &&
      other.plan == plan &&
      other.until == until &&
      other.ending == ending &&
      other.source == source;

  @override
  int get hashCode => Object.hash(active, plan, until, ending, source);
}

/// What a plan costs through Stripe.
class PremiumPrice {
  const PremiumPrice({required this.amount, required this.currency});

  /// In the currency's smallest unit (cents).
  final int amount;

  /// ISO 4217, lowercase: "usd".
  final String currency;

  /// "$20" (whole amounts) or "$20.50", for US dollars; "20 EUR" otherwise.
  String get label {
    final whole = amount % 100 == 0;
    final value = whole
        ? '${amount ~/ 100}'
        : (amount / 100).toStringAsFixed(2);
    return currency == 'usd' ? '\$$value' : '$value ${currency.toUpperCase()}';
  }

  static PremiumPrice? fromJson(Object? json) {
    if (json is! Map || json['amount'] is! num) return null;
    return PremiumPrice(
      amount: (json['amount'] as num).toInt(),
      currency: '${json['currency'] ?? 'usd'}',
    );
  }
}

/// `GET /api/premium`: mine, Stripe's prices (empty when Premium can't be
/// bought through Stripe: the stage has no Stripe keys), and the
/// appAccountToken the iOS app buys with (null without App Store
/// purchases).
class PremiumOffer {
  const PremiumOffer(this.premium, this.prices, {this.appleAccountToken});

  final Premium premium;
  final Map<PremiumPlan, PremiumPrice> prices;

  /// A UUID the API derives from my account: an App Store purchase made
  /// with it is mine.
  final String? appleAccountToken;

  bool get available => prices.isNotEmpty;
}
