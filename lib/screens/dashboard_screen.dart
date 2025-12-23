import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/inventory_service.dart';
import '../models/inventory_item.dart';
import '../providers/auth_providers.dart';
import 'upload_screen.dart';
import 'inventory_view_screen.dart';
import 'login_screen.dart';
import 'bulk_delete_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<Store> _stores = [];
  List<Store> _filteredStores = [];
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadData(refreshProfile: false); // Don't refresh profile on initial load
  }

  Future<void> _loadData({bool refreshProfile = true}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current manager first (from local cache - instant)
      var manager = ref.read(currentManagerProvider);
      
      // If refresh requested, refresh manager profile first to get latest vendorIds
      if (refreshProfile) {
        await ref.read(authStateProvider.notifier).refreshProfile();
        manager = ref.read(currentManagerProvider);
      }
      
      List<Store> stores;
      
      if (manager == null) {
        stores = [];
        print('DASHBOARD: No manager logged in');
      } else if (manager.isAdmin) {
        // Admin: fetch ALL stores
        stores = await InventoryService.getStores();
        print('DASHBOARD: Admin - fetched all ${stores.length} stores');
      } else if (manager.vendorIds.isNotEmpty) {
        // Regular manager: fetch ONLY their assigned stores (optimized!)
        stores = await InventoryService.getStoresByIds(manager.vendorIds);
        print('DASHBOARD: Manager ${manager.name} - fetched ${stores.length} stores');
      } else {
        stores = [];
        print('DASHBOARD: No assigned stores');
      }
      
      // Calculate stats from stores (NO API CALL - instant!)
      final stats = _calculateStatsFromStores(stores);
      
      setState(() {
        _stores = stores;
        _filteredStores = stores; // Already filtered by backend
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Calculate stats from stores data (no API calls needed!)
  Map<String, dynamic> _calculateStatsFromStores(List<Store> stores) {
    if (stores.isEmpty) {
      return {'totalMedicines': 0, 'totalInventory': 0, 'totalStores': 0};
    }
    
    int totalMedicines = 0;
    int totalInventory = 0;
    
    for (final store in stores) {
      totalMedicines += store.totalMedicines;
      totalInventory += store.activeMedicines; // Count active items as inventory records
    }
    
    return {
      'totalMedicines': totalMedicines,
      'totalInventory': totalInventory,
      'totalStores': stores.length,
    };
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 12),
            Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Logout', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _showLinkEmailDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link, color: Color(0xFF0D47A1)),
              ),
              const SizedBox(width: 12),
              Text('Link Email Account', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add an email and password to your account. This will allow you to sign in with either phone OTP or email/password.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'your@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Min 8 chars with upper, lower, digit, symbol',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Password: 8+ chars with uppercase, lowercase, digit, and special char (@\$!%*?&)',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () {
                if (emailController.text.trim().isEmpty || !emailController.text.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (passwordController.text.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 8 characters'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'email': emailController.text.trim(),
                  'password': passwordController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Link Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _linkEmailAccount(result['email']!, result['password']!);
    }
  }

  Future<void> _showSetPasswordDialog() async {
    final manager = ref.read(currentManagerProvider);
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final emailController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    final needsEmail = manager?.email == null || manager!.email!.isEmpty;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: Color(0xFF0D47A1)),
              ),
              const SizedBox(width: 12),
              Text(
                needsEmail ? 'Set Password' : 'Change Password',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (needsEmail) ...[
                  Text(
                    'Email is required for password-based login',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'your@email.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Min 8 chars with upper, lower, digit, symbol',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () {
                if (needsEmail && (emailController.text.trim().isEmpty || !emailController.text.contains('@'))) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (passwordController.text.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 8 characters'), backgroundColor: Colors.red),
                  );
                  return;
                }
                if (passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'email': emailController.text.trim(),
                  'password': passwordController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Password', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _linkEmailAccount(result['email']!, result['password']!);
    }
  }

  Future<void> _linkEmailAccount(String email, String password) async {
    final manager = ref.read(currentManagerProvider);
    if (manager == null) return;

    try {
      final success = await ref.read(authStateProvider.notifier).setPassword(
        managerId: manager.id,
        email: email.isNotEmpty ? email : null,
        password: password,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(email.isNotEmpty 
                ? 'Email linked successfully! You can now sign in with email/password.'
                : 'Password updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh to show updated manager info
        await ref.read(authStateProvider.notifier).refreshProfile();
      } else if (mounted) {
        final errorMessage = ref.read(authStateProvider).errorMessage ?? 'Failed to link email';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(currentManagerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Prismo Inventory Admin'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          // Profile menu
          if (manager != null)
            PopupMenuButton<String>(
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        manager.name.isNotEmpty ? manager.name[0].toUpperCase() : 'M',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      manager.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.7)),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                // Profile header
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manager.name,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (manager.email != null && manager.email!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.email, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              manager.email!,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            manager.phoneNumber,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const Divider(),
                    ],
                  ),
                ),
                // Link Email option (only if no email set)
                if (manager.email == null || manager.email!.isEmpty)
                  PopupMenuItem<String>(
                    value: 'link_email',
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: Color(0xFF0D47A1)),
                        const SizedBox(width: 12),
                        Text('Link Email Account', style: GoogleFonts.inter()),
                      ],
                    ),
                  ),
                // Set/Change Password option
                PopupMenuItem<String>(
                  value: 'set_password',
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 12),
                      Text(
                        manager.email != null && manager.email!.isNotEmpty 
                            ? 'Change Password' 
                            : 'Set Password',
                        style: GoogleFonts.inter(),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                // Logout
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red),
                      const SizedBox(width: 12),
                      Text('Logout', style: GoogleFonts.inter(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'link_email':
                    _showLinkEmailDialog();
                    break;
                  case 'set_password':
                    _showSetPasswordDialog();
                    break;
                  case 'logout':
                    _logout();
                    break;
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading data',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Manager Access Info
            _buildManagerAccessInfo(),
            const SizedBox(height: 24),
            
            // Stats Cards
            _buildStatsSection(),
            const SizedBox(height: 32),
            
            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 32),
            
            // Stores List
            _buildStoresSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerAccessInfo() {
    final manager = ref.watch(currentManagerProvider);
    if (manager == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D47A1).withOpacity(0.15),
            const Color(0xFF1976D2).withOpacity(0.10),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0D47A1).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                manager.isAdmin ? Icons.admin_panel_settings : Icons.store,
                color: const Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${manager.name}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    manager.isAdmin 
                        ? 'Admin Access - All stores visible'
                        : 'Store Access: ${_filteredStores.length} store(s)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: manager.isAdmin ? Colors.purple.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                manager.role.replaceAll('_', ' '),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: manager.isAdmin ? Colors.purple : Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Medicines',
                '${_stats?['totalMedicines'] ?? 0}',
                Icons.medication,
                const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Inventory Records',
                '${_stats?['totalInventory'] ?? 0}',
                Icons.inventory,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Your Stores',
                '${_filteredStores.length}',
                Icons.store,
                const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Upload Inventory',
                'Import Excel sheet to update store inventory',
                Icons.upload_file,
                const Color(0xFF0D47A1),
                () => _navigateToUpload(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'View Inventory',
                'Browse and manage store inventory',
                Icons.visibility,
                const Color(0xFF388E3C),
                () => _showStoreSelector(false),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Remove Items',
                'Remove items from store inventory',
                Icons.remove_circle_outline,
                const Color(0xFF00897B), // Teal - less aggressive
                () => _navigateToBulkDelete(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Stores',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: _filteredStores.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No stores assigned to you',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Contact an admin to get store access',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3), // Store - takes more space
                      1: FixedColumnWidth(80), // Status
                      2: FixedColumnWidth(70), // Total
                      3: FixedColumnWidth(70), // Active
                      4: FixedColumnWidth(70), // Expired
                      5: FixedColumnWidth(90), // Low Stock
                      6: FixedColumnWidth(100), // Actions
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      // Header Row
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        children: [
                          _tableHeader('Store'),
                          _tableHeader('Status'),
                          _tableHeader('Total', center: true),
                          _tableHeader('Active', center: true),
                          _tableHeader('Expired', center: true),
                          _tableHeader('Low Stock', center: true),
                          _tableHeader('Actions', center: true),
                        ],
                      ),
                      // Data Rows
                      ..._filteredStores.map((store) => TableRow(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        children: [
                          // Store cell
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: store.isActive
                                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                                      : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.store,
                                    size: 18,
                                    color: store.isActive ? const Color(0xFF4CAF50) : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(store.name, style: GoogleFonts.inter(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                      Text(
                                        store.address ?? store.id,
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status cell
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: store.isActive
                                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                store.isActive ? 'Active' : 'Inactive',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: store.isActive ? const Color(0xFF4CAF50) : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          // Total cell
                          Center(
                            child: Text(
                              '${store.totalMedicines}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E)),
                            ),
                          ),
                          // Active cell
                          Center(
                            child: Text(
                              '${store.activeMedicines}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50)),
                            ),
                          ),
                          // Expired cell
                          Center(
                            child: Text(
                              '${store.expiredMedicines}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: store.expiredMedicines > 0 ? Colors.red : Colors.grey,
                              ),
                            ),
                          ),
                          // Low Stock cell
                          Center(
                            child: Text(
                              '${store.lowStock}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: store.lowStock > 0 ? Colors.orange : Colors.grey,
                              ),
                            ),
                          ),
                          // Actions cell
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.upload_file, size: 20),
                                onPressed: () => _navigateToUpload(preselectedStore: store),
                                tooltip: 'Upload Inventory',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 20),
                                onPressed: () => _navigateToInventoryView(store),
                                tooltip: 'View Inventory',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tableHeader(String text, {bool center = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: center
          ? Center(child: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)))
          : Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  void _navigateToUpload({Store? preselectedStore}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadScreen(
          stores: _filteredStores,
          preselectedStore: preselectedStore,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToBulkDelete({Store? preselectedStore}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkDeleteScreen(
          stores: _filteredStores,
          preselectedStore: preselectedStore,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToInventoryView(Store store) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryViewScreen(store: store),
      ),
    );
  }

  void _showStoreSelector(bool forUpload) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Store',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 400,
          child: _filteredStores.isEmpty
              ? const Text('No stores available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredStores.length,
                  itemBuilder: (context, index) {
                    final store = _filteredStores[index];
                    return ListTile(
                      leading: const Icon(Icons.store),
                      title: Text(store.name),
                      subtitle: Text(store.id),
                      onTap: () {
                        Navigator.pop(context);
                        if (forUpload) {
                          _navigateToUpload(preselectedStore: store);
                        } else {
                          _navigateToInventoryView(store);
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
