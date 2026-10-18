import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';

void main(){
  CookingSession filling()=>CookingSession.start(id:'bag',flavor:'redbean',practice:true,
    fillingSequence:[CookingDirection.left,CookingDirection.right,CookingDirection.left,CookingDirection.right]).pour(0,2500);
  test('one squeeze records amount, preserves legacy codec and rejects duplicate/forged input',(){
    final before=filling(),next=before.squeezeFilling(before.token,1450);
    expect(next.phase,CookingPhase.secondBatter);
    expect(next.fillingDurationMs,1450);
    expect(isCookingSuccessor(before,next),isTrue);
    expect(isCookingSuccessor(next,next),isFalse);
    expect(next.squeezeFilling(before.token,9999),same(next));
    final restored=CookingSession.fromJson(jsonDecode(jsonEncode(next.toJson())) as Map<String,dynamic>);
    expect(restored.fillingDurationMs,1450);
    final later=restored.pour(restored.token,2500).close(restored.token+1);
    expect(later.fillingDurationMs,1450);
    expect(()=>before.squeezeFilling(before.token,-1),throwsFormatException);
    final forged=next.toJson()..['firstBatterMs']=1;
    expect(isCookingSuccessor(before,CookingSession.fromJson(forged)),isFalse);
  });
  test('old saves remain readable; new amount cannot appear before filling completes',(){
    final old=filling().toJson();
    expect(CookingSession.fromJson(old).fillingDurationMs,isNull);
    expect(()=>CookingSession.fromJson({...old,'fillingDurationMs':100}),throwsFormatException);
  });
  testWidgets('piping bag grows amount while held; another pointer cannot finish it', (tester) async {
    final results=<int>[];
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SizedBox(width:300,height:200,
      child:PipingBagControl(stageToken:1,blocked:false,capacityMs:4000,onFinished:results.add)))));
    final point=tester.getCenter(find.byType(PipingBagControl));
    final first=await tester.startGesture(point,pointer:1);
    await tester.pump();
    final second=await tester.startGesture(point,pointer:2);await second.up();
    await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:250)));
    await tester.pump(const Duration(milliseconds:100));
    expect(tester.widget<Text>(find.byKey(const Key('piping-amount'))).data,isNot(contains('속 양 0%')));
    expect(results,isEmpty);
    await first.up();await tester.pump();
    expect(results.length,1);expect(results.single,greaterThanOrEqualTo(200));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('paused squeeze cannot be harvested as filling on late release',(tester) async {
    final results=<int>[];
    Widget view(bool blocked)=>MaterialApp(home:Scaffold(body:SizedBox(width:300,height:200,
      child:PipingBagControl(stageToken:1,blocked:blocked,capacityMs:4000,onFinished:results.add))));
    await tester.pumpWidget(view(false));
    final gesture=await tester.startGesture(tester.getCenter(find.byType(PipingBagControl)));
    await tester.pumpWidget(view(true));await tester.pumpWidget(view(false));
    await gesture.up();expect(results,isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
