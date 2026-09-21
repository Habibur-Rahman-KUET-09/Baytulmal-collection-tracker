import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_data_provider.dart';
import 'screens/protisthan_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BaytulmalApp());
}

class BaytulmalApp extends StatelessWidget {
  const BaytulmalApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF00695C); // teal — matches the app icon

    return ChangeNotifierProvider(
      create: (_) => AppDataProvider(),
      child: MaterialApp(
        title: 'বাইতুলমাল কালেকশন ট্র্যাকার',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
          useMaterial3: true,
          fontFamily: 'NotoSansBengali',
          appBarTheme: const AppBarTheme(centerTitle: false),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'NotoSansBengali',
        ),
        home: const ProtisthanListScreen(),
      ),
    );
  }
}
