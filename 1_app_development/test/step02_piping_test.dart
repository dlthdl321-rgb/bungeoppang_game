import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_session.dart';

/// 짤주머니 속 넣기(24번 5단계: 문질러 칠한 양)의 세션 규칙.
void main(){
  CookingSession filling()=>CookingSession.start(id:'bag',flavor:'redbean',practice:true,
    fillingSequence:[CookingDirection.left,CookingDirection.right,CookingDirection.left,CookingDirection.right]).pour(0,PaintAmount.even);
  test('one stroke records the painted amount, preserves legacy codec and rejects duplicate/forged input',(){
    const amount=PaintAmount(720,830);
    final before=filling(),next=before.squeezeFilling(before.token,amount);
    expect(next.phase,CookingPhase.secondBatter);
    expect(next.filling,amount);
    expect(next.fillingIndex,4);
    expect(isCookingSuccessor(before,next),isTrue);
    expect(isCookingSuccessor(next,next),isFalse);
    expect(next.squeezeFilling(before.token,PaintAmount.even),same(next));
    final restored=CookingSession.fromJson(jsonDecode(jsonEncode(next.toJson())) as Map<String,dynamic>);
    expect(restored.filling,amount);
    final later=restored.pour(restored.token,PaintAmount.even).close(restored.token+1);
    expect(later.filling,amount);
    expect(()=>before.squeezeFilling(before.token,const PaintAmount(0,0)),throwsFormatException);
    final forged=next.toJson()..['firstBatterAmount']=1100;
    expect(isCookingSuccessor(before,CookingSession.fromJson(forged)),isFalse);
  });
  test('the filling is not judged: any amount, even overflow, is a step',(){
    final before=filling();
    expect(before.squeezeFilling(before.token,const PaintAmount(150,150)).phase,CookingPhase.secondBatter);
    expect(before.squeezeFilling(before.token,const PaintAmount(1000,4000)).phase,CookingPhase.secondBatter);
  });
  test('old saves remain readable; new amount cannot appear before filling completes',(){
    final old=filling().toJson();
    expect(CookingSession.fromJson(old).filling,isNull);
    expect(()=>CookingSession.fromJson({...old,'fillingDurationMs':100}),throwsFormatException);
    expect(()=>CookingSession.fromJson({...old,'fillingCoverage':500,'fillingAmount':500}),throwsFormatException);
  });
}
