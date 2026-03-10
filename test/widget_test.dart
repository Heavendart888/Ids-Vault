import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Make sure this matches your actual project name
import 'package:per_docs/main.dart'; 

void main() {
  testWidgets('Secure Vault UI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Replaced MyApp() with SecureDocApp() to match our new main.dart
    await tester.pumpWidget(const SecureDocApp());

    // Allow the initial Future from initState (_loadFilesList) to settle
    await tester.pumpAndSettle();

    // Verify that our AppBar title is present
    expect(find.text('Local Document Vault'), findsOneWidget);

    // Verify the initial empty state text is displayed
    expect(find.text('No documents stored yet.'), findsOneWidget);

    // Verify that the upload button is present on the screen
    expect(find.byIcon(Icons.upload_file), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
  });
}