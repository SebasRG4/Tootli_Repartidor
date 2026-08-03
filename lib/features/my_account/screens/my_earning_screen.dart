import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/common/widgets/filter_bottom_sheet_widget.dart';
import 'package:sixam_mart_delivery/features/my_account/controllers/my_account_controller.dart';
import 'package:sixam_mart_delivery/features/my_account/widgets/reports/loyalty_view_widget.dart';
import 'package:sixam_mart_delivery/features/my_account/widgets/reports/order_view_widget.dart';
import 'package:sixam_mart_delivery/features/my_account/widgets/reports/refer_view_widget.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class MyEarningScreen extends StatefulWidget {
  const MyEarningScreen({super.key});

  @override
  State<MyEarningScreen> createState() => _MyEarningScreenState();
}

class _MyEarningScreenState extends State<MyEarningScreen> {
  final ScrollController scrollController = ScrollController();
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();

    Get.find<MyAccountController>().resetEarningFilter(isUpdate: false);
    Get.find<MyAccountController>().setOffset(1);
    Get.find<MyAccountController>().setEarningType('all_types_earning');
    _getFilteredEarnings();

    scrollController.addListener(() {
      if (scrollController.position.pixels == scrollController.position.maxScrollExtent
          && Get.find<MyAccountController>().earningList != null
          && !Get.find<MyAccountController>().isLoading) {
        int pageSize = (Get.find<MyAccountController>().pageSize! / 10).ceil();
        if (Get.find<MyAccountController>().offset < pageSize) {
          Get.find<MyAccountController>().setOffset(Get.find<MyAccountController>().offset + 1);
          debugPrint('end of the page');
          Get.find<MyAccountController>().showBottomLoader();
          _getFilteredEarnings();
        }
      }
    });
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
    Get.find<MyAccountController>().resetEarningFilter();
    Get.find<MyAccountController>().setOffset(1);
    Get.find<MyAccountController>().setEarningType('all_types_earning');
    _getFilteredEarnings();
  }

  static const int _minTabTitleLengthForFullLabelHint = 15;

  void _showFullTabTitleIfLong(BuildContext context, String title) {
    if (title.length < _minTabTitleLengthForFullLabelHint) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(title, textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  void _getFilteredEarnings({bool fromFilter = false}) {
    if (_selectedTabIndex == 0) {
      Get.find<MyAccountController>().getEarningReport(
        offset: Get.find<MyAccountController>().offset.toString(),
        startDate: Get.find<MyAccountController>().from,
        endDate: Get.find<MyAccountController>().to,
        type: Get.find<MyAccountController>().selectedEarningType,
        dateRange: Get.find<MyAccountController>().selectedDateType,
        fromFilter: fromFilter,
      );
    } else if (_selectedTabIndex == 1) {
      Get.find<MyAccountController>().getReferralReport(
        offset: Get.find<MyAccountController>().offset.toString(),
        startDate: Get.find<MyAccountController>().from,
        endDate: Get.find<MyAccountController>().to,
        type: Get.find<MyAccountController>().selectedEarningType,
        fromFilter: fromFilter,
        dateRange: Get.find<MyAccountController>().selectedDateType,
      );
    } else {
      Get.find<MyAccountController>().getLoyaltyReport(
        offset: Get.find<MyAccountController>().offset.toString(),
        startDate: Get.find<MyAccountController>().from,
        endDate: Get.find<MyAccountController>().to,
        type: Get.find<MyAccountController>().selectedEarningType,
        fromFilter: fromFilter,
        dateRange: Get.find<MyAccountController>().selectedDateType,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyAccountController>(builder: (myAccountController) {
      double totalEarning = (myAccountController.earningReportModel?.totalDeliveryCharge ?? 0)
          + (myAccountController.earningReportModel?.totalDmTips ?? 0)
          + (myAccountController.earningReportModel?.totalReferal ?? 0)
          + (myAccountController.earningReportModel?.totalLoyaltyPointEarning ?? 0);

      return Scaffold(
        backgroundColor: const Color(0xFF0C0E12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C0E12),
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F161E),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 22),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
          centerTitle: true,
          title: Text(
            'my_earning'.tr,
            style: robotoBold.copyWith(color: Colors.white, fontSize: 18),
          ),
          actions: [
            // Download Button
            Container(
              height: 38,
              width: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF0F161E),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: !myAccountController.downloadLoading!
                    ? const Icon(Icons.download_rounded, color: Color(0xFF5EC44B), size: 18)
                    : const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Color(0xFF5EC44B), strokeWidth: 2),
                      ),
                onPressed: () {
                  myAccountController.downloadEarningInvoice(
                    dmId: Get.find<ProfileController>().profileModel!.id!,
                    earningType: _selectedTabIndex == 0 ? null : _selectedTabIndex == 1 ? 'referral_earning' : 'loyalty_earning',
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            // Filter Button
            Container(
              height: 38,
              width: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF0F161E),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.tune,
                  color: myAccountController.isFiltered ? Colors.redAccent : const Color(0xFF5EC44B),
                  size: 18,
                ),
                onPressed: () {
                  Get.bottomSheet(FilterBottomSheetWidget(
                    startDate: myAccountController.from,
                    endDate: myAccountController.to,
                    type: myAccountController.selectedDateType,
                    onApply: (dateRange, startDate, endDate) async {
                      if (startDate != null && endDate != null) {
                        await myAccountController.setDateRange(from: startDate, to: endDate);
                      }
                      if (dateRange != null) {
                        myAccountController.setDateType(dateRange);
                        _getFilteredEarnings(fromFilter: true);
                      }
                    },
                    onReset: () {
                      myAccountController.resetEarningFilter();
                      _getFilteredEarnings();
                    },
                  ));
                },
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: CustomScrollView(
          controller: scrollController,
          slivers: [
            // Earning Cards Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                  vertical: Dimensions.paddingSizeSmall,
                ),
                child: SizedBox(
                  height: 155,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _earningCard(
                        context: context,
                        icon: Icons.business_center_outlined,
                        price: totalEarning,
                        title: 'total_earning'.tr,
                        subtitle: 'Total acumulado',
                      ),
                      _earningCard(
                        context: context,
                        icon: Icons.archive_outlined,
                        price: myAccountController.earningReportModel?.totalDeliveryCharge ?? 0,
                        title: 'delivery_fee_earned'.tr,
                        subtitle: 'Total por entregas',
                      ),
                      _earningCard(
                        context: context,
                        icon: Icons.volunteer_activism_outlined,
                        price: myAccountController.earningReportModel?.totalDmTips ?? 0,
                        title: 'delivery_tips_earned'.tr,
                        subtitle: 'Total por propinas',
                      ),
                      _earningCard(
                        context: context,
                        icon: Icons.people_outline,
                        price: myAccountController.earningReportModel?.totalReferal ?? 0,
                        title: 'referral'.tr,
                        subtitle: 'Total por referidos',
                      ),
                      _earningCard(
                        context: context,
                        icon: Icons.stars_outlined,
                        price: myAccountController.earningReportModel?.totalLoyaltyPointEarning ?? 0,
                        title: 'loyalty_point'.tr,
                        subtitle: 'Total por lealtad',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Earning Statement Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'earning_statement'.tr,
                        style: robotoBold.copyWith(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${myAccountController.pageSize ?? 0} ',
                            style: robotoBold.copyWith(color: const Color(0xFF5EC44B), fontSize: 14),
                          ),
                          TextSpan(
                            text: 'result_found'.tr,
                            style: robotoRegular.copyWith(color: Colors.white38, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: Dimensions.paddingSizeSmall),
            ),

            // Sticky Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                child: Container(
                  color: const Color(0xFF0C0E12),
                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141922),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.02), width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTab(
                            context: context,
                            title: 'order'.tr,
                            index: 0,
                            icon: Icons.shopping_bag_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildTab(
                            context: context,
                            title: 'referral'.tr,
                            index: 1,
                            icon: Icons.people_outline,
                          ),
                        ),
                        Expanded(
                          child: _buildTab(
                            context: context,
                            title: 'loyalty_point'.tr,
                            index: 2,
                            icon: Icons.stars_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: Dimensions.paddingSizeSmall),
            ),

            // Earnings List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              sliver: SliverToBoxAdapter(
                child: _selectedTabIndex == 0
                    ? OrderViewWidget(myAccountController: myAccountController)
                    : _selectedTabIndex == 1
                        ? ReferViewWidget(myAccountController: myAccountController)
                        : LoyaltyViewWidget(myAccountController: myAccountController),
              ),
            ),

            // Security Card at the bottom of the list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141922),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                  ),
                  child: Row(
                    children: [
                      // Shield icon in green circle
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5EC44B).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF5EC44B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tus ganancias están protegidas',
                              style: robotoBold.copyWith(color: Colors.white, fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Todas tus ganancias se procesan de forma segura y transparente.',
                              style: robotoRegular.copyWith(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Lock icon with checkmark
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5EC44B).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF5EC44B).withValues(alpha: 0.2), width: 0.8),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF5EC44B),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 30),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTab({
    required BuildContext context,
    required String title,
    required int index,
    required IconData icon,
  }) {
    final bool isSelected = _selectedTabIndex == index;
    return Semantics(
      label: title,
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () {
          if (index != _selectedTabIndex) {
            _onTabChanged(index);
          }
          _showFullTabTitleIfLong(context, title);
        },
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? const Color(0xFF1C281D) : Colors.transparent,
            border: isSelected ? Border.all(color: const Color(0xFF5EC44B).withValues(alpha: 0.2), width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF5EC44B) : Colors.white38,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: robotoMedium.copyWith(
                    color: isSelected ? const Color(0xFF5EC44B) : Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _earningCard({
    required BuildContext context,
    required IconData icon,
    required double price,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: const Color(0xFF141922),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Wave background
            Positioned.fill(
              child: CustomPaint(
                painter: EarningCardWavePainter(),
              ),
            ),
            // Card Content
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circular Green Icon Box
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5EC44B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF5EC44B),
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: robotoMedium.copyWith(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    PriceConverterHelper.convertPrice(price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: robotoBold.copyWith(color: const Color(0xFF5EC44B), fontSize: 22),
                  ),
                  const Spacer(),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: robotoRegular.copyWith(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wave CustomPainter
class EarningCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5EC44B).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final path = Path();
    path.moveTo(0, size.height * 0.82);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.72, size.width * 0.5, size.height * 0.86);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.94, size.width, size.height * 0.78);

    canvas.drawPath(path, paint);

    // Draw a glowing gradient underneath the wave line
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF5EC44B).withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(0, size.height * 0.7, size.width, size.height));

    final gradientPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(gradientPath, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Sticky Tab Bar Delegate
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return oldDelegate.maxExtent != 56 || oldDelegate.minExtent != 56 || child != oldDelegate.child;
  }
}
