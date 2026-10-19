import 'development_balance.dart';

/// Selects from owned recipes only. Mastery is deliberately not a prerequisite
/// for an order made in the large mold. Existing authored preferences remain
/// the fallback; Taeo can actually encounter an untried newly unlocked flavor.
String preferredCustomerFlavor(String npc, DevelopmentBalance config,
    {required Set<String> owned, Set<String> previouslyServed = const {},
    bool firstCustomer = false}) {
  if (owned.isEmpty || !owned.contains('redbean')) {
    throw const FormatException('기본 레시피 누락');
  }
  if (npc == 'npc_doyun' && firstCustomer) return 'redbean';
  final preference = config.section('customer_order_preferences')[npc];
  if (preference is! Map<String, dynamic>) {
    throw const FormatException('손님 취향 누락');
  }
  if (npc == 'npc_taeo') {
    final recipes = config.section('active_recipes');
    final untried = owned.where((flavor) =>
        recipes[flavor] is Map<String, dynamic> &&
        (recipes[flavor] as Map<String, dynamic>)['initial'] != true &&
        !previouslyServed.contains(flavor)).toList()..sort();
    if (untried.isNotEmpty) return untried.first;
  }
  final flavor = preference['flavor'] as String;
  return owned.contains(flavor) ? flavor : 'redbean';
}
