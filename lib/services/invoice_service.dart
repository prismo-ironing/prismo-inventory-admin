import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/pharmacy_invoice.dart';

// File size limits (same as vendor documents)
const int maxInvoiceFileSizeBytes = 5 * 1024 * 1024; // 5MB
const int maxInvoiceFileSizeMB = 5;

/// Response from the optimized orders-with-invoice-status endpoint
class OrdersWithInvoiceResponse {
  final List<OrderForInvoice> orders;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
  final int pendingCount;
  final int uploadedCount;

  OrdersWithInvoiceResponse({
    required this.orders,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
    required this.pendingCount,
    required this.uploadedCount,
  });

  factory OrdersWithInvoiceResponse.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] ?? {};
    final summary = json['summary'] ?? {};
    final ordersJson = json['orders'] as List<dynamic>? ?? [];

    return OrdersWithInvoiceResponse(
      orders: ordersJson.map((o) => OrderForInvoice.fromOptimizedJson(o)).toList(),
      page: pagination['page'] ?? 0,
      size: pagination['size'] ?? 20,
      totalElements: pagination['totalElements'] ?? 0,
      totalPages: pagination['totalPages'] ?? 0,
      hasNext: pagination['hasNext'] ?? false,
      hasPrevious: pagination['hasPrevious'] ?? false,
      pendingCount: summary['pending'] ?? 0,
      uploadedCount: summary['uploaded'] ?? 0,
    );
  }

  factory OrdersWithInvoiceResponse.empty() {
    return OrdersWithInvoiceResponse(
      orders: [],
      page: 0,
      size: 20,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
      hasPrevious: false,
      pendingCount: 0,
      uploadedCount: 0,
    );
  }
}

/// Invoice summary counts
class InvoiceSummary {
  final int totalEligibleOrders;
  final int uploadedInvoices;
  final int pendingInvoices;

  InvoiceSummary({
    required this.totalEligibleOrders,
    required this.uploadedInvoices,
    required this.pendingInvoices,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceSummary(
      totalEligibleOrders: json['totalEligibleOrders'] ?? 0,
      uploadedInvoices: json['uploadedInvoices'] ?? 0,
      pendingInvoices: json['pendingInvoices'] ?? 0,
    );
  }
}

class InvoiceService {
  static const Duration _timeout = Duration(seconds: 30);

  // ===== OPTIMIZED BATCH ENDPOINTS =====

  /// 🚀 OPTIMIZED: Get orders with invoice status in a SINGLE API call
  /// 
  /// This replaces the old N+1 approach:
  /// - Old: 1 call for orders + N calls for invoice checks = 31 calls for 30 orders
  /// - New: 1 call with all data = 1 call for any number of orders
  /// 
  /// [vendorId] - Vendor/store ID
  /// [page] - Page number (0-indexed)
  /// [size] - Page size (max 100)
  /// [filter] - "all" | "pending" | "uploaded"
  static Future<OrdersWithInvoiceResponse> getOrdersWithInvoiceStatus(
    String vendorId, {
    int page = 0,
    int size = 20,
    String filter = 'all', // 'all', 'pending', 'uploaded'
  }) async {
    try {
      final url = '${ApiConfig.baseUrl}/orders/vendor/$vendorId/orders-with-invoice-status'
          '?page=$page&size=$size&filter=$filter';
      
      print('📊 Fetching orders with invoice status: $url');
      final stopwatch = Stopwatch()..start();
      
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      
      stopwatch.stop();
      print('✅ Fetched in ${stopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OrdersWithInvoiceResponse.fromJson(data);
      }
      throw Exception('Failed to load orders: ${response.statusCode}');
    } catch (e) {
      print('❌ Error fetching orders with invoice status: $e');
      rethrow;
    }
  }

  /// 🚀 Get invoice summary (counts only - very fast)
  static Future<InvoiceSummary> getInvoiceSummary(String vendorId) async {
    try {
      final url = '${ApiConfig.baseUrl}/orders/vendor/$vendorId/invoice-summary';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        return InvoiceSummary.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to load summary: ${response.statusCode}');
    } catch (e) {
      print('Error fetching invoice summary: $e');
      rethrow;
    }
  }

