// 저녁 산책 앱의 기본 위젯 테스트
// 
// 앱의 주요 화면과 기능들이 올바르게 작동하는지 확인합니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:walk/main.dart';

void main() {
  setUpAll(() async {
    // 테스트 환경에서 필요한 초기화
    await dotenv.load(fileName: 'assets/config/.env');
  });

  testWidgets('MyApp widget smoke test', (WidgetTester tester) async {
    // MyApp 위젯을 빌드하고 첫 프레임을 트리거
    await tester.pumpWidget(const MyApp());
    
    // 앱이 로딩 중임을 나타내는 CircularProgressIndicator 확인
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // 앱 제목이 올바른지 확인
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, '산책 앱');
    
    // 디버그 배너가 비활성화되어 있는지 확인
    expect(materialApp.debugShowCheckedModeBanner, false);
    
    // Material3가 비활성화되어 있는지 확인 (useMaterial3: false)
    expect(materialApp.theme?.useMaterial3, false);
    
    // 폰트 패밀리가 올바른지 확인
    expect(materialApp.theme?.textTheme.bodyMedium?.fontFamily, 'Cafe24Oneprettynight');
  });

  testWidgets('App routes are configured correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    
    // 필요한 라우트들이 정의되어 있는지 확인
    expect(materialApp.routes, isNotNull);
    expect(materialApp.routes!.containsKey('/login'), true);
    expect(materialApp.routes!.containsKey('/homescreen'), true);
    expect(materialApp.routes!.containsKey('/walk_history'), true);
  });

  testWidgets('SnackBar theme is configured correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final snackBarTheme = materialApp.theme?.snackBarTheme;
    
    expect(snackBarTheme, isNotNull);
    expect(snackBarTheme?.behavior, SnackBarBehavior.floating);
    expect(snackBarTheme?.elevation, 0);
    expect(snackBarTheme?.contentTextStyle?.fontFamily, 'Cafe24Oneprettynight');
    expect(snackBarTheme?.contentTextStyle?.fontSize, 16);
    expect(snackBarTheme?.contentTextStyle?.color, Colors.white);
  });
}
