import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/inventory_item.dart';
import '../models/promotion.dart';
import '../services/promotion_service.dart';
import 'package:intl/intl.dart';

class PromotionsViewScreen extends StatefulWidget {
  final Store store;

  const PromotionsViewScreen({super.key, required this.store});

  @override
  State<PromotionsViewScreen> createState() => _PromotionsViewScreenState();
}

class _PromotionsViewScreenState extends State<PromotionsViewScreen> {
  bool _isLoading = true;
  String? _error;
  List<Promotion> _promotions = [];
  List<Promotion> _filteredPromotions = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, inactive, expired

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final promotions = await PromotionService.getPromotionsForVendor(widget.store.id);
      
      setState(() {
        _promotions = promotions;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Promotion> filtered = _promotions;

    // Apply status filter
    if (_filterStatus == 'active') {
      filtered = filtered.where((p) => p.isValid && p.isActive).toList();
    } else if (_filterStatus == 'inactive') {
      filtered = filtered.where((p) => !p.isActive).toList();
    } else if (_filterStatus == 'expired') {
      filtered = filtered.where((p) => !p.isValid && p.isActive).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.promotionName.toLowerCase().contains(query) ||
            (p.promoCode?.toLowerCase().contains(query) ?? false) ||
            (p.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    setState(() {
      _filteredPromotions = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Promotions - ${widget.store.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPromotions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading promotions...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading promotions',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPromotions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filters and Search
        _buildFilters(),
        
        // Summary
        _buildSummary(),
        
        // Promotions List
        Expanded(
          child: _filteredPromotions.isEmpty
              ? _buildEmptyState()
              : _buildPromotionsList(),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search promotions...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Inactive', 'inactive'),
                const SizedBox(width: 8),
                _buildFilterChip('Expired', 'expired'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
        _applyFilters();
      },
      selectedColor: const Color(0xFF0D47A1).withOpacity(0.2),
      checkmarkColor: const Color(0xFF0D47A1),
    );
  }

  Widget _buildSummary() {
    final activeCount = _promotions.where((p) => p.isValid && p.isActive).length;
    final inactiveCount = _promotions.where((p) => !p.isActive).length;
    final expiredCount = _promotions.where((p) => !p.isValid && p.isActive).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard('Total', '${_promotions.length}', Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard('Active', '$activeCount', Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard('Inactive', '$inactiveCount', Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard('Expired', '$expiredCount', Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No promotions found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _filterStatus != 'all'
                ? 'Try adjusting your filters'
                : 'No promotions have been created for this store',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPromotions.length,
      itemBuilder: (context, index) {
        final promotion = _filteredPromotions[index];
        return _buildPromotionCard(promotion);
      },
    );
  }

  Widget _buildPromotionCard(Promotion promotion) {
    final dateFormat = DateFormat('dd MMM yyyy');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: promotion.statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.local_offer,
            color: promotion.statusColor,
            size: 24,
          ),
        ),
        title: Text(
          promotion.promotionName,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: promotion.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    promotion.statusText,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: promotion.statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  promotion.discountText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(promotion.startDate)} - ${dateFormat.format(promotion.endDate)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Type', promotion.promotionType),
                if (promotion.promoCode != null)
                  _buildDetailRow('Promo Code', promotion.promoCode!),
                _buildDetailRow('Applicable On', promotion.applicableOn),
                if (promotion.minOrderAmount > 0)
                  _buildDetailRow('Min Order', '₹${promotion.minOrderAmount.toStringAsFixed(0)}'),
                if (promotion.maxDiscountAmount != null)
                  _buildDetailRow('Max Discount', '₹${promotion.maxDiscountAmount!.toStringAsFixed(0)}'),
                if (promotion.usageLimitPerUser != null)
                  _buildDetailRow('Per User Limit', '${promotion.usageLimitPerUser}'),
                if (promotion.totalUsageLimit != null)
                  _buildDetailRow('Total Limit', '${promotion.totalUsageLimit}'),
                if (promotion.description != null && promotion.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Description',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promotion.description!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                if (promotion.termsConditions != null && promotion.termsConditions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Terms & Conditions',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promotion.termsConditions!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

