import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wechat_index_demo/main.dart';

void main() {
  testWidgets('点击索引会跳转到对应分组', (WidgetTester tester) async {
    await tester.pumpWidget(const ContactIndexDemoApp());

    expect(find.text('微信式索引通讯录'), findsOneWidget);
    expect(find.text('安然'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('index-letter-W')));
    await tester.pumpAndSettle();

    final Text currentLetter = tester.widget<Text>(
      find.byKey(const ValueKey<String>('current-letter-badge')),
    );

    expect(currentLetter.data, 'W');
    expect(find.text('王强'), findsOneWidget);
  });
}
