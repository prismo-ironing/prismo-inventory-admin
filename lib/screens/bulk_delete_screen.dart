import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/inventory_item.dart';
import '../services/excel_parser.dart';
import '../services/csv_parser.dart';
import '../services/inventory_service.dart';

class BulkDeleteScreen extends StatefulWidget {
  final List<Store> stores;
  final Store? preselectedStore;

  const BulkDeleteScreen({
    super.key,
    required this.stores,
    this.preselectedStore,
  });

  @override
  State<BulkDeleteScreen> createState() => _BulkDeleteScreenState();
}

class _BulkDeleteScreenState extends State<BulkDeleteScreen> {
  Store? _selectedStore;
  List<InventoryItem>? _parsedItems; // Use InventoryItem like upload screen
  String? _fileName;
  bool _isLoading = false;
  bool _isDeleting = false;
  BulkDeleteResponse? _deleteResponse;
  String? _error;

  // Progress tracking
  int _processedItems = 0;
  int _totalItems = 0;
  int _currentBatch = 0;
  int _totalBatches = 0;

  @override
  void initState() {
    super.initState();
    _selectedStore = widget.preselectedStore;
  }

  Future<void> _pickFile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _parsedItems = null;
        _deleteResponse = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          _fileName = file.name;

          // Use same parsers as upload screen for full preview
          List<InventoryItem> items;
          final extension = file.name.toLowerCase().split('.').last;

          if (extension == 'csv') {
            items = CsvParser.parseCsv(file.bytes!);
          } else {
            items = ExcelParser.parseExcel(file.bytes!);
          }

