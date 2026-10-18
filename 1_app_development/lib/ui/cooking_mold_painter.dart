import 'package:flutter/material.dart';
import '../cooking_session.dart';
import 'cozy_style.dart';

/// Opaque iron plate replaces the baked fish in the static background while
/// making a new product. Ingredients are separate layers; no finished fish.
class CookingMoldPainter extends CustomPainter {
  final CookingPhase phase;
  final bool hasBatter,hasFilling;
  const CookingMoldPainter({required this.phase,required this.hasBatter,required this.hasFilling});
  static Path cavity(Size size) {
    final path=Path()..moveTo(.06,.50)..cubicTo(.06,.18,.37,.08,.61,.27)
      ..lineTo(.70,.36)..lineTo(.94,.20)..quadraticBezierTo(.99,.48,.94,.81)
      ..lineTo(.70,.66)..cubicTo(.43,.91,.06,.82,.06,.50)..close();
    return path.transform(Matrix4.diagonal3Values(size.width,size.height,1).storage);
  }
  @override
  void paint(Canvas canvas,Size size){
    final outline=Path()..moveTo(.04,.5)..cubicTo(.04,.22,.22,.14,.33,.16)
      ..lineTo(.44,.02)..quadraticBezierTo(.61,-.02,.64,.24)
      ..quadraticBezierTo(.71,.26,.74,.38)..lineTo(.95,.18)
      ..quadraticBezierTo(1,.18,.98,.48)..quadraticBezierTo(1,.8,.95,.88)
      ..lineTo(.74,.67)..quadraticBezierTo(.65,.84,.59,.84)
      ..lineTo(.51,.99)..quadraticBezierTo(.38,.99,.35,.83)
      ..cubicTo(.17,.83,.04,.76,.04,.5)..close();
    final plate=outline.transform(Matrix4.diagonal3Values(size.width,size.height,1).storage)
      ..addOval(Rect.fromLTWH(0,0,size.width*.94,size.height));
    canvas.drawPath(plate,Paint()..color=const Color(0xff292426));
    canvas.drawPath(plate,Paint()..color=const Color(0xff5c5050)..style=PaintingStyle.stroke..strokeWidth=7);
    final fish=cavity(size);
    canvas.drawPath(fish,Paint()..color=const Color(0xff141316));
    canvas.drawPath(fish,Paint()..color=const Color(0xff756463)..style=PaintingStyle.stroke..strokeWidth=4);
    if(phase==CookingPhase.flipping || phase==CookingPhase.cooking){
      canvas.drawPath(plate,Paint()..color=const Color(0xff3d3638));
      canvas.drawLine(Offset(size.width*.40,size.height*.5),Offset(size.width*.60,size.height*.5),Paint()..color=Cozy.woodLight..strokeWidth=8..strokeCap=StrokeCap.round);
      return;
    }
    canvas.save();canvas.clipPath(fish);
    if(hasBatter)canvas.drawRect(Offset.zero & size,Paint()..color=const Color(0xffe9d6a7));
    if(hasFilling)canvas.drawOval(Rect.fromCenter(center:size.center(Offset.zero),width:size.width*.4,height:size.height*.25),Paint()..color=const Color(0xff642b27));
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant CookingMoldPainter old)=>phase!=old.phase || hasBatter!=old.hasBatter || hasFilling!=old.hasFilling;
}
