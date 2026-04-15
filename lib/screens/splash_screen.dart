import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:preron/service/ussd_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    checkPermissions();
    super.initState();
  }

  void checkPermissions() async {
    try {
      final callStatus = await Permission.phone.status;
      final bool accessibilityStatus =
      await UssdService.checkAccessibility();
      final bool overlayStatus =
      await UssdService.checkOverlayPermission();

      if (mounted) {
        if(callStatus.isGranted && accessibilityStatus && overlayStatus){
          Navigator.pushReplacementNamed(context, '/home');
        }else{
          Navigator.pushReplacementNamed(context, '/permission');
        }
      }
    } catch (e) {
      debugPrint('Permission check error: $e');

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Theme.of(context).colorScheme.surface,
                      Colors.white
                    ],
                  )
              ),
            ),
          ),
          Center(
            child: Text("preron.", style: Theme.of(context).textTheme.displaySmall,),
          ),
        ],
      ),
    );
  }
}
