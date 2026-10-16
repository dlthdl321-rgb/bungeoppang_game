import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/workshop_customers.dart';
import 'package:todays_bungeoppang/ui/customer_story_panel.dart';
void main() {
  testWidgets('선택 순서를 바꿔도 안정 ID를 보내고 점수·실명은 표시하지 않는다',(tester) async {
    final catalog=WorkshopCustomerCatalog.bundled();String? selected;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:CustomerChoicePanel(
      catalog:catalog,eventId:'choice_doyun_01',completedStories:{},choiceOrder:['c','a','b'],
      onSelect:(id) async {selected=id;return true;},onCloseReaction:() async=>true))));
    final event=catalog.choice('choice_doyun_01');
    final first=(event['choices'] as List).cast<Map>().singleWhere((c)=>c['id']=='c');
    await tester.tap(find.text(first['text'] as String));await tester.pump();
    expect(selected,'c');expect(find.text('김도윤'),findsNothing);
    expect(find.text('+3'),findsNothing);expect(find.byType(OutlinedButton),findsNWidgets(3));
  });
  testWidgets('만나지 않은 손님은 외모·사연·이름을 미리 공개하지 않는다',(tester) async {
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:CustomerRecordCard(
      catalog:WorkshopCustomerCatalog.bundled(),npcId:'npc_yunha',met:false,
      completedStories:{},stageLabel:'첫 만남'))));
    expect(find.text('아직 만나지 않은 이웃'),findsOneWidget);
    expect(find.text('퇴근길 윤하 씨'),findsNothing);
  });
}
