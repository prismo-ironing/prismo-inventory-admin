import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/inventory_item.dart';
import '../models/pharmacy_invoice.dart';
import '../services/invoice_service.dart';

class InvoiceManagementScreen extends ConsumerStatefulWidget {
  final List<Store> stores;
  final Store? preselectedStore;

  const InvoiceManagementScreen({
    super.key,
    required this.stores,
    this.preselectedStore,
  });

  @override
  ConsumerState<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends ConsumerState<InvoiceManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Store? _selectedStore;
  bool _isLoading = false;
  String? _error;
  
  // Tab 1: Pending invoices (orders needing invoices)
  List<OrderForInvoice> _pendingOrders = [];
  
  // Tab 2: Uploaded invoices
  List<PharmacyInvoice> _uploadedInvoices = [];
  
  // Upload state
  bool _isUploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedStore = widget.preselectedStore ?? (widget.stores.isNotEmpty ? widget.stores.first : null);
    if (_selectedStore != null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Pagination state
  int _currentPage = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  bool _hasNextPage = false;
  
  // Orders with invoice status (from optimized endpoint)
  List<OrderForInvoice> _allOrders = [];

  Future<void> _loadData({int page = 0}) async {
    if (_selectedStore == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 🚀 Use OPTIMIZED endpoint - single API call instead of N+1
      // Old way: 1 call for orders + N calls for invoice checks = 31+ calls
      // New way: 1 call with all data = 1 call total!
      final response = await InvoiceService.getOrdersWithInvoiceStatus(
        _selectedStore!.id,
        page: page,
        size: 50, // Fetch 50 at a time
        filter: 'all', // Get both pending and uploaded
      );

      // Separate into pending and uploaded
      final pendingOrders = response.orders.where((o) => !o.hasInvoice).toList();
      final uploadedOrders = response.orders.where((o) => o.hasInvoice).toList();

      setState(() {
        _allOrders = response.orders;
        _pendingOrders = pendingOrders;
        // Convert uploaded orders to PharmacyInvoice for compatibility
        _uploadedInvoices = uploadedOrders.map((o) => PharmacyInvoice(
          id: o.invoiceNumber ?? '',
          orderId: o.orderId,
          vendorId: _selectedStore!.id,
          pharmacyInvoiceNumber: o.invoiceNumber,
          invoiceImageUrl: o.invoiceImageUrl,
          createdAt: o.invoiceUploadedAt ?? o.createdAt,
        )).toList();
        
        // Pagination
        _currentPage = response.page;
        _totalPages = response.totalPages;
        _totalElements = response.totalElements;
        _hasNextPage = response.hasNext;
        
        _isLoading = false;
      });
      
      print('📊 Loaded ${response.orders.length} orders (pending: ${pendingOrders.length}, uploaded: ${uploadedOrders.length})');
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadNextPage() async {
    if (!_hasNextPage || _isLoading) return;
    await _loadData(page: _currentPage + 1);
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
              child: const Icon(Icons.receipt_long, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Invoice Management'),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending_actions),
                  const SizedBox(width: 8),
                  Text('Pending (${_pendingOrders.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle),
                  const SizedBox(width: 8),
                  Text('Uploaded (${_uploadedInvoices.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Store selector
          _buildStoreSelector(),
          
          // Content
          Expanded(
            child: _selectedStore == null
                ? _buildNoStoreSelected()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildError()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildPendingTab(),
                              _buildUploadedTab(),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Store:',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<Store>(
              value: _selectedStore,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              items: widget.stores.map((store) {
                return DropdownMenuItem<Store>(
                  value: store,
                  child: Row(
                    children: [
                      Icon(
                        Icons.store,
                        size: 20,
                        color: store.isActive ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(store.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (store) {
                setState(() {
                  _selectedStore = store;
                });
                _loadData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStoreSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Select a store to manage invoices',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
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
          Text(_error ?? '', style: TextStyle(color: Colors.grey.shade600)),
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

  Widget _buildPendingTab() {
    if (_pendingOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              'All invoices uploaded!',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No pending orders require invoice upload',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingOrders.length,
      itemBuilder: (context, index) {
        final order = _pendingOrders[index];
        return _buildPendingOrderCard(order);
      },
    );
  }

  Widget _buildPendingOrderCard(OrderForInvoice order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.orderId.substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${order.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: const Color(0xFF0D47A1),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Invoice Pending',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  order.customerName ?? 'Customer',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.status.replaceAll('_', ' '),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showUploadDialog(order),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload Invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadedTab() {
    if (_uploadedInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No invoices uploaded yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload invoices from the Pending tab',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _uploadedInvoices.length,
      itemBuilder: (context, index) {
        final invoice = _uploadedInvoices[index];
        return _buildUploadedInvoiceCard(invoice);
      },
    );
  }

  Widget _buildUploadedInvoiceCard(PharmacyInvoice invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${invoice.orderId.substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (invoice.pharmacyInvoiceNumber != null)
                        Text(
                          'Invoice: ${invoice.pharmacyInvoiceNumber}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (invoice.pharmacyInvoiceAmount != null)
                  Text(
                    '₹${invoice.pharmacyInvoiceAmount!.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: const Color(0xFF0D47A1),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Uploaded: ${DateFormat('dd MMM yyyy').format(invoice.createdAt)}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                if (invoice.invoiceImageUrl != null)
                  TextButton.icon(
                    onPressed: () => _viewInvoiceImage(invoice),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog(OrderForInvoice order) {
    final invoiceNumberController = TextEditingController();
    final invoiceAmountController = TextEditingController(
      text: order.totalAmount.toStringAsFixed(2),
    );
    DateTime? selectedDate = order.createdAt;
    Uint8List? selectedFileBytes;
    String? selectedFileName;      // Display name (with size)
    String? originalFileName;      // Original name (for upload/validation)

    showDialog(
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
                child: const Icon(Icons.upload_file, color: Color(0xFF0D47A1)),
              ),
              const SizedBox(width: 12),
              Text(
                'Upload Invoice',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Order #${order.orderId.substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          '₹${order.totalAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D47A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // File picker
                  Text(
                    'Invoice Image *',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,  // Only images, no PDFs
                        withData: true,
                      );
                      if (result != null && result.files.single.bytes != null) {
                        final bytes = result.files.single.bytes!;
                        final name = result.files.single.name;
                        
                        // Validate file size (max 5MB - same as vendor documents)
                        final validationError = InvoiceService.validateInvoiceFile(bytes, name);
                        if (validationError != null) {
                          setDialogState(() {
                            _uploadError = validationError;
                            selectedFileBytes = null;
                            selectedFileName = null;
                            originalFileName = null;
                          });
                          return;
                        }
                        
                        setDialogState(() {
                          selectedFileBytes = bytes;
                          originalFileName = name;  // Keep original for upload
                          selectedFileName = '$name (${_formatFileSize(bytes.length)})';  // Display with size
                          _uploadError = null;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedFileName != null
                              ? Colors.green
                              : Colors.grey.shade300,
                          width: selectedFileName != null ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: selectedFileName != null
                            ? Colors.green.withOpacity(0.05)
                            : Colors.grey.shade50,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selectedFileName != null
                                ? Icons.check_circle
                                : Icons.cloud_upload_outlined,
                            color: selectedFileName != null
                                ? Colors.green
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              selectedFileName ?? 'Click to select image',
                              style: GoogleFonts.inter(
                                color: selectedFileName != null
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Invoice number - REQUIRED for GST compliance
                  Text(
                    'Invoice Number *',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: invoiceNumberController,
                    decoration: InputDecoration(
                      hintText: 'e.g., MAC-INV-2024-001',
                      helperText: 'From pharmacy billing software (Marg/Mac/etc)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Invoice amount - auto-filled from order, editable
                  Text(
                    'Invoice Amount',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: invoiceAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      helperText: 'Pre-filled from order total',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Invoice date - defaults to order date
                  Text(
                    'Invoice Date',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            selectedDate != null
                                ? DateFormat('dd MMM yyyy').format(selectedDate!)
                                : 'Select date',
                            style: GoogleFonts.inter(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_uploadError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, size: 20, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _uploadError!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isUploading ? null : () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: _isUploading || selectedFileBytes == null || invoiceNumberController.text.isEmpty
                  ? null
                  : () async {
                      setDialogState(() {
                        _isUploading = true;
                        _uploadError = null;
                      });

                      try {
                        // Use GCS signed URL upload (like prescriptions/documents)
                        // This avoids multipart file size limits
                        final result = await InvoiceService.uploadInvoiceWithGcs(
                          orderId: order.orderId,
                          vendorId: _selectedStore!.id,
                          fileBytes: selectedFileBytes!,
                          fileName: originalFileName!,  // Use original name (not display name with size)
                          invoiceNumber: invoiceNumberController.text.trim(),  // REQUIRED
                          invoiceDate: selectedDate,
                          invoiceAmount: double.tryParse(invoiceAmountController.text),
                        );

                        if (result.success) {
                          Navigator.pop(context);
                          // Reset state after dialog closes using parent's setState
                          setState(() {
                            _isUploading = false;
                            _uploadError = null;
                          });
                          _loadData();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Invoice uploaded successfully!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          setDialogState(() {
                            _uploadError = result.error ?? 'Upload failed';
                          });
                          setState(() {
                            _isUploading = false;
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          _uploadError = 'Error: $e';
                        });
                        setState(() {
                          _isUploading = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewInvoiceImage(PharmacyInvoice invoice) {
    if (invoice.invoiceImageUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Invoice #${invoice.pharmacyInvoiceNumber ?? invoice.orderId.substring(0, 8)}'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () {
                    // Open in new tab (web)
                  },
                ),
              ],
            ),
            Flexible(
              child: Image.network(
                invoice.invoiceImageUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('Failed to load image'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
    }
  }
}

