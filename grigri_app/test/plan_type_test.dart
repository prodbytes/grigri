import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/model/plan.dart';

Map<String, Object?> _json([Map<String, Object?> extra = const {}]) => {
  'id': 'p1',
  'organizerId': 'ada',
  'discipline': 'sport',
  'place': 'Somewhere',
  'grades': {'scale': 'routes', 'min': 6, 'max': 10},
  'memberIds': ['ada', 'ben'],
  ...extra,
};

void main() {
  test('a plan without a type (or an unknown one) is private', () {
    expect(Plan.fromJson(_json()).type, PlanType.private);
    expect(Plan.fromJson(_json({'type': 'secret'})).type, PlanType.private);
  });

  test('deciders: every member, nobody, or the guide', () {
    expect(Plan.fromJson(_json()).deciders, ['ada', 'ben']);
    expect(Plan.fromJson(_json({'type': 'open'})).deciders, isEmpty);
    expect(Plan.fromJson(_json({'type': 'guided'})).deciders, ['ada']);
  });

  test(
    'a guided plan carries its price both ways; the others never send one',
    () {
      final guided = Plan.fromJson(
        _json({
          'type': 'guided',
          'price': {'amount': 49.5, 'currency': 'CHF'},
        }),
      );
      expect(guided.price, const Price(amount: 49.5, currency: 'CHF'));
      expect(guided.toJson()['type'], 'guided');
      expect(guided.toJson()['price'], {'amount': 49.5, 'currency': 'CHF'});
      final open = guided.copyWith(type: PlanType.open);
      expect(open.toJson()['type'], 'open');
      expect(open.toJson().containsKey('price'), isFalse);
    },
  );
}
