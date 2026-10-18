import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cooking_session_controls.dart' show BatterHoldButton;
import 'cozy_style.dart';

/// One squeeze owns one pointer and one stage. Released duration is the amount
/// evidence; the gauge is presentation only and does not invent a quality rule.
class PipingBagControl extends StatelessWidget {
  final int stageToken, capacityMs;
  final bool blocked, onMold;
  final void Function(int) onFinished;
  const PipingBagControl({super.key,required this.stageToken,required this.blocked,
    required this.capacityMs,required this.onFinished,this.onMold=false});
  @override
  Widget build(BuildContext context) => SizedBox(width:onMold ? double.infinity : 240,height:onMold ? double.infinity : 180,child:BatterHoldButton(
    key:ValueKey('piping:$stageToken'),stageToken:stageToken,blocked:blocked,
    label:'짤주머니로 속 넣기',onFinished:onFinished,
    surfaceBuilder:(pouring)=>PourAmountVisual(key:ValueKey('$stageToken:$pouring'),
      pouring:pouring,capacityMs:capacityMs)));
}
class PourAmountVisual extends StatefulWidget {
  final bool pouring, filling;
  final int capacityMs;
  const PourAmountVisual({super.key,required this.pouring,required this.capacityMs,this.filling=true});
  @override
  State<PourAmountVisual> createState()=>PourAmountVisualState();
}
class PourAmountVisualState extends State<PourAmountVisual> {
  final _clock=Stopwatch();
  Timer? _timer;
  @override
  void initState(){super.initState();if(widget.pouring){_clock.start();_timer=Timer.periodic(const Duration(milliseconds:100),(_){if(mounted)setState((){});});}}
  @override
  void dispose(){_timer?.cancel();_clock.stop();super.dispose();}
  @override
  Widget build(BuildContext context){
    final amount=_clock.elapsedMilliseconds/widget.capacityMs;
    return Stack(fit:StackFit.expand,children:[
      IgnorePointer(child:CustomPaint(painter:_BagPainter(widget.pouring,amount,widget.filling))),
      Align(alignment:Alignment.bottomCenter,child:Container(
        padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
        decoration:BoxDecoration(color:Cozy.woodDark.withValues(alpha:.9),borderRadius:BorderRadius.circular(8)),
        child:Text(widget.pouring ? '${widget.filling ? '속' : '반죽'} 양 ${(amount*100).toStringAsFixed(0)}% · 놓으면 마무리' : widget.filling ? '짤주머니를 길게 눌러 속을 짜 주세요' : '큰 틀을 길게 눌러 반죽을 부어 주세요',
          key:const Key('piping-amount'),textAlign:TextAlign.center,
          style:const TextStyle(color:Cozy.cream,fontWeight:FontWeight.bold,fontSize:13)))),
    ]);
  }
}
class _BagPainter extends CustomPainter {
  final bool pouring,filling;final double amount;
  _BagPainter(this.pouring,this.amount,this.filling);
  @override
  void paint(Canvas canvas,Size size){
    final center=Offset(size.width*.5,size.height*.58);
    if(amount>0){
      final width=size.width*.5*math.min(1,amount);
      final paste=Paint()..color=(filling ? const Color(0xff642b27) : const Color(0xffe9d6a7))..strokeWidth=math.max(6,size.height*.12)..strokeCap=StrokeCap.round;
      canvas.drawLine(center-Offset(width/2,0),center+Offset(width/2,0),paste);
    }
    if(!filling) return;
    canvas.save();
    canvas.translate(size.width*.65,size.height*.05);
    canvas.rotate(.35);
    final w=math.min(size.width*.25,76.0),h=math.min(size.height*.55,105.0);
    final bag=Path()..moveTo(-w*.5,0)..quadraticBezierTo(0,-h*.14,w*.5,0)
      ..quadraticBezierTo(w*(pouring ? .32:.5),h*.3,0,h)..quadraticBezierTo(-w*.42,h*.3,-w*.5,0)..close();
    canvas.drawPath(bag,Paint()..color=const Color(0xfff7e1ad));
    canvas.drawPath(bag,Paint()..color=Cozy.wood..style=PaintingStyle.stroke..strokeWidth=3);
    canvas.drawLine(Offset(-w*.45,0),Offset(w*.45,0),Paint()..color=Cozy.orangeDeep..strokeWidth=7);
    canvas.drawPath(Path()..moveTo(-5,h*.9)..lineTo(5,h*.9)..lineTo(0,h+12)..close(),Paint()..color=const Color(0xffa9adb0));
    if(pouring)canvas.drawLine(Offset(0,h+12),Offset(0,h+30),Paint()..color=const Color(0xff642b27)..strokeWidth=7..strokeCap=StrokeCap.round);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _BagPainter old)=>old.pouring!=pouring || old.amount!=amount;
}
