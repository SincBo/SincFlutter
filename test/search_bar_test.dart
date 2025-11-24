import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincboflutter/ui/widgets/search_bar.dart';

void main() {
  testWidgets('DebouncedSearchBar calls onChanged after debounce', (WidgetTester tester) async {
    final calls = <String>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DebouncedSearchBar(
          debounceDuration: const Duration(milliseconds: 300),
          onChanged: (v) => calls.add(v),
        ),
      ),
    ));

    // Enter text and advance time just before debounce expires
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump(const Duration(milliseconds: 299));
    expect(calls, isEmpty, reason: 'onChanged should not be called before debounce');

    // Advance to reach debounce
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, equals(['hello']));
  });

  testWidgets('DebouncedSearchBar clear button clears text and calls onChanged immediately', (WidgetTester tester) async {
    final calls = <String>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DebouncedSearchBar(
          debounceDuration: const Duration(milliseconds: 300),
          onChanged: (v) => calls.add(v),
        ),
      ),
    ));

    // Enter text and wait for debounce to fire
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, equals(['abc']));

    // Tap clear icon
    final clearFinder = find.byIcon(Icons.clear);
    expect(clearFinder, findsOneWidget);
    await tester.tap(clearFinder);
    await tester.pump();

    // Clear should call onChanged with empty string
    expect(calls.last, equals(''));
  });
}

