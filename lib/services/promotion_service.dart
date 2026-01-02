import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/promotion_item.dart';
import '../models/promotion.dart';

class PromotionService {
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _uploadTimeout = Duration(seconds: 180); // 3 min timeout for large batches

  /// Upload promotions from parsed Excel data with batching for large files
  /// Uses vendor-agnostic promotion create endpoint (promotions apply to all vendors)
  /// [onProgress] callback receives (completed, total, currentBatch, totalBatches)
  /// vendorId parameter kept for backward compatibility but ignored by backend
  static Future<PromotionUploadResponse> uploadPromotions(
    String? vendorId, // Optional - promotions are vendor-agnostic
    List<PromotionItem> items, {
    void Function(int completed, int total, int currentBatch, int totalBatches)? onProgress,
  }) async {
    // Use batch size similar to inventory upload
    const int batchSize = 100; // Smaller batches for promotions (more complex validation)
    final int totalItems = items.length;
    final int totalBatches = (totalItems / batchSize).ceil();

    print('Uploading $totalItems promotions in $totalBatches batches (vendor-agnostic - applies to all vendors)');

    // Aggregate results across batches
    int successfulPromotions = 0;
    int failedPromotions = 0;
    List<PromotionUploadError> allErrors = [];

    for (int batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      final int start = batchIndex * batchSize;
      final int end = (start + batchSize > totalItems) ? totalItems : start + batchSize;
      final batch = items.sublist(start, end);

      print('Uploading batch ${batchIndex + 1}/$totalBatches (items $start-$end)');
      onProgress?.call(start, totalItems, batchIndex + 1, totalBatches);

      // Process each promotion in the batch
      for (int i = 0; i < batch.length; i++) {
        final item = batch[i];
        try {
          final requestBody = json.encode(item.toJson());

          // Call vendor-agnostic promotion create endpoint
          final response = await http
              .post(
                Uri.parse(ApiConfig.createPromotionUrl()), // Vendor-agnostic endpoint
                headers: {'Content-Type': 'application/json'},
                body: requestBody,
              )
              .timeout(_uploadTimeout);

          if (response.statusCode == 200) {
            successfulPromotions++;
            print('Promotion "${item.promotionName}" created successfully');
          } else {
            failedPromotions++;
            final errorBody = response.body;
            String errorMessage = 'Failed with status ${response.statusCode}';
            try {
              final errorJson = json.decode(errorBody);
              errorMessage = errorJson['error'] ?? errorMessage;
            } catch (e) {
              // Use default error message
            }
            allErrors.add(PromotionUploadError(
              promotionName: item.promotionName,
              errorMessage: errorMessage,
            ));
            print('Promotion "${item.promotionName}" failed: $errorMessage');
          }
        } catch (e) {
          failedPromotions++;
          allErrors.add(PromotionUploadError(
            promotionName: item.promotionName,
            errorMessage: 'Error: $e',
          ));
          print('Error uploading promotion "${item.promotionName}": $e');
        }
        
        // Update progress after each item
        final completed = start + i + 1;
        onProgress?.call(completed, totalItems, batchIndex + 1, totalBatches);
      }
    }

    onProgress?.call(totalItems, totalItems, totalBatches, totalBatches);

    return PromotionUploadResponse(
      success: failedPromotions == 0,
      message:
          'Upload completed. $successfulPromotions successful${failedPromotions > 0 ? ", $failedPromotions failed" : ""}',
      totalItems: totalItems,
      successfulPromotions: successfulPromotions,
      failedPromotions: failedPromotions,
      errors: allErrors,
    );
  }

  /// Get all promotions (vendor-agnostic - applies to all vendors)
  /// vendorId parameter kept for backward compatibility but ignored by backend
  static Future<List<Promotion>> getPromotionsForVendor(String? vendorId) async {
    try {
      // Use vendor-agnostic endpoint - promotions apply to all vendors
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/promotions'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final promotions = jsonList
            .map((json) => Promotion.fromJson(json as Map<String, dynamic>))
            .toList();
        
        print('Found ${promotions.length} promotions (vendor-agnostic)');
        return promotions;
      } else {
        print('Failed to fetch promotions. Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching promotions: $e');
      return [];
    }
  }

  /// Get active promotions (vendor-agnostic - applies to all vendors)
  /// vendorId parameter kept for backward compatibility but ignored by backend
  static Future<List<Promotion>> getActivePromotionsForVendor(String? vendorId) async {
    try {
      // Use vendor-agnostic endpoint - promotions apply to all vendors
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/promotions/active'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final promotions = jsonList
            .map((json) => Promotion.fromJson(json as Map<String, dynamic>))
            .toList();
        
        print('Found ${promotions.length} active promotions (vendor-agnostic)');
        return promotions;
      } else {
        print('Failed to fetch active promotions. Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching active promotions: $e');
      return [];
    }
  }

  /// Deactivate a promotion (vendor-agnostic)
  /// vendorId parameter kept for backward compatibility but ignored by backend
  static Future<bool> deactivatePromotion(String? vendorId, String promotionId) async {
    try {
      // Use vendor-agnostic endpoint
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/promotions/$promotionId/deactivate'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        print('Promotion $promotionId deactivated successfully');
        return true;
      } else {
        print('Failed to deactivate promotion. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error deactivating promotion: $e');
      return false;
    }
  }

  /// Activate a promotion (vendor-agnostic)
  /// vendorId parameter kept for backward compatibility but ignored by backend
  static Future<bool> activatePromotion(String? vendorId, String promotionId) async {
    try {
      // Use vendor-agnostic endpoint
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/promotions/$promotionId/activate'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        print('Promotion $promotionId activated successfully');
        return true;
      } else {
        print('Failed to activate promotion. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error activating promotion: $e');
      return false;
    }
  }
}

