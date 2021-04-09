import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/translations.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      supportedLocales: Translations.supportedLocales,
      localizationsDelegates: const [
        Translations.delegate,
      ],
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text(Translations.of(context).hello),
    );
  }
}
