import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/theme/theme_cubit.dart';
import '../../../models/user.dart';
import '../../../repositories/misc_repository.dart';
import '../../../repositories/auth_repository.dart';

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
            icon: const Icon(LucideIcons.userCog),
            tooltip: 'Edit profile',
            onPressed: () => _showEditProfile(context, user),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  _initials(user),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.fullName.isNotEmpty == true ? user!.fullName : 'Student',
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontSize: 22),
            ),
            Text(
              '${user?.email ?? ''} • ${user?.role ?? 'student'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
            _buildProfileItem(
              context,
              LucideIcons.download,
              'My Downloads',
              onTap: () => context.push('/downloads'),
            ),
            _buildProfileItem(
              context,
              LucideIcons.mail,
              'Messages',
              onTap: () => context.push('/inbox'),
            ),
            _buildProfileItem(
              context,
              LucideIcons.award,
              'My Certificates',
              onTap: () => _showCertificates(context),
            ),
            _buildProfileItem(
              context,
              LucideIcons.qrCode,
              'Redeem Code',
              onTap: () => _showRedeemDialog(context),
            ),
            if (user?.role == 'admin' || user?.role == 'super_admin')
              _buildProfileItem(
                context,
                LucideIcons.shield,
                'Admin Dashboard',
                onTap: () => context.push('/admin'),
              ),
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return SwitchListTile(
                  secondary: const Icon(LucideIcons.moon),
                  title: const Text('Dark Mode'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    context.read<ThemeCubit>().setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                  },
                );
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.read<AuthCubit>().logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onErrorContainer,
                  elevation: 0,
                ),
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(User? user) {
    final name = user?.fullName.trim() ?? '';
    if (name.isEmpty) return '?';
    return name
        .split(RegExp(r'\s+'))
        .take(2)
        .map((p) => p[0])
        .join()
        .toUpperCase();
  }

  Widget _buildProfileItem(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: onTap,
    );
  }

  Future<void> _showEditProfile(BuildContext context, User? user) async {
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final parts = (user?.fullName ?? '').trim().split(RegExp(r'\s+'));
    final firstNameController = TextEditingController(text: parts.isNotEmpty ? parts.first : '');
    final lastNameController =
        TextEditingController(text: parts.length > 1 ? parts.sublist(1).join(' ') : '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) return;

    try {
      await context.read<AuthRepository>().updateCurrentUser({
        if (firstNameController.text.trim().isNotEmpty)
          'first_name': firstNameController.text.trim(),
        if (lastNameController.text.trim().isNotEmpty)
          'last_name': lastNameController.text.trim(),
        if (emailController.text.trim().isNotEmpty)
          'email': emailController.text.trim(),
        if (phoneController.text.trim().isNotEmpty)
          'phone': phoneController.text.trim(),
      });
      // Refresh the cached user so the UI reflects the change.
      final fresh = await context.read<AuthRepository>().getCurrentUser();
      if (context.mounted) {
        context.read<AuthCubit>().updateUser(fresh);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
  }

  Future<void> _showCertificates(BuildContext context) async {
    try {
      final certificates =
          await context.read<MiscRepository>().getCertificates();
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
                    Text(
                      'My Certificates',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
                              leading: const Icon(
                                LucideIcons.award,
                                color: Colors.amber,
                              ),
                              title: Text(cert.title),
                              subtitle: Text(
                                'Issued: ${_formatDate(cert.issuedAt)}',
                              ),
                              trailing: const Icon(LucideIcons.externalLink),
                              onTap: () => _showCertificateDetails(
                                context,
                                cert.title,
                                cert.certificateHash,
                                cert.issuedAt,
                                cert.expiryDate,
                              ),
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

  void _showCertificateDetails(
    BuildContext context,
    String title,
    String hash,
    DateTime issuedAt,
    DateTime? expiryDate,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(LucideIcons.award, color: Colors.amber, size: 40),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issued: ${_formatDate(issuedAt)}'),
            if (expiryDate != null)
              Text('Expires: ${_formatDate(expiryDate)}'),
            const SizedBox(height: 12),
            Text(
              'Certificate ID: $hash',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
      final response =
          await context.read<MiscRepository>().validateCode({'code': result});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Code redeemed successfully',
            ),
          ),
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