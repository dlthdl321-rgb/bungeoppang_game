import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_session.dart';

void main() {
  test('센서는 보정 뒤 경계1회·중립 복귀 후 다음 입력만 전달한다', () {
    final gate = TiltDirectionGate(activation: 15000, deadZone: 5000);
    expect(gate.sample(20000), isNull);
    gate.calibrate(1000);
    expect(gate.sample(15999), isNull);
    expect(gate.sample(16000), CookingDirection.right);
    expect(gate.sample(-16000), isNull);
    expect(gate.sample(6000), isNull);
    expect(gate.sample(-14000), CookingDirection.left);
    gate.reset();
    expect(gate.calibrated, isFalse);
  });
  test('포인터 취소와 늦은 해제는 반죽을 확정하지 않는다', () {
    final input = BatterHoldInput(2);
    input.begin(token: 2, pointer: 1, monotonicMs: 100);
    expect(input.finish(token: 1, pointer: 1, monotonicMs: 200), isNull);
    expect(input.finish(token: 2, pointer: 2, monotonicMs: 200), isNull);
    input.cancel();
    expect(input.finish(token: 2, pointer: 1, monotonicMs: 300), isNull);
    input.begin(token: 2, pointer: 1, monotonicMs: 400);
    expect(input.finish(token: 2, pointer: 1, monotonicMs: 650), 250);
  });
  test('단계 전파 없이 첫 반죽·속·둘째 반죽·닫기·뒤집기·꺼내기 순서다', () {
    var session = CookingSession.start(id: 'result-1', flavor: 'redbean', practice: true,
        fillingSequence: [CookingDirection.left, CookingDirection.right]);
    session = session.pour(0, 2500);
    expect(session.pour(0, 2500), same(session));
    session = session.fill(session.token, CookingDirection.right);
    expect(session.wrongInputs, 1);
    session = session.fill(session.token, CookingDirection.left);
    session = session.fill(session.token, CookingDirection.right);
    session = session.pour(session.token, 2500);
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
}
