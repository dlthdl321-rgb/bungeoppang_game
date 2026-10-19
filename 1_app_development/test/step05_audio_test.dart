import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/game_audio.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'controller_test.dart' show FakeTime;
import 'stage10_feedback_test.dart' show FakeAudio;
import 'workshop_controller_test.dart' show Repository;

void main() {
  testWidgets('광고·앱 중단이 겹쳐도 광고 종료만으로 오디오를 재개하지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync())
            as Map<String, dynamic>);
    final workshop = WorkshopController(config, Repository());
    await workshop.initialize();
    final controller = GameController(MemoryGameRepository(), FakeTime());
    await controller.initialize();
    final audio = FakeAudio();
    await tester.pumpWidget(
        GameApp(controller: controller, workshop: workshop, audio: audio));
    await tester.pump();
    expect(audio.musicPlaying, isTrue);
    workshop.setAdPaused(true);
    expect(audio.musicPlaying, isFalse);
    audio.play(Sfx.reward);
    expect(audio.sounds, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    workshop.setAdPaused(false);
    expect(audio.musicPlaying, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(audio.musicPlaying, isTrue);
    workshop.setAdPaused(true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(audio.musicPlaying, isFalse);
    workshop.setAdPaused(false);
    expect(audio.musicPlaying, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
