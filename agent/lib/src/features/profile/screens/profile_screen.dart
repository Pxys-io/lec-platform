import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/theme/theme_cubit.dart';
import '../../../repositories/misc_repository.dart';

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
            _buildProfileItem(context, LucideIcons.download, 'My Downloads', onTap: () => context.push('/downloads')),
            _buildProfileItem(context, LucideIcons.mail, 'Messages', onTap: () => context.push('/inbox')),
            _buildProfileItem(context, LucideIcons.user, 'Personal Information'),
            _buildProfileItem(context, LucideIcons.award, 'My Certificates', onTap: () => _showCertificates(context)),
            _buildProfileItem(context, LucideIcons.creditCard, 'Subscription'),
            _buildProfileItem(context, LucideIcons.bell, 'Notifications'),
            _buildProfileItem(context, LucideIcons.qrCode, 'Redeem Code', onTap: () => _showRedeemDialog(context)),
            if (user?.role == 'admin' || user?.role == 'super_admin' || user?.role == 'instructor')
              _buildProfileItem(context, LucideIcons.shield, 'Admin Dashboard', onTap: () => context.push('/admin')),
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

  Widget _buildProfileItem(BuildContext context, IconData icon, String label, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: onTap,
    );
  }

  Future<void> _showCertificates(BuildContext context) async {
    try {
      final certificates = await context.read<MiscRepository>().getCertificates();
      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('My Certificates', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    if (certificates.isEmpty)
                      const Expanded(
                        child: Center(child: Text('No certificates yet')),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: certificates.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final cert = certificates[index];
                            return ListTile(
                              leading: const Icon(LucideIcons.award, color: Colors.amber),
                              title: Text(cert.title),
                              subtitle: Text('Issued: ${_formatDate(cert.issuedAt)}'),
                              trailing: const Icon(LucideIcons.externalLink),
                              onTap: () {},
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load certificates: $e')),
        );
      }
    }
  }

  Future<void> _showRedeemDialog(BuildContext context) async {
    final codeController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Redeem Code'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'Enter code',
              prefixIcon: Icon(LucideIcons.qrCode),
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(LucideIcons.check),
              label: const Text('Redeem'),
              onPressed: () {
                final code = codeController.text.trim();
                if (code.isEmpty) return;
                Navigator.of(dialogContext).pop(code);
              },
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty || !context.mounted) return;

    try {
      final response = await context.read<MiscRepository>().validateCode({'code': result});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Code redeemed successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to redeem code: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
