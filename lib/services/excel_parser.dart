import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/inventory_item.dart';

class ExcelParser {
  /// Parse Excel file bytes into inventory items
  /// Expected columns (based on sample):
  /// S. No. | Product Name | Composition | Company | Category | 
  /// tab/qty per stp/vial/bottle qty | Inventory qty | Inventory type |
  /// MRP (Inventory type) | Selling Price | Used in | Precautions |
  /// Product image 1 | Product Image 2 | Recommended/Prescribed
  static List<InventoryItem> parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<InventoryItem> items = [];

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

    print('Parsed ${items.length} items from Excel');
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
      // Order matters! More specific matches first
      if (header.contains('s.') || header.contains('serial') || header == 'no' || header == 'no.') {
        columnMap['serialNo'] = i;
      } else if (header.contains('product name') || header == 'name' || header == 'medicine') {
        columnMap['productName'] = i;
      } else if (header.contains('composition') || header.contains('salt') || header.contains('generic')) {
        columnMap['composition'] = i;
      } else if (header.contains('company') || header.contains('manufacturer')) {
        columnMap['company'] = i;
      } else if (header.contains('tab/qty') || header.contains('pack') || header.contains('strip') || header.contains('per stp')) {
        columnMap['packSize'] = i;
      } else if (header.contains('inventory qty') || header.contains('stock') || (header.contains('qty') && !header.contains('tab'))) {
        columnMap['inventoryQty'] = i;
      } else if (header.contains('mrp')) {
        // MRP - check BEFORE inventory type since "MRP (Inventory type)" contains both
        columnMap['mrp'] = i;
      } else if (header.contains('inventory type') || header == 'form' || header == 'type') {
        columnMap['inventoryType'] = i;
      } else if (header.contains('selling') || (header.contains('price') && !header.contains('mrp'))) {
        columnMap['sellingPrice'] = i;
      } else if (header.contains('category')) {
        columnMap['category'] = i;
      } else if (header.contains('used in') || header.contains('indication') || header.contains('uses')) {
        columnMap['usedIn'] = i;
      } else if (header.contains('precaution') || header.contains('warning') || header.contains('side effect')) {
        columnMap['precautions'] = i;
      } else if (header.contains('image 1') || header.contains('product image 1')) {
        columnMap['imageUrl1'] = i;
      } else if (header.contains('image 2') || header.contains('product image 2')) {
        columnMap['imageUrl2'] = i;
      } else if (header.contains('recommend') || header.contains('prescri') || header.contains('rx')) {
        columnMap['prescriptionInfo'] = i;
      }
    }

    return columnMap;
  }

  /// Check if row is empty
  static bool _isEmptyRow(List<Data?> row) {
    return row.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty);
  }

  /// Parse a single row into InventoryItem
  static InventoryItem? _parseRow(List<Data?> row, Map<String, int> columnMap, int rowIndex) {
    // Get required fields
    String? productName = _getCellString(row, columnMap['productName']);
    
    // Skip if no product name
    if (productName == null || productName.isEmpty) {
      return null;
    }

    // Parse numeric values
    int? serialNo = _getCellInt(row, columnMap['serialNo']) ?? rowIndex;
    int inventoryQty = _getCellInt(row, columnMap['inventoryQty']) ?? 0;
    double? mrp = _getCellDouble(row, columnMap['mrp']);
    double sellingPrice = _getCellDouble(row, columnMap['sellingPrice']) ?? mrp ?? 0.0;

    return InventoryItem(
      serialNo: serialNo,
      productName: productName,
      composition: _getCellString(row, columnMap['composition']),
      company: _getCellString(row, columnMap['company']),
      category: _getCellString(row, columnMap['category']),
      packSize: _getCellString(row, columnMap['packSize']),
      inventoryQty: inventoryQty,
      inventoryType: _getCellString(row, columnMap['inventoryType']),
      mrp: mrp,
      sellingPrice: sellingPrice,
      usedIn: _getCellString(row, columnMap['usedIn']),
      precautions: _getCellString(row, columnMap['precautions']),
      imageUrl1: _getCellString(row, columnMap['imageUrl1']),
      imageUrl2: _getCellString(row, columnMap['imageUrl2']),
      prescriptionInfo: _getCellString(row, columnMap['prescriptionInfo']),
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
    
    // CellValue in excel 4.x wraps the actual value
    final cellValue = cell!.value;
    final strValue = cellValue.toString().trim();
    if (strValue.isEmpty) return null;
    
    // Try parsing as double first (handles "150.0" etc), then convert to int
    final doubleVal = double.tryParse(strValue);
    if (doubleVal != null) return doubleVal.toInt();
    
    return int.tryParse(strValue);
  }

  /// Get cell value as double
  static double? _getCellDouble(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return null;
    final cell = row[index];
    if (cell?.value == null) return null;
    
    // CellValue in excel 4.x wraps the actual value
    final cellValue = cell!.value;
    final strValue = cellValue.toString().trim();
    if (strValue.isEmpty) return null;
    
    return double.tryParse(strValue);
  }
}

