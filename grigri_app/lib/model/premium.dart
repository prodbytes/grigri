/// Premium (specs/premium.md): a subscription, paid through Stripe, that
/// lets me advertise on Grigri. Everything else is the same for everyone.
enum PremiumPlan {
  monthly,
  yearly;

  static PremiumPlan? fromName(Object? name) => switch (name) {
    'monthly' => monthly,
    'yearly' => yearly,
    _ => null,
  };
}

/// My Premium, as the API reads it from Stripe.
class Premium {
  const Premium({
    this.active = false,
    this.plan,
    this.until,
    this.ending = false,
  });

  const Premium.none() : this();

  final bool active;
  final PremiumPlan? plan;

  /// Paid until.
  final DateTime? until;

  /// Cancelled: it ends at [until] and won't renew.
  final bool ending;

  static Premium fromJson(Object? json) {
    if (json is! Map) return const Premium.none();
    return Premium(
      active: json['active'] == true,
      plan: PremiumPlan.fromName(json['plan']),
      until: DateTime.tryParse('${json['until']}')?.toLocal(),
      ending: json['ending'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Premium &&
      other.active == active &&
      other.plan == plan &&
      other.until == until &&
      other.ending == ending;

  @override
  int get hashCode => Object.hash(active, plan, until, ending);
}

/// What a plan costs.
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

/// `GET /api/premium`: mine, and the prices (empty when Premium can't be
/// bought: the stage has no Stripe keys).
class PremiumOffer {
  const PremiumOffer(this.premium, this.prices);

  final Premium premium;
  final Map<PremiumPlan, PremiumPrice> prices;

  bool get available => prices.isNotEmpty;
}
