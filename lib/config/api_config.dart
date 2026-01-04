class ApiConfig {
  // Environment toggle - set to true for local development
  static const bool _isDevelopment = false;
  
  // Development URL (localhost)
  static const String _devBaseUrl = 'http://localhost:8081/api';
  
  // Production URL (GCP Cloud Run)
  static const String _prodBaseUrl = 'https://prismo-service-184530546940.us-central1.run.app/api';
  
  // Active base URL
  static String get baseUrl => _isDevelopment ? _devBaseUrl : _prodBaseUrl;
  
  // =====================================================
  // MANAGER AUTHENTICATION ENDPOINTS
  // =====================================================
  
  static String get managersUrl => '$baseUrl/admin/managers';
  
  // Register new manager (POST)
  static String get managerRegisterUrl => '$managersUrl/register';
  
  // Login with phone number (POST) - after Firebase OTP
  static String get managerPhoneLoginUrl => '$managersUrl/login/phone';
  
  // Login with email/password (POST)
  static String get managerEmailLoginUrl => '$managersUrl/login';
  
  // Register with email/password (POST)
  static String get managerEmailRegisterUrl => '$managersUrl/register/email';
  
  // Set password for existing manager (POST)
  static String managerSetPasswordUrl(String managerId) => '$managersUrl/$managerId/password';
  
  // Get manager by ID (GET)
  static String managerByIdUrl(String managerId) => '$managersUrl/$managerId';
  
  // Get manager by phone (GET)
  static String managerByPhoneUrl(String phoneNumber) => '$managersUrl/by-phone/$phoneNumber';
  
  // Update manager profile (PUT)
  static String managerUpdateUrl(String managerId) => '$managersUrl/$managerId';
  
  // Get manager for a vendor (GET)
  static String managerForVendorUrl(String vendorId) => '$managersUrl/vendor/$vendorId';
  
  // =====================================================
  // ADMIN INVENTORY ENDPOINTS
  // =====================================================
  
  static String get adminInventoryUrl => '$baseUrl/admin/inventory';
  
  // Stores (all)
  static String get storesUrl => '$adminInventoryUrl/stores';
  
  // Stores filtered by IDs
  static String storesByIdsUrl(List<String> ids) => 
      '$adminInventoryUrl/stores?ids=${ids.join(",")}';
  
  // Upload endpoint (regular)
  static String get uploadUrl => '$adminInventoryUrl/upload';
  
  // Bulk upload endpoint (optimized for large uploads)
  static String get bulkUploadUrl => '$adminInventoryUrl/bulk-upload';
  
  // Bulk delete endpoint
  static String get bulkDeleteUrl => '$adminInventoryUrl/bulk-delete';
  
  // Bulk deduction endpoint (for reducing stock)
  static String get deductUrl => '$adminInventoryUrl/deduct';
  
  // Single item deduction
  static String deductSingleUrl(String storeId, String medicineId) => 
      '$adminInventoryUrl/store/$storeId/$medicineId/deduct';
  
  // Delete inventory item
  static String deleteInventoryItemUrl(String storeId, String medicineId) => 
      '$adminInventoryUrl/store/$storeId/$medicineId';
  
  // Store inventory (with pagination and filtering support)
  static String storeInventoryUrl(
    String storeId, {
    int page = 0,
    int size = 50,
    String status = 'all',
    String? search,
  }) {
    var url = '$adminInventoryUrl/store/$storeId?page=$page&size=$size&status=$status';
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }
    return url;
  }
  
  // Store alerts
  static String storeAlertsUrl(String storeId) => '$adminInventoryUrl/store/$storeId/alerts';
  
  // Stats
  static String get statsUrl => '$adminInventoryUrl/stats';
  
  // Medicines endpoint
  static String get medicinesUrl => '$baseUrl/medicines';
  
  // Search medicines
  static String searchMedicinesUrl(String query) => '$medicinesUrl/search?query=$query';
  
  // =====================================================
  // PROMOTION ENDPOINTS
  // =====================================================
  
  // Create promotion endpoint
  /// Create promotion URL (vendor-agnostic - promotions apply to all vendors)
  /// vendorId parameter kept for backward compatibility but ignored by backend
  static String createPromotionUrl([String? vendorId]) => 
      '$baseUrl/promotions/'; // Vendor-agnostic endpoint (with trailing slash to match backend @PostMapping)
}

