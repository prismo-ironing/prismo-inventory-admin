import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/inventory_item.dart';
import '../services/excel_parser.dart';
import '../services/inventory_service.dart';

class UploadScreen extends StatefulWidget {
  final List<Store> stores;
  final Store? preselectedStore;

  const UploadScreen({
    super.key,
    required this.stores,
    this.preselectedStore,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  Store? _selectedStore;
  List<InventoryItem>? _parsedItems;
  String? _fileName;
  bool _isLoading = false;
  bool _isUploading = false;
  UploadResponse? _uploadResponse;
  String? _error;

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
        _uploadResponse = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          _fileName = file.name;
          
          // Parse Excel
          final items = ExcelParser.parseExcel(file.bytes!);
          
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

  Future<void> _uploadInventory() async {
    if (_selectedStore == null || _parsedItems == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final response = await InventoryService.uploadInventory(
        _selectedStore!.id,
        _parsedItems!,
      );

      setState(() {
        _uploadResponse = response;
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Upload failed: $e';
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Upload Inventory'),
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
            // Step 1: Select Store
            _buildStepCard(
              step: 1,
              title: 'Select Store',
              subtitle: 'Choose the store for inventory update',
              icon: Icons.store,
              isCompleted: _selectedStore != null,
              child: _buildStoreSelector(),
            ),
            const SizedBox(height: 24),

            // Step 2: Upload File
            _buildStepCard(
              step: 2,
              title: 'Upload Excel File',
              subtitle: 'Select the inventory Excel sheet',
              icon: Icons.upload_file,
              isCompleted: _parsedItems != null,
              child: _buildFileUploader(),
            ),
            const SizedBox(height: 24),

            // Step 3: Preview
            if (_parsedItems != null) ...[
              _buildStepCard(
                step: 3,
                title: 'Preview Data',
                subtitle: '${_parsedItems!.length} items found',
                icon: Icons.preview,
                isCompleted: _parsedItems != null,
                child: _buildPreviewTable(),
              ),
              const SizedBox(height: 24),
            ],

            // Step 4: Upload
            if (_parsedItems != null && _selectedStore != null) ...[
              _buildStepCard(
                step: 4,
                title: 'Confirm Upload',
                subtitle: 'Upload inventory to ${_selectedStore!.name}',
                icon: Icons.cloud_upload,
                isCompleted: _uploadResponse != null && _uploadResponse!.success,
                child: _buildUploadSection(),
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

            // Upload response
            if (_uploadResponse != null) ...[
              const SizedBox(height: 24),
              _buildUploadResponse(),
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
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF0D47A1).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            '$step',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D47A1),
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
                    Icons.cloud_upload_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _fileName ?? 'Click to select Excel file',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supports .xlsx and .xls files',
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
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
              columns: const [
                DataColumn(label: Text('S.No')),
                DataColumn(label: Text('Product Name')),
                DataColumn(label: Text('Composition')),
                DataColumn(label: Text('Company')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Pack Size')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('MRP')),
                DataColumn(label: Text('Selling Price')),
                DataColumn(label: Text('Rx')),
              ],
              rows: _parsedItems!.take(10).map((item) {
                return DataRow(cells: [
                  DataCell(Text('${item.serialNo ?? ''}')),
                  DataCell(
                    SizedBox(
                      width: 200,
                      child: Text(
                        item.productName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 150,
                      child: Text(
                        item.composition ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(item.company ?? '')),
                  DataCell(Text(item.category ?? '')),
                  DataCell(Text(item.packSize ?? '')),
                  DataCell(Text('${item.inventoryQty}')),
                  DataCell(Text(item.inventoryType ?? '')),
                  DataCell(Text('₹${item.mrp?.toStringAsFixed(2) ?? '-'}')),
                  DataCell(Text('₹${item.sellingPrice.toStringAsFixed(2)}')),
                  DataCell(Text(item.prescriptionInfo ?? '')),
                ]);
              }).toList(),
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

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to upload',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_parsedItems!.length} items will be uploaded to ${_selectedStore!.name}',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _uploadInventory,
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload),
            label: Text(_isUploading ? 'Uploading...' : 'Upload Inventory'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadResponse() {
    final response = _uploadResponse!;
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
                        isSuccess ? 'Upload Successful!' : 'Upload Completed with Issues',
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
                _buildResultChip('New Medicines', '${response.newMedicinesAdded}', Colors.blue),
                _buildResultChip('Updated Medicines', '${response.existingMedicinesUpdated}', Colors.teal),
                _buildResultChip('Inventory Created', '${response.inventoryItemsCreated}', Colors.green),
                _buildResultChip('Inventory Updated', '${response.inventoryItemsUpdated}', Colors.orange),
                if (response.failedItems > 0)
                  _buildResultChip('Failed', '${response.failedItems}', Colors.red),
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
                      '• ${error.productName ?? 'Item ${error.serialNo}'}: ${error.errorMessage}',
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
              color: color.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: color.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

extension ColorShade on Color {
  Color get shade700 {
    return HSLColor.fromColor(this).withLightness(0.35).toColor();
  }

  Color get shade600 {
    return HSLColor.fromColor(this).withLightness(0.45).toColor();
  }
}

