import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:bilink/services/service_request_notification_service.dart';
import 'package:bilink/screens/service_details_screen.dart';

class AcceptedServiceRequestsDialog extends StatelessWidget {
  final List<DocumentSnapshot> requests;
  final VoidCallback onClose;

  const AcceptedServiceRequestsDialog({
    super.key,
    required this.requests,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Group requests by service type
    Map<String, List<DocumentSnapshot>> groupedRequests = {};
    
    for (var request in requests) {
      final data = request.data() as Map<String, dynamic>;
      final String serviceType = data['serviceType'] ?? 'تخزين';
      
      if (!groupedRequests.containsKey(serviceType)) {
        groupedRequests[serviceType] = [];
      }
      
      groupedRequests[serviceType]!.add(request);
    }
    
    // Sort keys to ensure consistent order (transport first, then storage)
    final sortedKeys = groupedRequests.keys.toList()
      ..sort((a, b) => a == 'نقل' ? -1 : 1);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الطلبات المقبولة حديثاً',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: requests.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('لا توجد طلبات مقبولة حديثاً'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: sortedKeys.length,
                      itemBuilder: (context, index) {
                        final serviceType = sortedKeys[index];
                        final typeRequests = groupedRequests[serviceType]!;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category header
                            Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: serviceType == 'نقل' 
                                    ? Colors.orange.withOpacity(0.1) 
                                    : Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    serviceType == 'نقل'
                                        ? Icons.local_shipping_outlined
                                        : Icons.inventory_2_outlined,
                                    color: serviceType == 'نقل'
                                        ? Colors.orange
                                        : Colors.teal,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    serviceType == 'نقل' ? 'طلبات النقل' : 'طلبات التخزين',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: serviceType == 'نقل'
                                          ? Colors.orange.shade800
                                          : Colors.teal.shade800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: serviceType == 'نقل'
                                          ? Colors.orange.shade800
                                          : Colors.teal.shade800,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${typeRequests.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Requests list for this category
                            ...typeRequests.map((request) => _buildRequestItem(context, request)),
                          ],
                        );
                      },
                    ),
            ),
            if (requests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Mark all as read and close dialog
                      final service = ServiceRequestNotificationService();
                      await service.markAllRequestsAsNotified();
                      onClose();
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF0B3D91), // Primary color from the client_interface.dart
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('تحديد الكل كمقروء'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRequestItem(BuildContext context, DocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    
    final String serviceName = data['serviceName'] ?? 'خدمة';
    final String providerName = data['providerName'] ?? 'مزود الخدمة';
    final String serviceType = data['serviceType'] ?? 'تخزين';
    final Timestamp? responseDate = data['responseDate'] as Timestamp?;
    
    final String formattedDate = responseDate != null
        ? DateFormat('yyyy/MM/dd hh:mm a').format(responseDate.toDate())
        : '';
        
    return InkWell(
      onTap: () async {
        // Mark this specific request as notified when tapped
        final service = ServiceRequestNotificationService();
        await service.markRequestAsNotified(request.id);
        
        Navigator.pop(context); // Close dialog
        String serviceId = data['serviceId'] ?? '';
        if (serviceId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailsScreen(serviceId: serviceId),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: data['isClientNotified'] == true 
              ? Colors.grey.withOpacity(0.1) 
              : Colors.yellow.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: serviceType == 'نقل'
                ? Colors.orange.withOpacity(0.3)
                : Colors.teal.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  serviceType == 'نقل'
                      ? Icons.local_shipping_outlined
                      : Icons.inventory_2_outlined,
                  color: serviceType == 'نقل'
                      ? Colors.orange
                      : Colors.teal,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'تمت الموافقة على طلب $serviceName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'من قبل: $providerName',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                // Status indicator for new notifications
                if (data['isClientNotified'] != true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'جديد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
