import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/promotion_item.dart';

class PromotionParser {
  /// Parse Excel file bytes into promotion items
  /// Expected columns:
  /// Promotion Name | Promotion Type | Discount Value | Min Order Amount | 
  /// Max Discount Amount | Start Date | End Date | Applicable On |
  /// Usage Limit Per User | Total Usage Limit | Promo Code | Description |
  /// Banner Image URL | Terms Conditions | Is Active | Created By |
  /// Medicine IDs | Categories
  static List<PromotionItem> parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<PromotionItem> items = [];

    // Get first sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];

    if (sheet == null || sheet.rows.isEmpty) {
      throw Exception('Empty or invalid Excel file');
    }

    // Find header row (first row)
    final headerRow = sheet.rows.first;
    final columnMap = _mapColumns(headerRow);

    print('Found columns: $columnMap');

    // Parse data rows (skip header)
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];

      // Skip empty rows
      if (_isEmptyRow(row)) continue;

      try {
        final item = _parseRow(row, columnMap, i);
        if (item != null) {
          items.add(item);
        }
      } catch (e) {
        print('Error parsing row $i: $e');
        // Continue with next row
      }
    }

    print('Parsed ${items.length} promotions from Excel');
    return items;
  }

  /// Map column headers to indices
  static Map<String, int> _mapColumns(List<Data?> headerRow) {
    final Map<String, int> columnMap = {};

    for (int i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell?.value == null) continue;

      final header = cell!.value.toString().toLowerCase().trim();

      // Map various possible header names to our standard keys
      if (header.contains('promotion name') || header == 'name' || header == 'promotion') {
        columnMap['promotionName'] = i;
      } else if (header.contains('promotion type') || header.contains('type')) {
        columnMap['promotionType'] = i;
      } else if (header.contains('discount value') || header.contains('discount')) {
        columnMap['discountValue'] = i;
      } else if (header.contains('min order') || header.contains('minimum order')) {
        columnMap['minOrderAmount'] = i;
      } else if (header.contains('max discount') || header.contains('maximum discount')) {
        columnMap['maxDiscountAmount'] = i;
      } else if (header.contains('start date') || header.contains('start')) {
        columnMap['startDate'] = i;
      } else if (header.contains('end date') || header.contains('end')) {
        columnMap['endDate'] = i;
      } else if (header.contains('applicable on') || header.contains('applicable')) {
        columnMap['applicableOn'] = i;
      } else if (header.contains('usage limit per user') || header.contains('per user limit')) {
        columnMap['usageLimitPerUser'] = i;
      } else if (header.contains('total usage limit') || header.contains('total limit')) {
        columnMap['totalUsageLimit'] = i;
      } else if (header.contains('promo code') || header.contains('promocode') || header.contains('code')) {
        columnMap['promoCode'] = i;
      } else if (header.contains('description')) {
        columnMap['description'] = i;
      } else if (header.contains('banner') || header.contains('image')) {
        columnMap['bannerImageUrl'] = i;
      } else if (header.contains('terms') || header.contains('conditions')) {
        columnMap['termsConditions'] = i;
      } else if (header.contains('is active') || header.contains('active')) {
        columnMap['isActive'] = i;
      } else if (header.contains('created by') || header.contains('creator')) {
        columnMap['createdBy'] = i;
      } else if (header.contains('medicine') && header.contains('id')) {
        columnMap['medicineIds'] = i;
      } else if (header.contains('category') || header.contains('categories')) {
        columnMap['categories'] = i;
      }
    }

    return columnMap;
  }

  /// Check if row is empty
  static bool _isEmptyRow(List<Data?> row) {
    return row.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty);
  }

  /// Parse a single row into PromotionItem
  static PromotionItem? _parseRow(List<Data?> row, Map<String, int> columnMap, int rowIndex) {
    // Get required fields
    String? promotionName = _getCellString(row, columnMap['promotionName']);

    // Skip if no promotion name
    if (promotionName == null || promotionName.isEmpty) {
      return null;
    }

    // Parse dates
    DateTime? startDate = _getCellDate(row, columnMap['startDate']);
    DateTime? endDate = _getCellDate(row, columnMap['endDate']);

    // Parse numeric values
    double? discountValue = _getCellDouble(row, columnMap['discountValue']);
    double? minOrderAmount = _getCellDouble(row, columnMap['minOrderAmount']);
    double? maxDiscountAmount = _getCellDouble(row, columnMap['maxDiscountAmount']);
    int? usageLimitPerUser = _getCellInt(row, columnMap['usageLimitPerUser']);
    int? totalUsageLimit = _getCellInt(row, columnMap['totalUsageLimit']);

    // Parse boolean
    bool? isActive = _getCellBool(row, columnMap['isActive']);

    return PromotionItem(
      promotionName: promotionName,
      promotionType: _getCellString(row, columnMap['promotionType']),
      discountValue: discountValue,
      minOrderAmount: minOrderAmount,
      maxDiscountAmount: maxDiscountAmount,
      startDate: startDate,
      endDate: endDate,
      applicableOn: _getCellString(row, columnMap['applicableOn']),
      usageLimitPerUser: usageLimitPerUser,
      totalUsageLimit: totalUsageLimit,
      promoCode: _getCellString(row, columnMap['promoCode']),
      description: _getCellString(row, columnMap['description']),
      bannerImageUrl: _getCellString(row, columnMap['bannerImageUrl']),
      termsConditions: _getCellString(row, columnMap['termsConditions']),
      isActive: isActive,
      createdBy: _getCellString(row, columnMap['createdBy']),
      medicineIds: _getCellString(row, columnMap['medicineIds']),
      categories: _getCellString(row, columnMap['categories']),
    );
  }

  /// Get cell value as string
  static String? _getCellString(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return null;
    final cell = row[index];
    if (cell?.value == null) return null;
    final value = cell!.value.toString().trim();
    return value.isEmpty ? null : value;
  }

  /// Get cell value as int
  static int? _getCellInt(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return null;
    final cell = row[index];
    if (cell?.value == null) return null;

    final cellValue = cell!.value;
    final strValue = cellValue.toString().trim();
    if (strValue.isEmpty) return null;

    final doubleVal = double.tryParse(strValue);
    if (doubleVal != null) return doubleVal.toInt();

    return int.tryParse(strValue);
  }

  /// Get cell value as double
  static double? _getCellDouble(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return null;
    final cell = row[index];
    if (cell?.value == null) return null;

    final cellValue = cell!.value;
    final strValue = cellValue.toString().trim();
    if (strValue.isEmpty) return null;

    return double.tryParse(strValue);
  }

  /// Get cell value as boolean
  static bool? _getCellBool(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return null;
    final cell = row[index];
    if (cell?.value == null) return null;

    final cellValue = cell!.value;
    final strValue = cellValue.toString().trim().toLowerCase();
    if (strValue.isEmpty) return null;

    if (strValue == 'true' || strValue == '1' || strValue == 'yes' || strValue == 'y') {
      return true;
    } else if (strValue == 'false' || strValue == '0' || strValue == 'no' || strValue == 'n') {
      return false;
    }

    return null;
  }

  /// Get cell value as DateTime
  static DateTime? _getCellDate(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return null;
    final cell = row[index];
    if (cell?.value == null) return null;

    // CellValue in excel 4.x wraps the actual value
    final cellValue = cell!.value;
    
    // Convert to string first (CellValue wraps the value)
    final strValue = cellValue.toString().trim();
    if (strValue.isEmpty) return null;

    // Try various date formats
    final dateFormats = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy',
      'MM/dd/yyyy HH:mm:ss',
      'MM/dd/yyyy',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy',
    ];

    for (final format in dateFormats) {
      try {
        final dateFormat = DateFormat(format);
        return dateFormat.parse(strValue);
      } catch (e) {
        // Try next format
      }
    }

    // Try parsing as ISO 8601
    try {
      return DateTime.parse(strValue);
    } catch (e) {
      print('Could not parse date: $strValue');
      return null;
    }
  }
}

