import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/inventory_service.dart';
import '../models/inventory_item.dart';
import 'upload_screen.dart';
import 'inventory_view_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<Store> _stores = [];
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stores = await InventoryService.getStores();
      final stats = await InventoryService.getStats();
      
      setState(() {
        _stores = stores;
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

  @override
  Widget build(BuildContext context) {
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
                'Active Stores',
                '${_stats?['totalStores'] ?? 0}',
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
          'Stores',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: _stores.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No stores found',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey.shade600,
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
                      ..._stores.map((store) => TableRow(
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
          stores: _stores,
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
          child: _stores.isEmpty
              ? const Text('No stores available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _stores.length,
                  itemBuilder: (context, index) {
                    final store = _stores[index];
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