          setState(() {
            _parsedItems = items;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error parsing file: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedStore == null || _parsedItems == null) return;

    setState(() {
      _isDeleting = true;
      _error = null;
      _processedItems = 0;
      _totalItems = _parsedItems!.length;
      _currentBatch = 0;
      _totalBatches = (_parsedItems!.length / 500).ceil();
    });

    try {
      // Convert InventoryItem to DeleteItem for the API
      final deleteItems = _parsedItems!
          .map((item) => DeleteItem(productName: item.productName))
          .toList();

      final response = await InventoryService.bulkDeleteInventory(
        _selectedStore!.id,
        deleteItems,
        onProgress: (completed, total, currentBatch, totalBatches) {
          if (mounted) {
            setState(() {
              _processedItems = completed;
              _totalItems = total;
              _currentBatch = currentBatch;
              _totalBatches = totalBatches;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _deleteResponse = response;
          _isDeleting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Bulk delete failed: $e';
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Remove from Inventory'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner - less dramatic
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remove Items from Store Inventory',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This removes items from the selected store\'s inventory only. The medicines remain in the global catalog for other stores.',
                          style: TextStyle(color: Colors.amber.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Step 1: Select Store
            _buildStepCard(
              step: 1,
              title: 'Select Store',
              subtitle: 'Choose the store to delete inventory from',
              icon: Icons.store,
              isCompleted: _selectedStore != null,
              child: _buildStoreSelector(),
            ),
            const SizedBox(height: 24),

            // Step 2: Upload File
            _buildStepCard(
              step: 2,
              title: 'Upload Delete List',
              subtitle: 'Select Excel/CSV file with items to delete',
              icon: Icons.upload_file,
              isCompleted: _parsedItems != null,
              child: _buildFileUploader(),
            ),
            const SizedBox(height: 24),

            // Step 3: Preview
            if (_parsedItems != null) ...[
              _buildStepCard(
                step: 3,
                title: 'Preview Items to Delete',
                subtitle: '${_parsedItems!.length} items will be deleted',
                icon: Icons.preview,
                isCompleted: _parsedItems != null,
                child: _buildPreviewTable(),
              ),
              const SizedBox(height: 24),
            ],

            // Step 4: Confirm Delete
            if (_parsedItems != null && _selectedStore != null) ...[
              _buildStepCard(
                step: 4,
                title: 'Confirm Bulk Delete',
                subtitle: 'Delete ${_parsedItems!.length} items from ${_selectedStore!.name}',
                icon: Icons.delete_forever,
                isCompleted: _deleteResponse != null && _deleteResponse!.success,
                child: _buildDeleteSection(),
              ),
            ],

            // Error message
            if (_error != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Delete response
            if (_deleteResponse != null) ...[
              const SizedBox(height: 24),
              _buildDeleteResponse(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required Widget child,
  }) {
    // Use professional teal color instead of aggressive red
    const primaryColor = Color(0xFF00897B); // Teal
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? primaryColor
                        : primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            '$step',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
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
                Icon(icon, color: Colors.grey.shade400, size: 28),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStoreSelector() {
    return DropdownButtonFormField<Store>(
      value: _selectedStore,
      decoration: InputDecoration(
        labelText: 'Select Store',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: const Icon(Icons.store),
      ),
      items: widget.stores.map((store) {
        return DropdownMenuItem(
          value: store,
          child: Text('${store.name} (${store.id})'),
        );
      }).toList(),
      onChanged: (store) {
        setState(() {
          _selectedStore = store;
        });
      },
    );
  }

  Widget _buildFileUploader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isLoading ? null : _pickFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Column(
              children: [
                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  Icon(
                    Icons.upload_file,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _fileName ?? 'Click to select file',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supports .xlsx, .xls and .csv files',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File Format:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Use the same file format as inventory upload. Items will be matched by "Product Name" column.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTable() {
    if (_parsedItems == null || _parsedItems!.isEmpty) {
      return const Text('No items to preview');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FixedColumnWidth(35),   // S.No
                1: FlexColumnWidth(2),      // Product Name
                2: FlexColumnWidth(1.5),    // Composition
                3: FlexColumnWidth(1.5),    // Company
                4: FlexColumnWidth(1),      // Category
                5: FixedColumnWidth(50),    // Qty
                6: FixedColumnWidth(55),    // MRP
                7: FixedColumnWidth(55),    // Price
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                // Header row
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    _tableHeader('#'),
                    _tableHeader('Product Name'),
                    _tableHeader('Composition'),
                    _tableHeader('Company'),
                    _tableHeader('Category'),
                    _tableHeader('Qty'),
                    _tableHeader('MRP'),
                    _tableHeader('Price'),
                  ],
                ),
                // Data rows
                ..._parsedItems!.take(10).map((item) {
                  return TableRow(
                    children: [
                      _tableCell('${item.serialNo ?? ''}'),
                      _tableCellBold(item.productName),
                      _tableCell(item.composition ?? '-'),
                      _tableCell(item.company ?? '-'),
                      _tableCell(item.category ?? '-'),
                      _tableCell('${item.inventoryQty}'),
                      _tableCell('₹${item.mrp?.toStringAsFixed(0) ?? '-'}'),
                      _tableCell('₹${item.sellingPrice.toStringAsFixed(0)}'),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        if (_parsedItems!.length > 10) ...[
          const SizedBox(height: 8),
          Text(
            'Showing first 10 of ${_parsedItems!.length} items',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeleteSection() {
    if (_deleteResponse != null && _deleteResponse!.success) {
      return _buildSuccessState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_deleteResponse == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.teal.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to remove from inventory',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_parsedItems!.length} items will be removed from ${_selectedStore!.name}\'s inventory',
                        style: TextStyle(color: Colors.teal.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (_deleteResponse == null) const SizedBox(height: 20),

        // Progress indicator when deleting
        if (_isDeleting) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Processing batch $_currentBatch of $_totalBatches...',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_processedItems / $_totalItems items processed',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _totalItems > 0 ? _processedItems / _totalItems : 0,
                  backgroundColor: Colors.blue.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                ),
              ],
            ),
          ),
        ] else if (_deleteResponse == null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _bulkDelete,
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Remove from Inventory'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF00897B), // Teal
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessState() {
    final response = _deleteResponse!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 2),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade200,
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Items Removed Successfully',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            response.message,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.green.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn('Removed', response.successfulDeletes, Icons.check_circle_outline, Colors.green),
              _buildStatColumn('Not Found', response.notFoundItems, Icons.search_off, Colors.orange),
              _buildStatColumn('Failed', response.failedDeletes, Icons.error_outline, Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _deleteResponse = null;
                      _parsedItems = null;
                      _fileName = null;
                    });
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Remove More'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: Colors.teal.shade700,
                    side: BorderSide(color: Colors.teal.shade300),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Inventory'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteResponse() {
    final response = _deleteResponse!;
    final isSuccess = response.success;

    return Card(
      color: isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.warning,
                  color: isSuccess ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSuccess ? 'Items Removed' : 'Completed with Issues',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isSuccess ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        response.message,
                        style: TextStyle(
                          color: isSuccess ? Colors.green.shade600 : Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildResultChip('Total Items', '${response.totalItems}', Colors.grey),
                _buildResultChip('Deleted', '${response.successfulDeletes}', Colors.green),
                _buildResultChip('Not Found', '${response.notFoundItems}', Colors.orange),
                if (response.failedDeletes > 0)
                  _buildResultChip('Failed', '${response.failedDeletes}', Colors.red),
              ],
            ),
            if (response.errors.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Errors:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...response.errors.take(5).map((error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${error.productName ?? "Unknown"}: ${error.error}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade600,
                      ),
                    ),
                  )),
              if (response.errors.length > 5)
                Text(
                  '... and ${response.errors.length - 5} more errors',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: _getShade700(color),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _getShade600(color),
            ),
          ),
        ],
      ),
    );
  }

  Color _getShade700(Color color) {
    return HSLColor.fromColor(color).withLightness(0.35).toColor();
  }

  Color _getShade600(Color color) {
    return HSLColor.fromColor(color).withLightness(0.45).toColor();
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableCellBold(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Tooltip(
        message: text,
        child: Text(
          text,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

