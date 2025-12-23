import 'dart:convert';
import 'dart:typed_data';
import '../models/inventory_item.dart';

class CsvParser {
  /// Parse CSV file bytes into inventory items
  /// Supports both comma-separated and tab-separated values
  /// 
  /// Expected columns (medicine catalog format):
  /// sub_category | product_name | salt_composition | product_price |
  /// product_manufactured | medicine_desc | side_effects | drug_interactions
  static List<InventoryItem> parseCsv(Uint8List bytes) {
    final String content = utf8.decode(bytes);
    final List<InventoryItem> items = [];

    // Split into lines
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) {
      throw Exception('Empty CSV file');
    }

    // Detect delimiter (tab or comma)
    final delimiter = _detectDelimiter(lines.first);
    print('Detected delimiter: ${delimiter == '\t' ? 'TAB' : 'COMMA'}');

    // Parse header row
    final headerRow = _parseCsvLine(lines.first, delimiter);
    final columnMap = _mapColumns(headerRow);
    print('Found columns: $columnMap');

    // Parse data rows (skip header)
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final row = _parseCsvLine(line, delimiter);
        final item = _parseRow(row, columnMap, i);
        if (item != null) {
          items.add(item);
        }
      } catch (e) {
        print('Error parsing row $i: $e');
        // Continue with next row
      }
    }

    print('Parsed ${items.length} items from CSV');
    return items;
  }

  /// Detect delimiter (tab or comma)
  static String _detectDelimiter(String headerLine) {
    final tabCount = headerLine.split('\t').length;
    final commaCount = headerLine.split(',').length;
    return tabCount > commaCount ? '\t' : ',';
  }

  /// Parse a CSV line handling quoted fields
  static List<String> _parseCsvLine(String line, String delimiter) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        // Check for escaped quote
        if (i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString().trim());

    return result;
  }

  /// Map column headers to indices
  static Map<String, int> _mapColumns(List<String> headerRow) {
    final Map<String, int> columnMap = {};

    for (int i = 0; i < headerRow.length; i++) {
      final header = headerRow[i].toLowerCase().trim();
      if (header.isEmpty) continue;

      // Map various possible header names to our standard keys
      // Support both Excel format and new CSV format
      
      // Serial number
      if (header.contains('s.') || header.contains('serial') || header == 'no' || header == 'no.') {
        columnMap['serialNo'] = i;
      }
      // Product name
      else if (header == 'product_name' || header.contains('product name') || header == 'name' || header == 'medicine') {
        columnMap['productName'] = i;
      }
      // Composition / Salt
      else if (header == 'salt_composition' || header.contains('composition') || header.contains('salt') || header.contains('generic')) {
        columnMap['composition'] = i;
      }
      // Company / Manufacturer
      else if (header == 'product_manufactured' || header.contains('company') || header.contains('manufacturer') || header.contains('manufactured')) {
        columnMap['company'] = i;
      }
      // Category
      else if (header == 'sub_category' || header.contains('category')) {
        columnMap['category'] = i;
      }
      // Pack size
      else if (header.contains('tab/qty') || header.contains('pack') || header.contains('strip') || header.contains('per stp')) {
        columnMap['packSize'] = i;
      }
      // Inventory quantity
      else if (header.contains('inventory qty') || header.contains('stock') || (header.contains('qty') && !header.contains('tab'))) {
        columnMap['inventoryQty'] = i;
      }
      // MRP
      else if (header.contains('mrp')) {
        columnMap['mrp'] = i;
      }
      // Price (product_price or selling price)
      else if (header == 'product_price' || header.contains('selling') || (header.contains('price') && !header.contains('mrp'))) {
        columnMap['sellingPrice'] = i;
      }
      // Inventory type / Form
      else if (header.contains('inventory type') || header == 'form' || header == 'type') {
        columnMap['inventoryType'] = i;
      }
      // Used in / Description / Indications
      else if (header == 'medicine_desc' || header.contains('used in') || header.contains('indication') || header.contains('uses') || header.contains('desc')) {
        columnMap['usedIn'] = i;
      }
      // Precautions / Side effects
      else if (header == 'side_effects' || header.contains('precaution') || header.contains('warning') || header.contains('side effect')) {
        columnMap['precautions'] = i;
      }
      // Drug interactions
      else if (header == 'drug_interactions' || header.contains('interaction')) {
        columnMap['drugInteractions'] = i;
      }
      // Images
      else if (header.contains('image 1') || header.contains('product image 1')) {
        columnMap['imageUrl1'] = i;
      }
      else if (header.contains('image 2') || header.contains('product image 2')) {
        columnMap['imageUrl2'] = i;
      }
      // Prescription info
      else if (header.contains('recommend') || header.contains('prescri') || header.contains('rx')) {
        columnMap['prescriptionInfo'] = i;
      }
    }

    return columnMap;
  }

  /// Parse a single row into InventoryItem
  static InventoryItem? _parseRow(List<String> row, Map<String, int> columnMap, int rowIndex) {
    // Get required fields
    String? productName = _getCellString(row, columnMap['productName']);

    // Skip if no product name
    if (productName == null || productName.isEmpty) {
      return null;
    }

    // Parse numeric values
    int serialNo = _getCellInt(row, columnMap['serialNo']) ?? rowIndex;
    int inventoryQty = _getCellInt(row, columnMap['inventoryQty']) ?? 0;
    double? mrp = _getCellDouble(row, columnMap['mrp']);
    double? sellingPrice = _getCellDouble(row, columnMap['sellingPrice']);
    
    // If only one price is available, use it for both
    mrp ??= sellingPrice;
    sellingPrice ??= mrp ?? 0.0;

    // Combine side effects and drug interactions into precautions if available
    String? precautions = _getCellString(row, columnMap['precautions']);
    String? drugInteractions = _getCellString(row, columnMap['drugInteractions']);
    if (drugInteractions != null && drugInteractions.isNotEmpty) {
      precautions = precautions != null 
          ? '$precautions\n\nDrug Interactions: $drugInteractions'
          : 'Drug Interactions: $drugInteractions';
    }

    // Extract form/type from product name if not explicitly provided
    String? inventoryType = _getCellString(row, columnMap['inventoryType']);
    if (inventoryType == null || inventoryType.isEmpty) {
      inventoryType = _extractFormFromProductName(productName);
    }

    return InventoryItem(
      serialNo: serialNo,
      productName: productName,
      composition: _getCellString(row, columnMap['composition']),
      company: _getCellString(row, columnMap['company']),
      category: _getCellString(row, columnMap['category']),
      packSize: _getCellString(row, columnMap['packSize']),
      inventoryQty: inventoryQty,
      inventoryType: inventoryType,
      mrp: mrp,
      sellingPrice: sellingPrice,
      usedIn: _getCellString(row, columnMap['usedIn']),
      precautions: precautions,
      imageUrl1: _getCellString(row, columnMap['imageUrl1']),
      imageUrl2: _getCellString(row, columnMap['imageUrl2']),
      prescriptionInfo: _getCellString(row, columnMap['prescriptionInfo']),
    );
  }

  /// Extract dosage form from product name
  static String _extractFormFromProductName(String productName) {
    final lowerName = productName.toLowerCase();
    
    // Check for common dosage forms in the product name
    if (lowerName.contains('injection') || lowerName.contains('inj ') || lowerName.contains('inj.')) {
      return 'injection';
    } else if (lowerName.contains('suspension')) {
      return 'suspension';
    } else if (lowerName.contains('syrup') || lowerName.contains('solution') || lowerName.contains('oral liquid')) {
      return 'syrup';
    } else if (lowerName.contains('capsule') || lowerName.contains('cap ') || lowerName.contains('cap.')) {
      return 'capsule';
    } else if (lowerName.contains('cream') || lowerName.contains('ointment') || lowerName.contains('gel')) {
      return 'cream';
    } else if (lowerName.contains('drops') || lowerName.contains('drop ')) {
      return 'drops';
    } else if (lowerName.contains('inhaler') || lowerName.contains('respules')) {
      return 'inhaler';
    } else if (lowerName.contains('powder') || lowerName.contains('sachet')) {
      return 'powder';
    } else if (lowerName.contains('spray') || lowerName.contains('nasal')) {
      return 'spray';
    } else if (lowerName.contains('patch')) {
      return 'patch';
    } else if (lowerName.contains('lotion')) {
      return 'lotion';
    } else if (lowerName.contains('tablet') || lowerName.contains('tab ') || lowerName.contains('tab.')) {
      return 'tablet';
    }
    
    // Default to tablet if no form is detected
    return 'tablet';
  }

  /// Get cell value as string
  static String? _getCellString(List<String> row, int? index) {
    if (index == null || index >= row.length) return null;
    final value = row[index].trim();
    // Remove currency symbols for price fields
    final cleaned = value.replaceAll('₹', '').replaceAll('\$', '').trim();
    return cleaned.isEmpty ? null : value;
  }

  /// Get cell value as int
  static int? _getCellInt(List<String> row, int? index) {
    if (index == null || index >= row.length) return null;
    final value = row[index].trim();
    if (value.isEmpty) return null;

    // Try parsing as double first (handles "150.0" etc), then convert to int
    final doubleVal = double.tryParse(value);
    if (doubleVal != null) return doubleVal.toInt();

    return int.tryParse(value);
  }

  /// Get cell value as double
  static double? _getCellDouble(List<String> row, int? index) {
    if (index == null || index >= row.length) return null;
    String value = row[index].trim();
    if (value.isEmpty) return null;

    // Remove currency symbols
    value = value.replaceAll('₹', '').replaceAll('\$', '').replaceAll(',', '').trim();

    return double.tryParse(value);
  }

  /// Parse CSV file bytes into delete items (just product names)
  /// Expects a simple CSV with at least a "product_name" or "name" column
  static List<DeleteItem> parseDeleteCsv(Uint8List bytes) {
    final String content = utf8.decode(bytes);
    final List<DeleteItem> items = [];

    // Split into lines
    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) {
      throw Exception('Empty CSV file');
    }

    // Detect delimiter (tab or comma)
    final delimiter = _detectDelimiter(lines.first);
    print('Delete CSV - Detected delimiter: ${delimiter == '\t' ? 'TAB' : 'COMMA'}');

    // Parse header row
    final headerRow = _parseCsvLine(lines.first, delimiter);
    int? productNameIndex;
    int? medicineIdIndex;

    for (int i = 0; i < headerRow.length; i++) {
      final header = headerRow[i].toLowerCase().trim();
      if (header == 'product_name' || header.contains('product name') || 
          header == 'name' || header == 'medicine' || header == 'medicine name') {
        productNameIndex = i;
      }
      if (header == 'medicine_id' || header.contains('medicine id') || header == 'id') {
        medicineIdIndex = i;
      }
    }

    if (productNameIndex == null && medicineIdIndex == null) {
      throw Exception('CSV must have a "product_name", "name", or "medicine_id" column');
    }

    print('Found columns - productName: $productNameIndex, medicineId: $medicineIdIndex');

    // Parse data rows (skip header)
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        final row = _parseCsvLine(line, delimiter);
        String? productName = productNameIndex != null && productNameIndex < row.length 
            ? row[productNameIndex].trim() 
            : null;
        String? medicineId = medicineIdIndex != null && medicineIdIndex < row.length 
            ? row[medicineIdIndex].trim() 
            : null;

        if ((productName != null && productName.isNotEmpty) || 
            (medicineId != null && medicineId.isNotEmpty)) {
          items.add(DeleteItem(
            productName: productName?.isNotEmpty == true ? productName : null,
            medicineId: medicineId?.isNotEmpty == true ? medicineId : null,
          ));
        }
      } catch (e) {
        print('Error parsing row $i for delete: $e');
      }
    }

    print('Parsed ${items.length} delete items from CSV');
    return items;
  }
}

