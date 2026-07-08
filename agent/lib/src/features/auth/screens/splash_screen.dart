import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../backend.dart';
import '../../../repositories/misc_repository.dart';
import '../../../services/server_mode_service.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../misc/screens/panic_mode_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      final miscRepo = context.read<MiscRepository>();
      final backend = context.read<Backend>();
      final deviceId = backend.deviceId;
      final platform = Platform.operatingSystem;
      const version = '1.0.0'; // Should come from package_info
      const buildNumber = '1';

      final handshake = await miscRepo.appHandshake({
        'platform': platform,
        'version': version,
        'build_number': buildNumber,
        'device_id': deviceId,
      });

      await ServerModeService().updateFromHandshake(handshake);

      if (handshake['panic_mode'] == true) {
        if (mounted) {
          final token = context.read<AuthCubit>().token;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PanicModeScreen(
                url: handshake['webview_url'],
                token: token,
                deviceId: deviceId,
              ),
            ),
          );
        }
        return;
      }
    } catch (e) {
      print('Handshake failed: $e');
    }

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_services, size: 80, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'beIN Med',
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
