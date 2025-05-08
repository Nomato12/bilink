import 'package:flutter/material.dart';

class ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final Function(String) onEdit;
  final Function(String, bool) onToggleStatus;
  final Function(String) onDelete;

  const ServiceCard({
    Key? key,
    required this.service,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extraer datos del servicio
    final String title = service['title'] ?? 'u062eu062fu0645u0629 u0628u062fu0648u0646 u0639u0646u0648u0627u0646';
    final String type = service['type'] ?? 'u063au064au0631 u0645u062du062fu062f';
    final String region = service['region'] ?? 'u063au064au0631 u0645u062du062fu062f';
    final double price = service['price'] ?? 0.0;
    final bool isActive = service['isActive'] ?? true;
    final List<dynamic> imageUrls = service['imageUrls'] ?? [];
    final double rating = service['rating'] ?? 0.0;
    final int reviewCount = service['reviewCount'] ?? 0;
    final String currency = service['currency'] ?? 'u062fu064au0646u0627u0631 u062cu0632u0627u0626u0631u064a';
    final String description = service['description'] ?? '';
    final String serviceId = service['id'] ?? '';

    // Colores segu00fan el tipo de servicio
    final Color serviceColor = type == 'u062au062eu0632u064au0646' 
        ? Color(0xFF3498DB) // Azul para almacenamiento
        : Color(0xFFE67E22); // Naranja para transporte
    
    // Icono segu00fan el tipo de servicio
    final IconData serviceIcon = type == 'u062au062eu0632u064au0646' 
        ? Icons.warehouse 
        : Icons.local_shipping;

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: serviceColor.withOpacity(0.2),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del servicio con indicadores
            Stack(
              children: [
                // Imagen del servicio
                Container(
                  height: 180,
                  width: double.infinity,
                  child: imageUrls.isNotEmpty
                      ? Image.network(
                          imageUrls[0],
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              width: double.infinity,
                              color: serviceColor.withOpacity(0.2),
                              child: Icon(
                                serviceIcon,
                                size: 60,
                                color: serviceColor,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: serviceColor.withOpacity(0.2),
                          child: Center(
                            child: Icon(
                              serviceIcon,
                              size: 60,
                              color: serviceColor,
                            ),
                          ),
                        ),
                ),
                
                // Indicador de estado (activo/inactivo)
                Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.cancel,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          isActive ? 'u0646u0634u0637' : 'u063au064au0631 u0646u0634u0637',
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
                
                // Tipo de servicio
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          serviceIcon,
                          color: serviceColor,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          type,
                          style: TextStyle(
                            color: serviceColor,
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
            
            // Informaciu00f3n del servicio
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tu00edtulo del servicio y precio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: serviceColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$price $currency',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: serviceColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Regiu00f3n
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 4),
                      Text(
                        region,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Valoraciu00f3n si estu00e1 disponible
                  if (rating > 0)
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < rating.floor()
                                  ? Icons.star
                                  : index < rating
                                      ? Icons.star_half
                                      : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '$rating ($reviewCount)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: 16),
                  
                  // Botones de acciu00f3n
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.edit,
                        label: 'u062au0639u062fu064au0644',
                        color: Color(0xFF3498DB),
                        onTap: () => onEdit(serviceId),
                      ),
                      _buildActionButton(
                        icon: isActive ? Icons.visibility_off : Icons.visibility,
                        label: isActive ? 'u0625u062eu0641u0627u0621' : 'u0625u0638u0647u0627u0631',
                        color: isActive ? Colors.orange : Colors.green,
                        onTap: () => onToggleStatus(serviceId, isActive),
                      ),
                      _buildActionButton(
                        icon: Icons.delete,
                        label: 'u062du0630u0641',
                        color: Colors.red,
                        onTap: () => onDelete(serviceId),
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

  // Botu00f3n de acciu00f3n en la tarjeta de servicio
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
