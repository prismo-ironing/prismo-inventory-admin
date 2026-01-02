import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/promotion_item.dart';

class PromotionService {
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _uploadTimeout = Duration(seconds: 180); // 3 min timeout for large batches

  /// Upload promotions from parsed Excel data with batching for large files
  /// Uses promotion create endpoint with batching similar to inventory upload
  /// [onProgress] callback receives (completed, total, currentBatch, totalBatches)
  static Future<PromotionUploadResponse> uploadPromotions(
    String vendorId,
    List<PromotionItem> items, {
    void Function(int completed, int total, int currentBatch, int totalBatches)? onProgress,
  }) async {
    // Use batch size similar to inventory upload
    const int batchSize = 100; // Smaller batches for promotions (more complex validation)
    final int totalItems = items.length;
    final int totalBatches = (totalItems / batchSize).ceil();

    print('Uploading $totalItems promotions in $totalBatches batches to vendor $vendorId');

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

          // Call promotion create endpoint
          final response = await http
              .post(
                Uri.parse(ApiConfig.createPromotionUrl(vendorId)),
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
}

