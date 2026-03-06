import 'dart:async';
import 'package:sixam_mart_delivery/features/home/widgets/count_card_widget.dart';
import 'package:sixam_mart_delivery/features/home/widgets/earning_widget.dart';
import 'package:sixam_mart_delivery/features/home/widgets/order_count_card_widget.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/refer_and_earn/screens/refer_and_earn_screen.dart';
import 'package:sixam_mart_delivery/features/refer_and_earn/widgets/refer_bottom_sheet.dart';
import 'package:sixam_mart_delivery/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/helper/price_converter_helper.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_app_bar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_button_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/order_shimmer_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/order_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/title_widget.dart';
import 'package:sixam_mart_delivery/features/order/widgets/order_requset_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class OrderRequestScreen extends StatefulWidget {
  final Function onTap;
  const OrderRequestScreen({super.key, required this.onTap});

  @override
  OrderRequestScreenState createState() => OrderRequestScreenState();
}

class OrderRequestScreenState extends State<OrderRequestScreen> {
  Timer? _timer;
  bool _isEarningsExpanded = true;
  bool _isOrderStatsExpanded = true;
  bool _isNotificationPermissionGranted = true;
  bool _isBatteryOptimizationGranted = true;

  @override
  initState() {
    super.initState();

    if (Get.find<ProfileController>().profileModel == null) {
      Get.find<ProfileController>().getProfile();
    }

    Get.find<OrderController>().getLatestOrders();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      Get.find<OrderController>().getLatestOrders();
    });

    _checkPermission();
  }

  Future<void> _checkPermission() async {
    var notificationStatus = await Permission.notification.status;
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    setState(() {
      _isNotificationPermissionGranted =
          !notificationStatus.isDenied &&
          !notificationStatus.isPermanentlyDenied;
      _isBatteryOptimizationGranted = !batteryStatus.isDenied;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: 'tootli_requests'.tr,
        isBackButtonExist: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Get.find<OrderController>().getLatestOrders();
          await Get.find<ProfileController>().getProfile();
          await Get.find<OrderController>().getRunningOrders(1);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (!_isNotificationPermissionGranted)
                    _permissionWarning(
                      isBatteryPermission: false,
                      onTap: () async {
                        await Permission.notification.request();
                        _checkPermission();
                      },
                      closeOnTap: () {
                        setState(() => _isNotificationPermissionGranted = true);
                      },
                    ),

                  if (!_isBatteryOptimizationGranted)
                    _permissionWarning(
                      isBatteryPermission: true,
                      onTap: () async {
                        await Permission.ignoreBatteryOptimizations.request();
                        _checkPermission();
                      },
                      closeOnTap: () {
                        setState(() => _isBatteryOptimizationGranted = true);
                      },
                    ),

                  GetBuilder<ProfileController>(
                    builder: (profileController) {
                      return GetBuilder<OrderController>(
                        builder: (orderController) {
                          bool isPayable =
                              profileController.profileModel != null &&
                              profileController
                                      .profileModel!
                                      .showPayNowButton ==
                                  true;
                          bool showReferAndEarn =
                              profileController.profileModel != null &&
                              profileController.profileModel!.earnings == 1 &&
                              (Get.find<SplashController>()
                                          .configModel
                                          ?.dmReferralData
                                          ?.dmReferalStatus ==
                                      true ||
                                  (profileController
                                              .profileModel
                                              ?.referalEarning !=
                                          null &&
                                      profileController
                                              .profileModel!
                                              .referalEarning! >
                                          0));

                          bool hasActiveOrder =
                              orderController.currentOrderList == null ||
                              orderController.currentOrderList!.isNotEmpty;
                          bool hasMoreOrder =
                              orderController.currentOrderList != null &&
                              orderController.currentOrderList!.length > 1;

                          return Column(
                            children: [
                              // Active Order Section
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Dimensions.paddingSizeDefault,
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(
                                      height: Dimensions.paddingSizeSmall,
                                    ),
                                    hasActiveOrder
                                        ? TitleWidget(
                                            title: 'active_order'.tr,
                                            showOrderCount: true,
                                            orderCount:
                                                orderController
                                                    .currentOrderList
                                                    ?.length ??
                                                0,
                                            onTap: hasMoreOrder
                                                ? () => widget.onTap()
                                                : null,
                                          )
                                        : const SizedBox(),
                                    SizedBox(
                                      height: hasActiveOrder
                                          ? Dimensions.paddingSizeExtraSmall
                                          : 0,
                                    ),
                                    orderController.currentOrderList == null
                                        ? OrderShimmerWidget(
                                            isEnabled:
                                                orderController
                                                    .currentOrderList ==
                                                null,
                                          )
                                        : orderController
                                              .currentOrderList!
                                              .isNotEmpty
                                        ? OrderWidget(
                                            orderModel: orderController
                                                .currentOrderList![0],
                                            isRunningOrder: true,
                                            orderIndex: 0,
                                            cardWidth: context.width * 0.9,
                                          )
                                        : const SizedBox(),
                                    SizedBox(
                                      height: hasActiveOrder
                                          ? Dimensions.paddingSizeDefault
                                          : 0,
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Dimensions.paddingSizeDefault,
                                  vertical: Dimensions.paddingSizeSmall,
                                ),
                                child: Column(
                                  children: [
                                    // Earnings Section (Collapsible)
                                    if (profileController.profileModel !=
                                            null &&
                                        profileController
                                                .profileModel!
                                                .earnings ==
                                            1)
                                      Column(
                                        children: [
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _isEarningsExpanded =
                                                  !_isEarningsExpanded,
                                            ),
                                            child: TitleWidget(
                                              title: 'earnings'.tr,
                                              onTap: () => setState(
                                                () => _isEarningsExpanded =
                                                    !_isEarningsExpanded,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: Dimensions.paddingSizeSmall,
                                          ),
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                            child: _isEarningsExpanded
                                                ? Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          Dimensions
                                                              .paddingSizeLarge,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusDefault,
                                                          ),
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const SizedBox(
                                                              width: Dimensions
                                                                  .paddingSizeSmall,
                                                            ),
                                                            Container(
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .cardColor
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      50,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    Dimensions
                                                                        .paddingSizeSmall,
                                                                  ),
                                                              child:
                                                                  Image.asset(
                                                                    Images
                                                                        .wallet,
                                                                    width: 40,
                                                                    height: 40,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              width: Dimensions
                                                                  .paddingSizeLarge,
                                                            ),
                                                            Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'balance'.tr,
                                                                  style: robotoMedium.copyWith(
                                                                    fontSize:
                                                                        Dimensions
                                                                            .fontSizeSmall,
                                                                    color:
                                                                        Theme.of(
                                                                          context,
                                                                        ).cardColor.withValues(
                                                                          alpha:
                                                                              0.9,
                                                                        ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: Dimensions
                                                                      .paddingSizeExtraSmall,
                                                                ),
                                                                Text(
                                                                  PriceConverterHelper.convertPrice(
                                                                    profileController
                                                                        .profileModel!
                                                                        .balance,
                                                                  ),
                                                                  style: robotoBold.copyWith(
                                                                    fontSize:
                                                                        24,
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).cardColor,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: Dimensions
                                                              .paddingSizeLarge,
                                                        ),
                                                        Row(
                                                          children: [
                                                            EarningWidget(
                                                              title: 'today'.tr,
                                                              amount: profileController
                                                                  .profileModel
                                                                  ?.todaysEarning,
                                                            ),
                                                            Container(
                                                              height: 30,
                                                              width: 1,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .cardColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.8,
                                                                      ),
                                                            ),
                                                            EarningWidget(
                                                              title: 'this_week'
                                                                  .tr,
                                                              amount: profileController
                                                                  .profileModel
                                                                  ?.thisWeekEarning,
                                                            ),
                                                            Container(
                                                              height: 30,
                                                              width: 1,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .cardColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.8,
                                                                      ),
                                                            ),
                                                            EarningWidget(
                                                              title:
                                                                  'this_month'
                                                                      .tr,
                                                              amount: profileController
                                                                  .profileModel
                                                                  ?.thisMonthEarning,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          Dimensions
                                                              .paddingSizeSmall,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusDefault,
                                                          ),
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Image.asset(
                                                              Images.wallet,
                                                              width: 25,
                                                              height: 25,
                                                              color: Theme.of(
                                                                context,
                                                              ).cardColor,
                                                            ),
                                                            const SizedBox(
                                                              width: Dimensions
                                                                  .paddingSizeSmall,
                                                            ),
                                                            Text(
                                                              'balance'.tr,
                                                              style: robotoMedium.copyWith(
                                                                fontSize: Dimensions
                                                                    .fontSizeDefault,
                                                                color: Theme.of(
                                                                  context,
                                                                ).cardColor,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Text(
                                                          PriceConverterHelper.convertPrice(
                                                            profileController
                                                                .profileModel!
                                                                .balance,
                                                          ),
                                                          style: robotoBold.copyWith(
                                                            fontSize: Dimensions
                                                                .fontSizeDefault,
                                                            color: Theme.of(
                                                              context,
                                                            ).cardColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(
                                            height:
                                                Dimensions.paddingSizeDefault,
                                          ),
                                        ],
                                      ),

                                    // Order Statistics (Collapsible)
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _isOrderStatsExpanded =
                                            !_isOrderStatsExpanded,
                                      ),
                                      child: TitleWidget(
                                        title: 'orders'.tr,
                                        onTap: () => setState(
                                          () => _isOrderStatsExpanded =
                                              !_isOrderStatsExpanded,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: Dimensions.paddingSizeExtraSmall,
                                    ),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: _isOrderStatsExpanded
                                          ? ((profileController.profileModel !=
                                                        null &&
                                                    profileController
                                                            .profileModel!
                                                            .earnings ==
                                                        1)
                                                ? Row(
                                                    children: [
                                                      OrderCountCardWidget(
                                                        title:
                                                            'todays_orders'.tr,
                                                        value: profileController
                                                            .profileModel
                                                            ?.todaysOrderCount
                                                            .toString(),
                                                      ),
                                                      const SizedBox(
                                                        width: Dimensions
                                                            .paddingSizeDefault,
                                                      ),
                                                      OrderCountCardWidget(
                                                        title:
                                                            'this_week_orders'
                                                                .tr,
                                                        value: profileController
                                                            .profileModel
                                                            ?.thisWeekOrderCount
                                                            .toString(),
                                                      ),
                                                      const SizedBox(
                                                        width: Dimensions
                                                            .paddingSizeDefault,
                                                      ),
                                                      OrderCountCardWidget(
                                                        title:
                                                            'total_orders'.tr,
                                                        value: profileController
                                                            .profileModel
                                                            ?.orderCount
                                                            .toString(),
                                                      ),
                                                    ],
                                                  )
                                                : Column(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: CountCardWidget(
                                                              title:
                                                                  'todays_orders'
                                                                      .tr,
                                                              backgroundColor:
                                                                  const Color(
                                                                    0xffE5EAFF,
                                                                  ),
                                                              height: 180,
                                                              value: profileController
                                                                  .profileModel
                                                                  ?.todaysOrderCount
                                                                  .toString(),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: Dimensions
                                                                .paddingSizeSmall,
                                                          ),
                                                          Expanded(
                                                            child: CountCardWidget(
                                                              title:
                                                                  'this_week_orders'
                                                                      .tr,
                                                              backgroundColor:
                                                                  const Color(
                                                                    0xffE84E50,
                                                                  ).withValues(
                                                                    alpha: 0.2,
                                                                  ),
                                                              height: 180,
                                                              value: profileController
                                                                  .profileModel
                                                                  ?.thisWeekOrderCount
                                                                  .toString(),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                        height: Dimensions
                                                            .paddingSizeSmall,
                                                      ),
                                                      CountCardWidget(
                                                        title:
                                                            'total_orders'.tr,
                                                        backgroundColor:
                                                            const Color(
                                                              0xffE1FFD8,
                                                            ),
                                                        height: 140,
                                                        value: profileController
                                                            .profileModel
                                                            ?.orderCount
                                                            .toString(),
                                                      ),
                                                    ],
                                                  ))
                                          : Container(
                                              padding: const EdgeInsets.all(
                                                Dimensions.paddingSizeSmall,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      Dimensions.radiusDefault,
                                                    ),
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .primaryColor
                                                      .withValues(alpha: 0.5),
                                                ),
                                                color: Theme.of(context)
                                                    .primaryColor
                                                    .withValues(alpha: 0.05),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceAround,
                                                children: [
                                                  Text(
                                                    '${'todays_orders'.tr}: ${profileController.profileModel?.todaysOrderCount ?? 0}',
                                                    style: robotoMedium
                                                        .copyWith(
                                                          fontSize: Dimensions
                                                              .fontSizeSmall,
                                                        ),
                                                  ),
                                                  Text(
                                                    '${'total_orders'.tr}: ${profileController.profileModel?.orderCount ?? 0}',
                                                    style: robotoMedium
                                                        .copyWith(
                                                          fontSize: Dimensions
                                                              .fontSizeSmall,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                    const SizedBox(
                                      height: Dimensions.paddingSizeLarge,
                                    ),

                                    // Cash In Hand
                                    profileController.profileModel != null &&
                                            profileController
                                                    .profileModel!
                                                    .cashInHands! >
                                                0
                                        ? Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusDefault,
                                                  ),
                                              border: Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).disabledColor,
                                                width: 0.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.05),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.all(
                                              Dimensions.paddingSizeLarge,
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .primaryColor
                                                        .withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: Image.asset(
                                                    Images.payMoney,
                                                    height: 30,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: Dimensions
                                                      .paddingSizeSmall,
                                                ),
                                                Text(
                                                  PriceConverterHelper.convertPrice(
                                                    profileController
                                                        .profileModel!
                                                        .cashInHands,
                                                  ),
                                                  style: robotoBold.copyWith(
                                                    fontSize: Dimensions
                                                        .fontSizeOverLarge,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: Dimensions
                                                      .paddingSizeSmall,
                                                ),
                                                Text(
                                                  'cash_in_your_hand'.tr,
                                                  style: robotoRegular.copyWith(
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color!
                                                        .withValues(alpha: 0.7),
                                                  ),
                                                ),
                                                if (isPayable)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: Dimensions
                                                              .paddingSizeDefault,
                                                        ),
                                                    child: CustomButtonWidget(
                                                      width: 100,
                                                      height: 35,
                                                      buttonText: 'pay_now'.tr,
                                                      onPressed: () => Get.toNamed(
                                                        RouteHelper.getMyAccountRoute(),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          )
                                        : const SizedBox(),

                                    if (showReferAndEarn)
                                      InkWell(
                                        onTap: () => Get.to(
                                          () => const ReferAndEarnScreen(),
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            top: Dimensions.paddingSizeLarge,
                                          ),
                                          padding: const EdgeInsets.all(
                                            Dimensions.paddingSizeDefault,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              Dimensions.radiusDefault,
                                            ),
                                            color: Theme.of(context)
                                                .disabledColor
                                                .withValues(alpha: 0.1),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'invite_and_get_rewards'
                                                          .tr,
                                                      style: robotoBold
                                                          .copyWith(
                                                            fontSize: Dimensions
                                                                .fontSizeLarge,
                                                          ),
                                                    ),
                                                    const SizedBox(
                                                      height: Dimensions
                                                          .paddingSizeSmall,
                                                    ),
                                                    CustomButtonWidget(
                                                      height: 30,
                                                      width: 120,
                                                      buttonText:
                                                          'invite_friends'.tr,
                                                      fontSize: Dimensions
                                                          .fontSizeSmall,
                                                      onPressed: () =>
                                                          Get.bottomSheet(
                                                            const ReferBottomSheet(),
                                                            isScrollControlled:
                                                                true,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Image.asset(
                                                Images.shareImage,
                                                width: 80,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(
                                      height: Dimensions.paddingSizeDefault,
                                    ),
                                    TitleWidget(title: 'new_requests'.tr),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            GetBuilder<OrderController>(
              builder: (orderController) {
                return orderController.latestOrderList != null
                    ? orderController.latestOrderList!.isNotEmpty
                          ? SliverPadding(
                              padding: const EdgeInsets.all(
                                Dimensions.paddingSizeSmall,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    return OrderRequestWidget(
                                      orderModel: orderController
                                          .latestOrderList![index],
                                      index: index,
                                      onTap: widget.onTap,
                                    );
                                  },
                                  childCount:
                                      orderController.latestOrderList!.length,
                                ),
                              ),
                            )
                          : SliverFillRemaining(
                              child: Center(
                                child: Text('no_order_request_available'.tr),
                              ),
                            )
                    : const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionWarning({
    required bool isBatteryPermission,
    required Function() onTap,
    required Function() closeOnTap,
  }) {
    return GetPlatform.isAndroid
        ? Container(
            width: double.infinity,
            color: Theme.of(
              context,
            ).textTheme.bodyLarge!.color?.withValues(alpha: 0.7),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: Row(
                  children: [
                    if (isBatteryPermission)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Image.asset(
                          Images.allertIcon,
                          height: 20,
                          width: 20,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        isBatteryPermission
                            ? 'for_better_performance_allow_notification_to_run_in_background'
                                  .tr
                            : 'notification_is_disabled_please_allow_notification'
                                  .tr,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_circle_right_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox();
  }
}
