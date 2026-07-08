import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/theme/theme_cubit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: user?.avatarUrl != null 
                      ? NetworkImage(user!.avatarUrl!) 
                      : const NetworkImage('https://i.pravatar.cc/150'),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(LucideIcons.edit2, size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(user?.fullName ?? 'Student Name', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 22)),
            Text('${user?.id ?? 'STU-0000'} • ${user?.role ?? 'Student'}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 32),
            _buildProfileItem(context, LucideIcons.user, 'Personal Information'),
            _buildProfileItem(context, LucideIcons.award, 'My Certificates'),
            _buildProfileItem(context, LucideIcons.creditCard, 'Subscription'),
            _buildProfileItem(context, LucideIcons.bell, 'Notifications'),
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return SwitchListTile(
                  secondary: const Icon(LucideIcons.moon),
                  title: const Text('Dark Mode'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    context.read<ThemeCubit>().setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                  },
                );
              },
            ),
            _buildProfileItem(context, LucideIcons.helpCircle, 'Support'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                context.read<AuthCubit>().logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                elevation: 0,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, IconData icon, String label) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: () {},
    );
  }
}
