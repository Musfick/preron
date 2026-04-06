import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:preron/screens/balance_screen.dart';
import 'package:preron/screens/cashout_screen.dart';
import 'package:preron/screens/home_screen.dart';
import 'package:preron/screens/permission_screen.dart';
import 'package:preron/screens/send_money_screen.dart';
import 'package:preron/screens/splash_screen.dart';
import 'package:preron/service/ussd_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        title: 'preron',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
          textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
        ),
        themeMode: ThemeMode.light,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/permission': (context) => const PermissionScreen(),
          '/home': (context) => const HomeScreen(),
          '/cashout': (context) => const CashoutScreen(),
          '/balance': (context) => const BalanceScreen(),
          '/send-money': (context) => const SendMoneyScreen(),
        },
      ),
    );
  }
}
