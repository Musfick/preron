import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:preron/service/ussd_service.dart';
import 'package:preron/widgets/buttons.dart';
import 'package:preron/widgets/widgets.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {

  bool _callPermissionGranted = false;
  bool _accessibilityEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final callStatus = await Permission.phone.status;
      final bool accessibilityStatus =
          await UssdService.checkAccessibility();

      if (mounted) {
        setState(() {
          _callPermissionGranted = callStatus.isGranted;
          _accessibilityEnabled = accessibilityStatus ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> requestCallPermission() async {
    final status = await Permission.phone.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    if (mounted) setState(() => _callPermissionGranted = status.isGranted);
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await UssdService.openAccessibilitySettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open Accessibility Settings'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canContinue = _callPermissionGranted && _accessibilityEnabled;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("preron.", style: Theme.of(context).textTheme.headlineLarge,),
                    SizedBox(height: 16,),
                    Text(
                      "bKash but Offline: Cashout, Send Money, Balance Check Without the Internet.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PermissionCard(
                        title: 'Phone / Call Permission',
                        iconData: Icons.phone,
                        isGranted: _callPermissionGranted,
                        isLoading: _isLoading,
                        onAction: requestCallPermission,
                        actionText: 'Grant',
                      ),
                      SizedBox(height: 16),
                      PermissionCard(
                        title: 'Accessibility Service',
                        iconData: Icons.accessibility,
                        isGranted: _accessibilityEnabled,
                        isLoading: _isLoading,
                        onAction: openAccessibilitySettings,
                        actionText: 'Enable',
                      ),
                      SizedBox(height: 24),
                      PreronButton(
                        text: "Continue",
                        onPressed: canContinue ? (){
                          Navigator.pushReplacementNamed(context, '/home');
                        } : null,
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
