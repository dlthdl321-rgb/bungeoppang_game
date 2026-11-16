import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_session.dart';

void main() {
  test('단계 전파 없이 첫 반죽·속·둘째 반죽·닫기·뒤집기·꺼내기 순서다', () {
    var session = CookingSession.start(id: 'result-1', flavor: 'redbean', practice: true,
        fillingSequence: [CookingDirection.left, CookingDirection.right]);
    session = session.pour(0, PaintAmount.even);
    expect(session.pour(0, PaintAmount.even), same(session));
    session = session.fill(session.token, CookingDirection.right);
    expect(session.wrongInputs, 1);
    session = session.fill(session.token, CookingDirection.left);
    session = session.fill(session.token, CookingDirection.right);
    session = session.pour(session.token, PaintAmount.even);
    session = session.close(session.token);
    session = session.flip(session.token);
    session = session.takeOut(session.token, 15000);
    expect(session.phase, CookingPhase.result);
    expect(session.takeOut(session.token, 20000), same(session));
    expect(session.donenessElapsedMs, 15000);
    final restored = CookingSession.fromJson(jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>);
    expect(restored.toJson(), session.toJson());
    expect(() => CookingSession.fromJson({...session.toJson(), 'token': 0}), throwsFormatException);
  });
  test('제작 후속 입력은 같은 ID·토큰이어도 맛/맥락/이전 반죽을 바꿀 수 없다', () {
    final start = CookingSession.start(id:'same-session', flavor:'redbean', practice:true,
      fillingSequence:[CookingDirection.left]);
    final poured = start.pour(start.token, const PaintAmount(800, 900));
    expect(isCookingSuccessor(start, poured), isTrue);
    final forged = poured.toJson()..['flavor'] = 'cocoa';
    expect(isCookingSuccessor(start, CookingSession.fromJson(forged)), isFalse);
    final changedContext = poured.toJson()..['practice'] = false;
    expect(isCookingSuccessor(start, CookingSession.fromJson(changedContext)), isFalse);
    expect(isCookingSuccessor(poured, poured.fill(poured.token, CookingDirection.left)), isTrue);
    expect(isCookingSuccessor(poured, poured), isFalse);
  });

}
