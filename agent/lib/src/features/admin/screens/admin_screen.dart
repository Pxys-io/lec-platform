import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../repositories/misc_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../repositories/course_repository.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>>? _reports;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final misc = context.read<MiscRepository>();
      final overview = await misc.getStatsOverview();
      final reports = await misc.getReports();
      if (mounted) {
        setState(() {
          _stats = {
            'total_users': overview.totalUsers,
            'total_courses': overview.totalCourses,
            'total_lessons': overview.totalLessons,
            'total_watch_time': overview.totalWatchTime,
          };
          _reports = reports
              .where((r) => r.status == 'pending')
              .map((r) => {'id': r.id, 'target_type': r.targetType, 'reason': r.reason, 'status': r.status})
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final isAdmin = user?.role == 'admin' || user?.role == 'super_admin';

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('Admin access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatGrid(),
                  const SizedBox(height: 24),
                  Text('Pending Reports', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (_reports == null || _reports!.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No pending reports')))
                  else
                    ..._reports!.map((r) => Card(
                          child: ListTile(
                            leading: const Icon(LucideIcons.flag, color: Colors.red),
                            title: Text(r['reason'] as String),
                            subtitle: Text('${r['target_type']} • ${r['status']}'),
                            trailing: TextButton(
                              onPressed: () async {
                                try {
                                  await context.read<MiscRepository>().updateReport(r['id'] as String, {'status': 'resolved'});
                                  _loadData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Report resolved')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Resolve'),
                            ),
                          ),
                        )),
                  const SizedBox(height: 24),
                  Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(LucideIcons.users),
                          title: const Text('Manage Users'),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(LucideIcons.bookOpen),
                          title: const Text('Manage Courses'),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(LucideIcons.smartphone),
                          title: const Text('User Devices'),
                          subtitle: const Text('View & reset device limits'),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => _showDeviceManagement(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(LucideIcons.barChart3),
                          title: const Text('View All Certificates'),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Users', '${_stats?['total_users'] ?? 0}', LucideIcons.users, Colors.blue),
        _buildStatCard('Courses', '${_stats?['total_courses'] ?? 0}', LucideIcons.bookOpen, Colors.green),
        _buildStatCard('Lessons', '${_stats?['total_lessons'] ?? 0}', LucideIcons.fileText, Colors.orange),
        _buildStatCard('Watch Hours', '${(_stats?['total_watch_time'] as num? ?? 0) ~/ 3600}h', LucideIcons.clock, Colors.purple),
      ],
    );
  }

  void _showDeviceManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DeviceManagementSheet(),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DeviceManagementSheet extends StatefulWidget {
  @override
  State<_DeviceManagementSheet> createState() => _DeviceManagementSheetState();
}

class _DeviceManagementSheetState extends State<_DeviceManagementSheet> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  Map<String, dynamic>? _selectedUserDevices;
  bool _devicesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await context.read<UserRepository>().getUsers();
      if (mounted) {
        setState(() {
          _users = users
              .where((u) => u.role != 'super_admin')
              .map((u) => {
                    'id': u.id,
                    'email': u.email,
                    'name': u.fullName,
                    'role': u.role,
                  })
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDevices(String userId) async {
    setState(() => _devicesLoading = true);
    try {
      final devices = await context.read<UserRepository>().getUserDevices(userId);
      if (mounted) {
        setState(() {
          _selectedUserDevices = devices;
          _devicesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _devicesLoading = false);
    }
  }

  Future<void> _resetDevices(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Devices'),
        content: const Text('This will remove all registered devices for this user. They can log in again from any device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await context.read<UserRepository>().resetUserDevices(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devices reset successfully')),
        );
        setState(() => _selectedUserDevices = null);
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('User Devices', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Tap a user to view and reset their devices', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              if (_selectedUserDevices != null) ...[
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _selectedUserDevices = null),
                    ),
                    Text('Device Limit: ${_selectedUserDevices!['device_limit']}',
                      style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text('Reset All'),
                      onPressed: () => _resetDevices(_selectedUserDevices!['user_id']),
                    ),
                  ],
                ),
                const Divider(),
                if (_devicesLoading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if ((_selectedUserDevices!['devices'] as List).isEmpty)
                  const Expanded(child: Center(child: Text('No devices registered')))
                else
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: (_selectedUserDevices!['devices'] as List).map((d) {
                        final isMobile = d['device_type'] == 'mobile';
                        return Card(
                          child: ListTile(
                            leading: Icon(isMobile ? Icons.phone_android : Icons.desktop_windows),
                            title: Text(isMobile ? 'Mobile' : 'Desktop'),
                            subtitle: Text('Last login: ${d['last_login'] ?? 'N/A'}'),
                            trailing: Text(d['device_id'].toString().substring(0, 8)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ] else ...[
                if (_loading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: _users.map((u) {
                        return ListTile(
                          leading: CircleAvatar(child: Text((u['name'] as String).isNotEmpty ? (u['name'] as String)[0].toUpperCase() : '?')),
                          title: Text(u['name'] as String),
                          subtitle: Text('${u['email']}  •  ${u['role']}'),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => _loadDevices(u['id']),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
