import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';

class InventoryViewScreen extends StatefulWidget {
  final Store store;

  const InventoryViewScreen({super.key, required this.store});

  @override
  State<InventoryViewScreen> createState() => _InventoryViewScreenState();
}

class _InventoryViewScreenState extends State<InventoryViewScreen> {
  bool _isLoading = true;
  String? _error;
  InventorySummary? _summary;
  List<StoreInventoryItem> _items = [];
  List<StoreInventoryItem> _filteredItems = [];
  String _searchQuery = '';
  String _filterStatus = 'all';
  String _sortBy = 'name';
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await InventoryService.getStoreInventory(widget.store.id);
      setState(() {
        _summary = data['summary'] as InventorySummary;
        _items = data['items'] as List<StoreInventoryItem>;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    var filtered = _items.where((item) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!item.brandName.toLowerCase().contains(query) &&
            !(item.genericName?.toLowerCase().contains(query) ?? false) &&
            !(item.composition?.toLowerCase().contains(query) ?? false) &&
            !item.medicineId.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Status filter
      if (_filterStatus != 'all') {
        if (_filterStatus == 'in_stock' && item.stockQuantity <= 0) return false;
        if (_filterStatus == 'low_stock' && 
            (item.stockQuantity > 10 || item.stockQuantity <= 0)) return false;
        if (_filterStatus == 'out_of_stock' && item.stockQuantity > 0) return false;
      }

      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      int compare = 0;
      switch (_sortBy) {
        case 'name':
          compare = a.brandName.compareTo(b.brandName);
          break;
        case 'stock':
          compare = a.stockQuantity.compareTo(b.stockQuantity);
          break;
        case 'price':
          compare = a.sellingPrice.compareTo(b.sellingPrice);
          break;
        case 'category':
          compare = (a.category ?? '').compareTo(b.category ?? '');
          break;
      }
      return _sortAsc ? compare : -compare;
    });

    _filteredItems = filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.store.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventory,
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
            Text('Loading inventory...'),
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
            Text('Error: $_error'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInventory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary Cards
        _buildSummaryCards(),
        
        // Search and Filter
        _buildSearchAndFilter(),
        
        // Items List
        Expanded(
          child: _buildItemsList(),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Items',
              '${_summary?.totalItems ?? 0}',
              Icons.inventory_2,
              const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'In Stock',
              '${_summary?.inStock ?? 0}',
              Icons.check_circle,
              const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Low Stock',
              '${_summary?.lowStock ?? 0}',
              Icons.warning,
              const Color(0xFFFF9800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Out of Stock',
              '${_summary?.outOfStock ?? 0}',
              Icons.error,
              const Color(0xFFF44336),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Total Value',
              '₹${_formatNumber(_summary?.totalInventoryValue ?? 0)}',
              Icons.currency_rupee,
              const Color(0xFF9C27B0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Search
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Filter by status
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filterStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'in_stock', child: Text('In Stock')),
                DropdownMenuItem(value: 'low_stock', child: Text('Low Stock')),
                DropdownMenuItem(value: 'out_of_stock', child: Text('Out of Stock')),
              ],
              onChanged: (value) {
                setState(() {
                  _filterStatus = value ?? 'all';
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          
          // Sort
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: InputDecoration(
                labelText: 'Sort By',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Name')),
                DropdownMenuItem(value: 'stock', child: Text('Stock')),
                DropdownMenuItem(value: 'price', child: Text('Price')),
                DropdownMenuItem(value: 'category', child: Text('Category')),
              ],
              onChanged: (value) {
                setState(() {
                  _sortBy = value ?? 'name';
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          
          // Sort direction
          IconButton(
            icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _sortAsc = !_sortAsc;
                _applyFilters();
              });
            },
            tooltip: _sortAsc ? 'Ascending' : 'Descending',
          ),
          
          const SizedBox(width: 8),
          
          // Results count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_filteredItems.length} items',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No items found',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Medicine')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Manufacturer')),
              DataColumn(label: Text('Form')),
              DataColumn(label: Text('Pack Size')),
              DataColumn(label: Text('MRP'), numeric: true),
              DataColumn(label: Text('Selling Price'), numeric: true),
              DataColumn(label: Text('Stock'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Last Updated')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _filteredItems.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 250,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.brandName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.genericName != null)
                            Text(
                              item.genericName!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.composition != null)
                            Text(
                              item.composition!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(Text(item.category ?? '-')),
                  DataCell(Text(item.manufacturer ?? '-')),
                  DataCell(Text(item.form ?? '-')),
                  DataCell(Text(item.packSize ?? '-')),
                  DataCell(Text('₹${item.mrp?.toStringAsFixed(2) ?? '-'}')),
                  DataCell(Text('₹${item.sellingPrice.toStringAsFixed(2)}')),
                  DataCell(
                    Text(
                      '${item.stockQuantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _getStockColor(item.stockQuantity),
                      ),
                    ),
                  ),
                  DataCell(_buildStatusBadge(item.availabilityStatus)),
                  DataCell(
                    Text(
                      _formatDate(item.lastUpdatedAt),
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showEditDialog(item),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, size: 18, color: Colors.red.shade400),
                          onPressed: () => _confirmDelete(item),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    
    switch (status.toUpperCase()) {
      case 'IN_STOCK':
        color = const Color(0xFF4CAF50);
        label = 'In Stock';
        break;
      case 'LOW_STOCK':
        color = const Color(0xFFFF9800);
        label = 'Low Stock';
        break;
      case 'OUT_OF_STOCK':
        color = const Color(0xFFF44336);
        label = 'Out of Stock';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getStockColor(int quantity) {
    if (quantity <= 0) return const Color(0xFFF44336);
    if (quantity <= 10) return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatNumber(double number) {
    if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(2)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }

  void _showEditDialog(StoreInventoryItem item) {
    final stockController = TextEditingController(text: '${item.stockQuantity}');
    final priceController = TextEditingController(text: '${item.sellingPrice}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.brandName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stockController,
              decoration: const InputDecoration(
                labelText: 'Stock Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Selling Price',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement update API call
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Update functionality coming soon')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(StoreInventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${item.brandName} from inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await InventoryService.deleteInventoryItem(
                widget.store.id,
                item.medicineId,
              );
              if (success) {
                _loadInventory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item deleted successfully')),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete item')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

