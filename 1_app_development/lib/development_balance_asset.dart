import 'dart:convert';
import 'package:flutter/services.dart';
import 'development_balance.dart';

/// Explicit opt-in loader. Does not replace existing live prices or IAP data.
Future<DevelopmentBalance> loadDevelopmentBalance({AssetBundle? bundle}) async {
  final source = await (bundle ?? rootBundle)
      .loadString('config/development_balance.json');
  final data = jsonDecode(source);
  if (data is! Map<String, dynamic>) {
    throw const FormatException('개발 수치 설정 형식 오류');
  }
  return DevelopmentBalance.fromJson(data);
}