  /// 🚀 Batch check invoice status for multiple orders
  static Future<Map<String, bool>> batchCheckInvoiceStatus(List<String> orderIds) async {
    try {
      final url = '${ApiConfig.baseUrl}/orders/invoice/batch-check';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'orderIds': orderIds}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, dynamic> orderIdsMap = data['orderIds'] ?? {};
        return orderIdsMap.map((k, v) => MapEntry(k, v as bool));
      }
      throw Exception('Batch check failed: ${response.statusCode}');
    } catch (e) {
      print('Error batch checking invoices: $e');
      rethrow;
    }
  }

  // ===== GCS SIGNED URL UPLOAD (PREFERRED - like prescriptions/documents) =====

  /// Validate file before upload
  static String? validateInvoiceFile(Uint8List fileBytes, String fileName) {
    // Check file size (max 5MB)
    if (fileBytes.length > maxInvoiceFileSizeBytes) {
      final sizeMB = (fileBytes.length / (1024 * 1024)).toStringAsFixed(2);
      return 'File size ($sizeMB MB) exceeds maximum allowed ($maxInvoiceFileSizeMB MB). Please compress the image.';
    }

    // Check file extension (images only, no PDF)
    final ext = fileName.toLowerCase().split('.').last;
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif'];
    if (!allowedExtensions.contains(ext)) {
      return 'Only image files (JPG, PNG, WebP) are allowed. PDFs are not supported.';
    }

    return null; // Valid
  }

  /// Step 1: Get signed upload URL from backend
  static Future<Map<String, dynamic>> getUploadUrl(String orderId, String vendorId) async {
    try {
      print('📤 Getting signed URL for invoice upload...');
      
      final url = '${ApiConfig.baseUrl}/orders/$orderId/invoice/upload-url';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'vendorId': vendorId,
          'contentType': 'image/jpeg',
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Got signed URL, objectKey: ${data['objectKey']}');
        return data;
      } else {
        print('❌ Failed to get signed URL: ${response.statusCode}');
        throw Exception('Failed to get upload URL: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Error getting signed URL: $e');
      rethrow;
    }
  }

  /// Step 2: Upload directly to GCS using signed URL
  static Future<bool> uploadToGcs(String uploadUrl, Uint8List bytes) async {
    try {
      print('📤 Uploading ${bytes.length} bytes to GCS...');
      
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': 'image/jpeg'},
        body: bytes,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ GCS upload successful');
        return true;
      } else {
        print('❌ GCS upload failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('💥 Error uploading to GCS: $e');
      return false;
    }
  }

  /// Step 3: Confirm upload with invoice details
  static Future<InvoiceUploadResult> confirmUpload({
    required String orderId,
    required String vendorId,
    required String objectKey,
    required String invoiceNumber,
    required int fileSize,
    DateTime? invoiceDate,
    double? invoiceAmount,
  }) async {
    try {
      print('📤 Confirming invoice upload...');
      
      final url = '${ApiConfig.baseUrl}/orders/$orderId/invoice/confirm-upload';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'vendorId': vendorId,
          'objectKey': objectKey,
          'invoiceNumber': invoiceNumber,
          'fileSize': fileSize,
          if (invoiceDate != null) 'invoiceDate': invoiceDate.toIso8601String().split('T')[0],
          if (invoiceAmount != null) 'invoiceAmount': invoiceAmount,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        print('✅ Invoice confirmed');
        return InvoiceUploadResult.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        return InvoiceUploadResult(
          success: false,
          error: errorData['error'] ?? 'Confirmation failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('💥 Error confirming upload: $e');
      return InvoiceUploadResult(success: false, error: 'Network error: $e');
    }
  }

  /// 🚀 MAIN METHOD: Upload invoice using GCS signed URL (PREFERRED)
  /// 
  /// Flow (same as prescriptions/vendor documents):
  /// 1. Validate file size and type locally
  /// 2. Get signed upload URL from backend
  /// 3. Upload directly to GCS using PUT
  /// 4. Confirm upload with invoice details
  static Future<InvoiceUploadResult> uploadInvoiceWithGcs({
    required String orderId,
    required String vendorId,
    required Uint8List fileBytes,
    required String fileName,
    required String invoiceNumber,
    DateTime? invoiceDate,
    double? invoiceAmount,
  }) async {
    print('📤 Starting GCS invoice upload for order: $orderId');
    
    // Step 0: Validate file
    final validationError = validateInvoiceFile(fileBytes, fileName);
    if (validationError != null) {
      return InvoiceUploadResult(success: false, error: validationError);
    }
    
    // Validate invoice number
    if (invoiceNumber.trim().isEmpty) {
      return InvoiceUploadResult(
        success: false,
        error: 'Invoice number is required for GST compliance',
      );
    }

    try {
      // Step 1: Get signed upload URL
      final urlData = await getUploadUrl(orderId, vendorId);
      if (urlData['success'] != true) {
        return InvoiceUploadResult(
          success: false,
          error: urlData['message'] ?? 'Failed to get upload URL',
        );
      }
      
      final uploadUrl = urlData['uploadUrl'] as String;
      final objectKey = urlData['objectKey'] as String;
      
      // Step 2: Upload directly to GCS
      final uploadSuccess = await uploadToGcs(uploadUrl, fileBytes);
      if (!uploadSuccess) {
        return InvoiceUploadResult(
          success: false,
          error: 'Failed to upload to cloud storage. Please try again.',
        );
      }
      
      // Step 3: Confirm upload with invoice details
      return await confirmUpload(
        orderId: orderId,
        vendorId: vendorId,
        objectKey: objectKey,
        invoiceNumber: invoiceNumber,
        fileSize: fileBytes.length,
        invoiceDate: invoiceDate,
        invoiceAmount: invoiceAmount,
      );
      
    } catch (e) {
      print('💥 Error in GCS upload flow: $e');
      return InvoiceUploadResult(success: false, error: 'Upload failed: $e');
    }
  }

  // ===== EXISTING ENDPOINTS (kept for compatibility) =====

  /// Get all invoices for a vendor/store
  static Future<List<PharmacyInvoice>> getVendorInvoices(String vendorId) async {
    try {
      final url = '${ApiConfig.baseUrl}/orders/vendor/$vendorId/invoices';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => PharmacyInvoice.fromJson(j)).toList();
      }
      throw Exception('Failed to load invoices: ${response.statusCode}');
    } catch (e) {
      print('Error fetching vendor invoices: $e');
      rethrow;
    }
  }

  /// Check if invoice exists for an order
  static Future<Map<String, dynamic>> checkInvoiceExists(String orderId) async {
    try {
      final url = '${ApiConfig.baseUrl}/orders/$orderId/invoice/exists';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'hasInvoice': false};
    } catch (e) {
      print('Error checking invoice: $e');
      return {'hasInvoice': false};
    }
  }

  /// Get invoice details for an order
  static Future<PharmacyInvoice?> getInvoice(String orderId) async {
    try {
      final url = '${ApiConfig.baseUrl}/orders/$orderId/invoice';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        return PharmacyInvoice.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('Error fetching invoice: $e');
      return null;
    }
  }

  /// Upload invoice image (base64)
  static Future<InvoiceUploadResult> uploadInvoiceBase64({
    required String orderId,
    required String vendorId,
    required String base64Image,
    String? invoiceNumber,
    DateTime? invoiceDate,
    double? invoiceAmount,
  }) async {
    try {
      final url = '${ApiConfig.baseUrl}/orders/$orderId/invoice/upload';
      
      final body = {
        'vendorId': vendorId,
        'image': base64Image,
        if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
        if (invoiceDate != null) 'invoiceDate': invoiceDate.toIso8601String().split('T')[0],
        if (invoiceAmount != null) 'invoiceAmount': invoiceAmount,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return InvoiceUploadResult.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        return InvoiceUploadResult(
          success: false,
          error: errorData['error'] ?? 'Upload failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error uploading invoice: $e');
      return InvoiceUploadResult(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

}
