import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class V2HomeBottomPanelWidget extends StatefulWidget {
  final VoidCallback? onToggleConnection;

  const V2HomeBottomPanelWidget({
    super.key,
    this.onToggleConnection,
  });

  @override
  State<V2HomeBottomPanelWidget> createState() => _V2HomeBottomPanelWidgetState();
}

class _V2HomeBottomPanelWidgetState extends State<V2HomeBottomPanelWidget> {
  int _selectedModuleIndex = 0; // 0 = Viajes, 1 = Comida, 2 = Paquete, 3 = Ciudad

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileController>(
      builder: (profileController) {
        final profile = profileController.profileModel;
        final bool isOnline = profileController.isOnline;
        final bool isPending = profileController.isPendingRegistrationDashboard ||
            (profile != null && profile.identityVerified != 'approved');

        final String todayEarnings = PriceConverterHelper.convertPrice(
          profile?.todaysEarning ?? 0,
        );
        final int todayTrips = profile?.todaysOrderCount ?? 0;
        final String rating = (profile?.avgRating != null && profile!.avgRating! > 0)
            ? profile.avgRating!.toStringAsFixed(1)
            : '—';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de agarre / Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Fila de Estado: Desconectado · no recibe solicitudes
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isPending
                            ? const Color(0xFFD97706)
                            : (isOnline ? const Color(0xFF006837) : const Color(0xFF64748B)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: isPending
                                  ? 'En revisión'
                                  : (isOnline ? 'Conectado' : 'Desconectado'),
                              style: robotoBold.copyWith(
                                fontSize: 14,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            TextSpan(
                              text: isPending
                                  ? ' · tu cuenta está siendo validada'
                                  : (isOnline
                                      ? ' · listo para recibir solicitudes'
                                      : ' · no recibe solicitudes'),
                              style: robotoRegular.copyWith(
                                fontSize: 14,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tarjeta de Métricas ($ 0 | 0 Trips | Rating)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      // Ganancias de hoy
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              todayEarnings,
                              style: robotoBold.copyWith(
                                fontSize: 18,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ganancias de hoy',
                              style: robotoRegular.copyWith(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),

                      // Viajes
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$todayTrips',
                              style: robotoBold.copyWith(
                                fontSize: 18,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Viajes',
                              style: robotoRegular.copyWith(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),

                      // Calificación
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFEAB308)),
                                const SizedBox(width: 2),
                                Text(
                                  rating,
                                  style: robotoBold.copyWith(
                                    fontSize: 18,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Calificación',
                              style: robotoRegular.copyWith(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Selector de Módulos (Viajes | Comida | Paquete | Ciudad)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildModuleTab(0, 'Viajes', Icons.directions_car_rounded),
                      _buildModuleTab(1, 'Comida', Icons.restaurant_rounded),
                      _buildModuleTab(2, 'Paquete', Icons.inventory_2_rounded),
                      _buildModuleTab(3, 'Ciudad', Icons.apartment_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Botón Circular de Encendido / Conexión (Power Button Card)
                GestureDetector(
                  onTap: widget.onToggleConnection,
                  child: Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF006837) : const Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF006837).withValues(alpha: isOnline ? 0.3 : 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          size: 32,
                          color: isOnline ? Colors.white : const Color(0xFF006837),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModuleTab(int index, String label, IconData icon) {
    final bool isSelected = _selectedModuleIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedModuleIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF006837) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: isSelected
                    ? robotoBold.copyWith(fontSize: 12, color: const Color(0xFF006837))
                    : robotoMedium.copyWith(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
