import 'development_balance.dart';

/// The per-NPC event evaluator consumes persisted observations, never wall-clock
/// absence, stars, real photos, health data or a caller's current wallet.
class CustomerEventFacts {
  final String npcId;
  final int affinity, visits, distinctVisitDays, daysSinceLastVisit;
  final int redbeanTwoSuccessDays, largeOrderSuccessDays, otherMetCount;
  final int recipeCount, receivedFlavorCount, sketchVisitCount;
  final int workVisits, workSuccessDays, runningVisits, custardSuccesses;
  final bool mapStoryKnown, newFlavorFirstServed, forgotPhotoShown;
  final bool workingVisit, runningTurnedBack, morning, timeFeatureEnabled;
  final bool firstVisit;
  final Set<String> completedStories;
  const CustomerEventFacts({required this.npcId, required this.affinity,
    required this.visits, this.distinctVisitDays = 0, this.daysSinceLastVisit = 0,
    this.redbeanTwoSuccessDays = 0, this.largeOrderSuccessDays = 0,
    this.otherMetCount = 0, this.recipeCount = 0, this.receivedFlavorCount = 0,
    this.sketchVisitCount = 0, this.workVisits = 0, this.workSuccessDays = 0,
    this.runningVisits = 0, this.custardSuccesses = 0, this.mapStoryKnown = false,
    this.newFlavorFirstServed = false, this.forgotPhotoShown = false,
    this.workingVisit = false, this.runningTurnedBack = false,
    this.morning = false, this.timeFeatureEnabled = false,
    this.firstVisit = false, this.completedStories = const {}});
}

/// All numeric prerequisites are supplied by the common provisional config.
/// Yunha/Minjae candidate order variants must be reserved when generating the
/// visit. This function cannot convert a random normal order after the sale.
bool eligibleCustomerChoice(CustomerEventFacts f, DevelopmentBalance config,
    {required bool candidateOrderMatches}) {
  if (f.firstVisit || !candidateOrderMatches) return false;
  final rows = config.section('customer_choice_conditions');
  final raw = rows[f.npcId];
  if (raw is! Map<String, dynamic>) return false;
  int n(String key) => DevelopmentBalance.integer(raw, key);
  if (f.affinity < n('min_affinity') || f.visits < n('min_visits')) return false;
  if (raw['forbidden_story'] is String && f.completedStories.contains(raw['forbidden_story'])) return false;
  switch (f.npcId) {
    case 'npc_yunha': return f.redbeanTwoSuccessDays >= n('redbean_two_success_days');
    case 'npc_doyun': return f.recipeCount >= n('recipes') && f.receivedFlavorCount >= n('received_flavors') && f.mapStoryKnown;
    case 'npc_makrye': return f.largeOrderSuccessDays >= n('large_order_success_days') && f.otherMetCount >= n('other_met');
    case 'npc_seojin': return f.sketchVisitCount >= n('sketch_visits');
    case 'npc_taeo': return f.newFlavorFirstServed && f.forgotPhotoShown;
    case 'npc_eunchae': return f.workingVisit && f.workVisits >= n('work_visits') && f.workSuccessDays >= n('work_success_days') && (!f.timeFeatureEnabled || f.morning);
    case 'npc_minjae': return f.runningVisits >= n('running_visits') && f.runningTurnedBack;
    case 'npc_sua': return f.distinctVisitDays >= n('distinct_visit_days') && f.custardSuccesses >= n('custard_successes') && f.daysSinceLastVisit >= n('return_gap_days');
  }
  return false;
}

/// Story completion does not depend on a particular choice answer or on seeing
/// the optional choice at all. Scene completion, not eligibility, changes names.
bool eligibleCustomerStory(String npcId, WorkshopStoryFacts f, DevelopmentBalance config) {
  final raw = config.section('customer_story_conditions')[npcId];
  if (raw is! Map<String,dynamic> || !f.met.contains(npcId)) return false;
  int stageOf(String id) => config.integers('customer_relationships','stage_thresholds')
      .where((v) => (f.affinity[id] ?? 0) >= v).length - 1;
  if (stageOf(npcId) < DevelopmentBalance.integer(raw,'stage')) return false;
  if (raw.containsKey('successful_visits') && (f.successfulVisits[npcId] ?? 0) < DevelopmentBalance.integer(raw,'successful_visits')) return false;
  if (raw['requires_drawing_conversation'] == true && !f.drawingConversationSeen) return false;
  final other = raw['other_npc'];
  return other == null || other is String && f.met.contains(other) && stageOf(other) >= DevelopmentBalance.integer(raw,'other_stage');
}
class WorkshopStoryFacts {
  final Set<String> met;
  final Map<String,int> affinity, successfulVisits;
  final bool drawingConversationSeen;
  const WorkshopStoryFacts({required this.met, required this.affinity,
    this.successfulVisits = const {}, this.drawingConversationSeen = false});
}
