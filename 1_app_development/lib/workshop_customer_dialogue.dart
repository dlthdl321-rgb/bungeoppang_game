import 'development_orders.dart';
import 'workshop_customers.dart';

/// Only actual order/visit/scene facts may enable a specific line. Unsupported
/// weather, time, appearance changes and simultaneous companions stay false.
class CustomerDialogueFacts {
  final CustomerOrder order;
  final int stage;
  final Set<String> met, stories;
  final bool working, running, cameraPresent, onSite, weatherRain, weatherCold;
  final bool morning, evening, timeFeature, apronChanged, companionPresent;
  final bool exactProductAppearance, swappedFlavorKnown, corrected;
  final bool openingDay;
  const CustomerDialogueFacts({required this.order,this.stage=0,this.met=const {},this.stories=const {},
    this.working=false,this.running=false,this.cameraPresent=false,this.onSite=false,
    this.weatherRain=false,this.weatherCold=false,this.morning=false,this.evening=false,
    this.timeFeature=false,this.apronChanged=false,this.companionPresent=false,
    this.exactProductAppearance=false,this.swappedFlavorKnown=false,this.corrected=false,this.openingDay=false});
  int get quantity => order.lines.fold<int>(0,(n,line)=>n+line.quantity);
  bool only(String flavor,{int? count}) => order.lines.length==1 && order.lines.single.flavor==flavor && (count==null || quantity==count);
}

/// Numeric quantities here are authored sentence literals ("두 개"/"다섯 개"),
/// not price or order-generation defaults: when tuning changes the real order,
/// a mismatched literal is automatically disabled rather than rewritten falsely.
bool qualifiesCustomerDialogue(String event,CustomerDialogueFacts f) {
  final id=f.order.customerId;
  if(event=='rain') return f.weatherRain;
  if(event=='cold') return f.weatherCold && (id!='npc_minjae' || f.running);
  if(event=='corrected') return f.corrected;
  if(event=='wrong_order') return false; // Supplied flavor/package subtype is not modeled; use the neutral mismatch line.
  if(event=='success') return f.exactProductAppearance;
  if(event=='timeout') return id!='npc_minjae' || f.running;
  if(event=='waiting' || event=='delayed') {
    if(id=='npc_minjae') return f.running;
    if(id=='npc_eunchae') return f.working;
    if(id=='npc_taeo') return f.cameraPresent;
    if(id=='npc_yunha' && event=='delayed') return f.timeFeature && f.evening;
    return true;
  }
  if(event=='first_visit' || event=='order') {
    switch(id) {
      case 'npc_yunha':return f.only('redbean',count:2) && (event!='first_visit' || f.onSite);
      case 'npc_doyun':return f.only('custard',count:1);
      case 'npc_makrye':return f.only('redbean',count:event=='first_visit' ? 4 : 5) && (event!='first_visit' || f.openingDay);
      case 'npc_seojin':return f.only('custard',count:1);
      case 'npc_taeo':return f.quantity==1 && f.cameraPresent;
      case 'npc_eunchae':return f.only('custard',count:2) && f.working && (event!='first_visit' || f.timeFeature && f.morning);
      case 'npc_minjae':return f.only('redbean',count:event=='first_visit' ? 1:2) && f.running;
      case 'npc_sua':return f.only('custard',count:1);
    }
  }
  if(event=='smalltalk') {
    switch(id) {
      case 'npc_yunha':return f.quantity==2 && f.order.lines.length==2 && f.order.lines.any((l)=>l.flavor=='redbean' && l.quantity==1) && f.order.lines.any((l)=>l.flavor=='custard' && l.quantity==1);
      case 'npc_doyun':return f.only('custard');
      case 'npc_makrye':return f.order.lines.any((l)=>l.flavor=='custard') && f.order.lines.any((l)=>l.flavor=='redbean');
      case 'npc_seojin':return f.only('redbean',count:1);
      case 'npc_taeo':return f.quantity==2 && f.cameraPresent;
      case 'npc_eunchae':return f.working;
      case 'npc_minjae':return f.only('redbean',count:2);
      case 'npc_sua':return f.order.lines.isNotEmpty;
    }
  }
  if(event=='friendly') {
    switch(id) {
      case 'npc_yunha':return f.apronChanged;
      case 'npc_doyun':return f.stories.contains('story_doyun_01');
      case 'npc_makrye':return true;
      case 'npc_seojin':return false; // No verified pencil-on-head appearance yet.
      case 'npc_taeo':return !f.cameraPresent && f.stories.contains('story_taeo_01');
      case 'npc_eunchae':return f.working && f.timeFeature && f.morning;
      case 'npc_minjae':return false; // Watch location story is not implemented.
      case 'npc_sua':return f.order.lines.length>1 && f.order.lines.any((l)=>l.flavor=='redbean');
    }
  }
  if(event=='regular') {
    switch(id) {
      case 'npc_yunha':return true;
      case 'npc_doyun':return f.companionPresent; // Otherwise use the authored map alternate later.
      case 'npc_makrye':return f.onSite;
      case 'npc_seojin':return false; // Gift is handled only by its one-time relationship scene.
      case 'npc_taeo':return f.stories.contains('story_taeo_01');
      case 'npc_eunchae':return !f.working && f.stories.contains('story_eunchae_01');
      case 'npc_minjae':return !f.running && f.stories.contains('story_minjae_01');
      case 'npc_sua':return f.stories.contains('story_sua_01');
    }
  }
  if(event=='neighbor') {
    switch(id) {
      case 'npc_yunha':return f.met.contains('npc_makrye');
      case 'npc_doyun':return f.met.contains('npc_taeo');
      case 'npc_makrye':return f.met.contains('npc_sua');
      case 'npc_seojin':return f.met.contains('npc_doyun') && f.stories.contains('story_seojin_01');
      case 'npc_taeo':return f.met.contains('npc_makrye');
      case 'npc_eunchae':return f.met.contains('npc_minjae') && f.timeFeature && f.morning;
      case 'npc_minjae':return f.met.contains('npc_doyun');
      case 'npc_sua':return f.met.contains('npc_makrye') && f.stories.contains('story_sua_01');
    }
  }
  // Trips, new menus, sold-out and pre-cooking cancellation need explicit state
  // transitions; never invent them from an empty inventory or calendar absence.
  return false;
}
Map<String,String>? selectCustomerSpeech(WorkshopCustomerCatalog catalog,String event,
    CustomerDialogueFacts facts,{List<String> recent=const []}) {
  final id='${facts.order.customerId.replaceFirst('npc_', '')}_${event}_01';
  return catalog.dialogue(facts.order.customerId,event,
    qualifiedIds:qualifiesCustomerDialogue(event,facts) ? {id}: {},recent:recent);
}
