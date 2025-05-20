import 'package:flutter/material.dart';

/// A modern, logistics-themed card for services display
class LogisticsServiceCard extends StatelessWidget {
  final String title;
  final String type;
  final String region;
  final double price;
  final bool isActive;
  final List<String> imageUrls;
  final double rating;
  final int reviewCount;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  
  const LogisticsServiceCard({
    super.key,
    required this.title,
    required this.type,
    required this.region,
    required this.price,
    required this.isActive,
    required this.imageUrls,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) {
    // Define colors based on service type
    final Color typeColor = type == 'تخزين' 
      ? Colors.teal // Teal for storage
      : Color(0xFFFF6D00); // Orange for transport
      
    final IconData typeIcon = type == 'تخزين'
      ? Icons.warehouse_rounded
      : Icons.local_shipping_rounded;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            typeColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 2,
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image slider
            _buildImageSlider(typeColor, typeIcon),
            
            // Card content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with icon
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Service details row
                  Row(
                    children: [
                      // Price (for storage only)
                      if (type == 'تخزين')
                        _buildInfoChip(
                          icon: Icons.payments_rounded,
                          label: '${price.toStringAsFixed(0)} دج',
                          color: typeColor,
                          hasBorder: true
                        ),

                      if (type == 'تخزين') SizedBox(width: 8),
                        
                      // Region
                      _buildInfoChip(
                        icon: Icons.location_on,
                        label: region,
                        color: Colors.grey[700]!,
                      ),
                      
                      Spacer(),
                      
                      // Status badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive 
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                              ? Colors.green.withOpacity(0.3)
                              : Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive ? Icons.check_circle : Icons.cancel,
                              color: isActive ? Colors.green : Colors.red,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              isActive ? 'نشط' : 'غير نشط',
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Rating
                  if (rating > 0)
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating.floor()
                              ? Icons.star
                              : index < rating.ceil() && index >= rating.floor()
                                ? Icons.star_half
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                        SizedBox(width: 8),
                        Text(
                          '${rating.toStringAsFixed(1)} (${reviewCount.toString()})',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  
                  if (rating > 0) SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(
                        icon: Icons.edit_rounded,
                        label: 'تعديل',
                        color: Color(0xFF3B82F6),
                        onTap: onEdit,
                      ),
                      _buildActionButton(
                        icon: isActive 
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                        label: isActive ? 'تعطيل' : 'تفعيل',
                        color: isActive ? Colors.orange : Colors.green,
                        onTap: onToggleStatus,
                      ),
                      _buildActionButton(
                        icon: Icons.delete_rounded,
                        label: 'حذف',
                        color: Colors.red,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSlider(Color typeColor, IconData typeIcon) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // Image carousel - sample implementation
          // In a real app, use PageView.builder with actual images
          imageUrls.isNotEmpty
            ? PageView.builder(
                itemCount: imageUrls.length,
                itemBuilder: (context, index) {
                  return Hero(
                    tag: 'service_image_$index',
                    child: Image.network(
                      imageUrls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder(typeColor, typeIcon);
                      },
                    ),
                  );
                },
              )
            : _buildPlaceholder(typeColor, typeIcon),
              
          // Type badge
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(typeIcon, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    type,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlaceholder(Color typeColor, IconData typeIcon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withOpacity(0.05),
            typeColor.withOpacity(0.15),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              typeIcon,
              size: 60,
              color: typeColor.withOpacity(0.4),
            ),
            SizedBox(height: 10),
            Text(
              type == 'تخزين' ? 'خدمة تخزين' : 'خدمة نقل',
              style: TextStyle(
                color: typeColor.withOpacity(0.7),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    bool hasBorder = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: hasBorder 
          ? Border.all(color: color.withOpacity(0.3), width: 1)
          : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
