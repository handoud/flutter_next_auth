import 'package:flutter/material.dart';
import 'package:flutter_next_auth/flutter_next_auth.dart';

/// Example demonstrating dynamic role-based access control
///
/// This example shows how to use the new role checking features
/// introduced in version 1.2.1
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await flutternext.initialize(
    baseUrl: 'https://your-erp-server.com',
  );

  runApp(const RoleBasedApp());
}

class RoleBasedApp extends StatelessWidget {
  const RoleBasedApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Role-Based Access Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<String> _userRoles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRoles();
  }

  Future<void> _loadUserRoles() async {
    setState(() => _isLoading = true);

    // Fetch user roles from server
    final roles = await flutternext.role.getUserRoles();

    setState(() {
      _userRoles = roles;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadUserRoles(),
            tooltip: 'Refresh Roles',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUserRolesCard(),
          const SizedBox(height: 16),
          _buildModuleAccessCards(),
        ],
      ),
    );
  }

  Widget _buildUserRolesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Roles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_userRoles.isEmpty)
              const Text('No roles assigned')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _userRoles.map((role) => Chip(label: Text(role))).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleAccessCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Module Access',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildStockModuleCard(),
        const SizedBox(height: 8),
        _buildHRModuleCard(),
        const SizedBox(height: 8),
        _buildSalesModuleCard(),
        const SizedBox(height: 8),
        _buildAccountsModuleCard(),
        const SizedBox(height: 8),
        _buildAdminModuleCard(),
      ],
    );
  }

  Widget _buildStockModuleCard() {
    return FutureBuilder<bool>(
      future: flutternext.role
          .hasAnyRole(['Stock Manager', 'Stock User', 'System Manager']),
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;
        return _buildAccessCard(
          title: 'Stock Management',
          icon: Icons.inventory,
          hasAccess: hasAccess,
          onTap: hasAccess
              ? () => _navigateToModule(context, 'Stock Management')
              : null,
        );
      },
    );
  }

  Widget _buildHRModuleCard() {
    return FutureBuilder<bool>(
      future: flutternext.role
          .hasAnyRole(['HR Manager', 'HR User', 'System Manager']),
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;
        return _buildAccessCard(
          title: 'Human Resources',
          icon: Icons.people,
          hasAccess: hasAccess,
          onTap: hasAccess
              ? () => _navigateToModule(context, 'Human Resources')
              : null,
        );
      },
    );
  }

  Widget _buildSalesModuleCard() {
    return FutureBuilder<bool>(
      future: flutternext.role
          .hasAnyRole(['Sales Manager', 'Sales User', 'System Manager']),
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;
        return _buildAccessCard(
          title: 'Sales',
          icon: Icons.point_of_sale,
          hasAccess: hasAccess,
          onTap: hasAccess ? () => _navigateToModule(context, 'Sales') : null,
        );
      },
    );
  }

  Widget _buildAccountsModuleCard() {
    return FutureBuilder<bool>(
      future: flutternext.role
          .hasAnyRole(['Accounts Manager', 'Accounts User', 'System Manager']),
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;
        return _buildAccessCard(
          title: 'Accounts',
          icon: Icons.account_balance,
          hasAccess: hasAccess,
          onTap:
              hasAccess ? () => _navigateToModule(context, 'Accounts') : null,
        );
      },
    );
  }

  Widget _buildAdminModuleCard() {
    return FutureBuilder<bool>(
      future: flutternext.role.hasRole('System Manager'),
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;
        return _buildAccessCard(
          title: 'System Administration',
          icon: Icons.admin_panel_settings,
          hasAccess: hasAccess,
          onTap: hasAccess
              ? () => _navigateToModule(context, 'System Administration')
              : null,
        );
      },
    );
  }

  Widget _buildAccessCard({
    required String title,
    required IconData icon,
    required bool hasAccess,
    VoidCallback? onTap,
  }) {
    return Card(
      color: hasAccess ? Colors.blue.shade50 : Colors.grey.shade200,
      child: ListTile(
        leading: Icon(
          icon,
          color: hasAccess ? Colors.blue : Colors.grey,
        ),
        title: Text(title),
        trailing: Icon(
          hasAccess ? Icons.check_circle : Icons.lock,
          color: hasAccess ? Colors.green : Colors.grey,
        ),
        enabled: hasAccess,
        onTap: onTap,
      ),
    );
  }

  void _navigateToModule(BuildContext context, String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening $moduleName...')),
    );
    // Navigate to actual module screen here
  }
}

/// Example of checking roles for specific features
class FeatureGuard extends StatelessWidget {
  final String requiredRole;
  final Widget child;
  final Widget? fallback;

  const FeatureGuard({
    Key? key,
    required this.requiredRole,
    required this.child,
    this.fallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: flutternext.role.hasRole(requiredRole),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final hasRole = snapshot.data ?? false;

        if (hasRole) {
          return child;
        }

        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Example usage of FeatureGuard
class ExampleFeatureGuardUsage extends StatelessWidget {
  const ExampleFeatureGuardUsage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feature Guard Example')),
      body: Column(
        children: [
          // Only show delete button to Stock Managers
          FeatureGuard(
            requiredRole: 'Stock Manager',
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.delete),
              label: const Text('Delete Item'),
            ),
            fallback: const Text('You need Stock Manager role'),
          ),

          // Only show reports to managers
          FeatureGuard(
            requiredRole: 'Sales Manager',
            child: Card(
              child: ListTile(
                title: const Text('Sales Reports'),
                leading: const Icon(Icons.analytics),
                onTap: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Example of checking multiple roles
Future<void> exampleMultipleRoleChecks() async {
  // Check if user can access stock module
  final canAccessStock = await flutternext.role.hasAnyRole([
    'Stock Manager',
    'Stock User',
    'System Manager',
  ]);

  if (canAccessStock) {
    print('User can access stock module');
  }

  // Check if user has full management access
  final hasFullManagementAccess = await flutternext.role.hasAllRoles([
    'Stock Manager',
    'Sales Manager',
    'Accounts Manager',
  ]);

  if (hasFullManagementAccess) {
    print('User has full management access across modules');
  }

  // Get all user roles
  final roles = await flutternext.role.getUserRoles();
  print('User roles: $roles');

  // Check specific role with forced refresh
  final isSystemManager = await flutternext.role.hasRole(
    'System Manager',
    refresh: true, // Force fetch from server
  );

  if (isSystemManager) {
    print('User is a System Manager');
  }
}
