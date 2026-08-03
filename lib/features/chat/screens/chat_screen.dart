import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/helper/pusher_service.dart';
import 'package:sixam_mart_delivery/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_delivery/features/chat/controllers/chat_controller.dart';
import 'package:sixam_mart_delivery/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_delivery/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart_delivery/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_delivery/features/chat/domain/models/conversation_model.dart';
import 'package:sixam_mart_delivery/helper/responsive_helper.dart';
import 'package:sixam_mart_delivery/helper/route_helper.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/images.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_image_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/paginated_list_view_widget.dart';
import 'package:sixam_mart_delivery/features/chat/widgets/message_bubble_widget.dart';
import 'package:geolocator/geolocator.dart';

class ChatScreen extends StatefulWidget {
  final NotificationBodyModel? notificationBody;
  final User? user;
  final int? conversationId;
  final bool fromNotification;
  const ChatScreen({super.key, required this.notificationBody, required this.user, this.conversationId, this.fromNotification = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputMessageController = TextEditingController();
  late bool _isLoggedIn;
  final FocusNode _inputMessageFocus = FocusNode();
  StreamSubscription<dynamic>? _chatSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  bool _isConnected = false;
  bool _isOtherTyping = false;          // indicador "escribiendo..."
  bool _showQuickReplies = false;        // barra de respuestas rápidas
  Timer? _typingTimer;                   // temporizador para ocultar "escribiendo"

  // Respuestas rápidas predefinidas para el repartidor
  static const List<String> _quickReplies = [
    'Estoy en camino 🚚',
    'Ya llegué a tu dirección 📍',
    'En unos minutos llego ⏰',
    '¿Cuál es tu número exacto de casa? 🏠',
    'Llame a la puerta pero nadie respondió 🚪',
    'Tu pedido está listo para entrega ✅',
    'Por favor ten el cambio listo 💵',
  ];
  
  bool _isChattingAllowed(ChatController chatController) {
    final String? chatType = widget.notificationBody?.type;
    if (chatType == 'admin' || chatType == AppConstants.admin) {
      return true; // Chats con Soporte/Administrador siempre permitidos
    }

    final orderController = Get.find<OrderController>();
    final runningOrders = orderController.currentOrderList ?? [];
    if (runningOrders.isEmpty) {
      return false; // Sin pedidos activos
    }

    int? myId = Get.find<ProfileController>().profileModel?.userInfoId ?? Get.find<ProfileController>().profileModel?.id;
    User? otherUser;
    if (chatController.messageModel != null && chatController.messageModel!.conversation != null) {
      otherUser = (chatController.messageModel!.conversation!.sender?.id == myId)
          ? chatController.messageModel!.conversation!.receiver
          : chatController.messageModel!.conversation!.sender;
    }

    // Identificar si es chat de cliente (user/customer) o de tienda (vendor)
    bool isCustomer = false;
    bool isVendor = false;

    if (widget.notificationBody?.customerId != null) {
      isCustomer = true;
    } else if (widget.notificationBody?.vendorId != null) {
      isVendor = true;
    } else if (chatType == AppConstants.user || chatType == AppConstants.customer) {
      isCustomer = true;
    } else if (chatType == AppConstants.vendor) {
      isVendor = true;
    } else if (otherUser != null) {
      if (otherUser.vendorId != null) {
        isVendor = true;
      } else {
        isCustomer = true;
      }
    }

    if (isCustomer) {
      final int? customerId = widget.notificationBody?.customerId ?? otherUser?.id;
      if (customerId == null) return false;
      return runningOrders.any((order) =>
        order.customer != null && order.customer!.id == customerId
      );
    } else if (isVendor) {
      final int? vendorId = widget.notificationBody?.vendorId ?? otherUser?.vendorId ?? otherUser?.id;
      if (vendorId == null) return false;
      return runningOrders.any((order) =>
        order.storeId == vendorId
      );
    }

    return false;
  }

  void _sendMessage(ChatController chatController) {
    if (!_isChattingAllowed(chatController)) {
      showCustomSnackBar('El chat ha finalizado ya que no tienes un pedido activo con este usuario.');
      return;
    }
    if(chatController.isSendButtonActive) {
      int totalAttachments = (chatController.chatImage?.length ?? 0) +
          (chatController.objFile?.length ?? 0) +
          (chatController.pickedVideoFile != null ? 1 : 0);

      if(totalAttachments > 3){
        showCustomSnackBar('you_do_not_send_more_then_3_photos'.tr);
      }else{
        chatController.sendMessage(
          message: _inputMessageController.text, notificationBody: widget.notificationBody, conversationId: widget.conversationId,
        ).then((success) {
          _inputMessageController.clear();
          if(success){
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
            // El backend ya devuelve el mensaje actualizado en sendMessage,
            // así que no necesitamos un refresh extra. Si Pusher confirma,
            // el stream lo actualizará automáticamente.
          }
        });
      }
    }else{
      showCustomSnackBar('write_somethings'.tr);
    }
  }

  @override
  void initState() {
    super.initState();

    _isLoggedIn = Get.find<AuthController>().isLoggedIn();
    _isConnected = PusherService.instance.isConnected;
    Get.find<ChatController>().getMessages(1, widget.notificationBody!, widget.user, widget.conversationId, firstLoad: true);
    
    // Reconectar WebSocket si se desconectó
    final profileModel = Get.find<ProfileController>().profileModel;
    if (profileModel != null) {
      PusherService.instance.reconnectIfNeeded(profileModel.id!);
    }

    // Escuchar cambios de estado de conexión
    _connectionSubscription = PusherService.instance.connectionStatusController.stream.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });

    String? prefill;
    if (Get.isRegistered<OrderController>()) {
      prefill = Get.find<OrderController>().consumeCancelSupportPrefill();
    }
    if (prefill != null && prefill.isNotEmpty) {
      _inputMessageController.text = prefill;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chatController = Get.find<ChatController>();
        if (!chatController.isSendButtonActive) {
          chatController.toggleSendButtonActivity();
        }
        _sendMessage(chatController);
      });
    } else if (widget.notificationBody?.type == AppConstants.admin &&
        widget.notificationBody?.orderId != null) {
      _inputMessageController.text =
          'Soporte para el pedido #${widget.notificationBody!.orderId}: ';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!Get.find<ChatController>().isSendButtonActive) {
          Get.find<ChatController>().toggleSendButtonActivity();
        }
      });
    }

    _chatSubscription = PusherService.instance.chatStreamController.stream.listen((data) {
      if (!mounted) return;
      try {
        // Detectar evento de "escribiendo"
        if (data is Map && data['event'] == 'ClientTyping') {
          final convId = data['conversation_id'];
          final int? receivedConvId = convId is int ? convId : int.tryParse(convId.toString());
          if (widget.conversationId == null || receivedConvId == widget.conversationId) {
            setState(() => _isOtherTyping = true);
            _typingTimer?.cancel();
            _typingTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _isOtherTyping = false);
            });
          }
          return;
        }

        final message = data is Map ? data['message'] : null;
        final convId = message is Map ? message['conversation_id'] : null;
        final senderId = message is Map ? message['sender_id'] : null;
        final int? receivedConvId = convId is int ? convId : (convId != null ? int.tryParse(convId.toString()) : null);
        final int? receivedSenderId = senderId is int ? senderId : (senderId != null ? int.tryParse(senderId.toString()) : null);
        final int? myId = Get.find<ProfileController>().profileModel?.id;

        if (widget.conversationId == null || receivedConvId == widget.conversationId) {
          if (mounted) setState(() => _isOtherTyping = false);
          if (receivedSenderId != null && myId != null && receivedSenderId != myId) {
            AudioPlayer().play(AssetSource('imessenge_recive.mp3'));
          }
          Get.find<ChatController>().getMessages(1, widget.notificationBody!, widget.user, widget.conversationId);
        }
      } catch (_) {
        Get.find<ChatController>().getMessages(1, widget.notificationBody!, widget.user, widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _connectionSubscription?.cancel();
    _typingTimer?.cancel();
    _scrollController.dispose();
    _inputMessageController.dispose();
    _inputMessageFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChatController>(builder: (chatController) {

      // String? baseUrl = '';
      // if(widget.notificationBody!.customerId != null || (widget.notificationBody!.conversationId != null && widget.notificationBody!.type == 'user')) {
      //   baseUrl = ImageType.customer_image_url.name;
      // }else {
      //   baseUrl = ImageType.store_image_url.name;
      // }

      int? myId = Get.find<ProfileController>().profileModel?.userInfoId ?? Get.find<ProfileController>().profileModel?.id;
      User? otherUser;
      if (chatController.messageModel != null && chatController.messageModel!.conversation != null) {
        otherUser = (chatController.messageModel!.conversation!.sender?.id == myId)
            ? chatController.messageModel!.conversation!.receiver
            : chatController.messageModel!.conversation!.sender;
      }

      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) async{
          if(widget.fromNotification && !didPop) {
            Get.offAllNamed(RouteHelper.getInitialRoute());
          }else {
            return;
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: GestureDetector(onTap: () {
              if(widget.fromNotification){
                Get.offAllNamed(RouteHelper.getInitialRoute());
              }else{
                Get.back();
              }
            },
              child: const Icon(Icons.arrow_back_ios_rounded),
            ),
            title: Row(children: [
              Container(width: 40, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(width: 2,color: Theme.of(context).cardColor),
                  color: Theme.of(context).cardColor,
                ),
                child: ClipOval(child: CustomImageWidget(
                  image: '${otherUser != null ? otherUser.imageFullUrl : chatController.messageModel?.conversation?.receiver?.imageFullUrl ?? ''}',
                  fit: BoxFit.cover, height: 40, width: 40,
                )),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  otherUser != null ? '${otherUser.fName ?? ''} ${otherUser.lName ?? ''}' : chatController.messageModel?.conversation?.receiver?.fName ?? 'receiver_name'.tr,
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge),
                ),
                Row(children: [
                  // Indicador de conexión en tiempo real
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? 'En línea' : 'Conectando...',
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeExtraSmall,
                      color: _isConnected ? Colors.green : Theme.of(context).disabledColor,
                    ),
                  ),
                ]),
              ]),
            ]),
            backgroundColor: Theme.of(context).cardColor,
            surfaceTintColor: Theme.of(context).cardColor,
            shadowColor: Theme.of(context).disabledColor.withValues(alpha: 0.5),
            elevation: 2,
          ),

          body: _isLoggedIn ? GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SafeArea(
              child: Center(
                child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Column(children: [

                  Expanded(child: chatController.messageModel != null ? chatController.messageModel!.messages!.isNotEmpty ? PaginatedListViewWidget(
                    scrollController: _scrollController,
                    totalSize: chatController.messageModel?.totalSize,
                    offset: chatController.messageModel?.offset,
                    showLoadingInUpper: true,
                    onPaginate: (int? offset) async => await chatController.getMessages(
                      offset!, widget.notificationBody!, widget.user, widget.conversationId,
                    ),
                    productView: Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: ClampingScrollPhysics(),
                        //shrinkWrap: true,
                        reverse: true,
                        itemCount: chatController.messageModel!.messages!.length,
                        itemBuilder: (context, index) {
                          return MessageBubbleWidget(
                            previousMessage: index == 0 ? null : chatController.messageModel?.messages?.elementAt(index-1),
                            message: chatController.messageModel!.messages![index],
                            nextMessage: index == (chatController.messageModel!.messages!.length - 1) ? null : chatController.messageModel?.messages?.elementAt(index+1),
                            user: chatController.messageModel!.conversation!.receiver,
                            sender: chatController.messageModel!.conversation!.sender,
                            userType: widget.notificationBody!.customerId != null || (widget.notificationBody!.conversationId != null && widget.notificationBody!.type == 'user')
                                ? AppConstants.user : AppConstants.vendor,
                          );
                        },
                      ),
                    ),
                  ) : const SizedBox() : const Center(child: CircularProgressIndicator())),

                  (chatController.messageModel != null) ? Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
                    ),
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                    child: !_isChattingAllowed(chatController)
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault, horizontal: Dimensions.paddingSizeLarge),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                            border: Border.all(color: Theme.of(context).disabledColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            Icon(Icons.lock_outline, color: Theme.of(context).disabledColor),
                            const SizedBox(width: Dimensions.paddingSizeSmall),
                            Expanded(
                              child: Text(
                                'El chat ha finalizado. Solo puedes enviar mensajes mientras tengas un pedido activo.',
                                style: robotoMedium.copyWith(color: Theme.of(context).disabledColor, fontSize: Dimensions.fontSizeSmall),
                              ),
                            ),
                          ]),
                        )
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        // Images Preview
                        chatController.chatImage!.isNotEmpty ? SizedBox(height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            itemCount: chatController.chatImage!.length,
                            itemBuilder: (BuildContext context, index){
                              return  chatController.chatImage!.isNotEmpty ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Stack(children: [

                                  Container(width: 100, height: 100,
                                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(20))),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.all(Radius.circular(Dimensions.paddingSizeDefault)),
                                      child: ResponsiveHelper.isWeb() ? Image.network(
                                        chatController.chatImage![index].path, width: 100, height: 100, fit: BoxFit.cover,
                                      ) : Image.file(
                                        File(chatController.chatImage![index].path), width: 100, height: 100, fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),

                                  Positioned(top:0, right:0,
                                    child: InkWell(
                                      onTap : () => chatController.removeImage(index),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.all(Radius.circular(Dimensions.paddingSizeDefault)),
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.clear, color: Colors.red, size: 15),
                                        ),
                                      ),
                                    ),
                                  )],
                                ),
                              ) : const SizedBox();
                            },
                          ),
                        ) : const SizedBox(),

                        // Video Preview
                        (chatController.pickedVideoFile != null || chatController.pickedWebVideoFile != null) ? Container(
                          height: 60,
                          margin: const EdgeInsets.only(top: 8),
                          child: Stack(clipBehavior: Clip.none, children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                              ),
                              padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.video_library, size: 28, color: Theme.of(context).disabledColor.withValues(alpha: 0.5)),
                                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                                Text(
                                  chatController.pickedVideoFile!.name.length > 15 ? '${chatController.pickedVideoFile!.name.substring(0, 15)}...' : chatController.pickedVideoFile!.name,
                                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                                if(chatController.videoSize > 0)
                                  Text(
                                    '${chatController.videoSize.toStringAsFixed(2)} MB',
                                    style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                                  )
                              ]),
                            ),
                            Positioned(top: -10, right: -10,
                              child: InkWell(
                                onTap: () => chatController.pickVideoFile(true),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.all(Radius.circular(Dimensions.paddingSizeDefault)),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.clear, color: Colors.red, size: 15),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ) : const SizedBox(),

                        // Files Preview
                        (chatController.objFile!.isNotEmpty || chatController.objWebFile!.isNotEmpty) ? Container(
                          height: 60,
                          margin: const EdgeInsets.only(top: 8),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            itemCount: ResponsiveHelper.isWeb() ? chatController.objWebFile?.length : chatController.objFile?.length,
                            itemBuilder: (BuildContext context, index) {
                              String fileName = '';
                              if (ResponsiveHelper.isWeb()) {
                                fileName = chatController.objWebFile![index].name;
                              } else {
                                fileName = chatController.objFile![index].name;
                              }
                              
                              return Stack(clipBehavior: Clip.none, children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                                  ),
                                  padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(
                                      fileName.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.description,
                                      size: 28,
                                      color: Theme.of(context).disabledColor.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      fileName.length > 15 ? '${fileName.substring(0, 15)}...' : fileName,
                                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                                    if(chatController.fileSizeList.isNotEmpty && index < chatController.fileSizeList.length)
                                      Text(
                                        '${chatController.fileSizeList[index].toStringAsFixed(2)} MB',
                                        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
                                      ),
                                  ]),
                                ),
                                Positioned(top: -10, right: -10,
                                  child: InkWell(
                                    onTap: () => chatController.pickFile(true, index: index),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.white,
                                        borderRadius: BorderRadius.all(Radius.circular(Dimensions.paddingSizeDefault)),
                                      ),
                                      child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.clear, color: Colors.red, size: 15)),
                                    ),
                                  ),
                                ),
                              ]);
                            },
                          ),
                        ) : const SizedBox(),
                        
                        (chatController.isLoading && chatController.chatImage!.isNotEmpty)
                            ? Align(alignment: Alignment.centerRight, child: Padding(
                          padding: const EdgeInsets.only(right: Dimensions.paddingSizeLarge, top: Dimensions.paddingSizeExtraSmall),
                          child: Text(
                            '${'uploading'.tr} ${chatController.chatImage?.length} ${'images'.tr}',
                            style: robotoMedium.copyWith(color: Theme.of(context).hintColor),
                          ),
                        )) : const SizedBox(),

                        // ── Indicador "Escribiendo..." ─────────────────
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _isOtherTyping
                              ? Padding(
                                  key: const ValueKey('typing'),
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(children: [
                                    const SizedBox(width: 8),
                                    _TypingIndicator(),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Escribiendo...',
                                      style: robotoRegular.copyWith(
                                        fontSize: Dimensions.fontSizeSmall,
                                        color: Theme.of(context).hintColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ]),
                                )
                              : const SizedBox(key: ValueKey('not_typing')),
                        ),

                        // ── Respuestas Rápidas ─────────────────────────
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: _showQuickReplies
                              ? SizedBox(
                                  height: 44,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                    itemCount: _quickReplies.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                                    itemBuilder: (ctx, i) => GestureDetector(
                                      onTap: () {
                                        _inputMessageController.text = _quickReplies[i];
                                        if (!chatController.isSendButtonActive) {
                                          chatController.toggleSendButtonActivity();
                                        }
                                        setState(() => _showQuickReplies = false);
                                        _sendMessage(chatController);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          _quickReplies[i],
                                          style: robotoRegular.copyWith(
                                            fontSize: Dimensions.fontSizeSmall,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(),
                        ),

                        Row(children: [
                          // Botón respuestas rápidas
                          GestureDetector(
                            onTap: () => setState(() => _showQuickReplies = !_showQuickReplies),
                            child: Container(
                              width: 40, height: 40,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: _showQuickReplies
                                    ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                                    : Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Icon(
                                Icons.flash_on_rounded,
                                color: _showQuickReplies
                                    ? Theme.of(context).primaryColor
                                    : Theme.of(context).hintColor,
                                size: 20,
                              ),
                            ),
                          ),

                          Expanded(
                            child: Container(
                              height: 55,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                                  border: Border.all(width: 1, color: Theme.of(context).disabledColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(children: [
                                  const SizedBox(width: Dimensions.paddingSizeDefault),
                                  // text editing button
                                  Expanded(
                                    child: TextField(
                                      inputFormatters: [LengthLimitingTextInputFormatter(Dimensions.messageInputLength)],
                                      controller: _inputMessageController,
                                      textCapitalization: TextCapitalization.sentences,
                                      style: robotoRegular,
                                      textInputAction: TextInputAction.send,
                                      maxLines: null,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'type_here'.tr,
                                        hintStyle: robotoRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeLarge),
                                      ),
                                      onSubmitted: (String newText) {
                                        _sendMessage(chatController);
                                      },
                                      onChanged: (String newText) {
                                        if(newText.trim().isNotEmpty && !Get.find<ChatController>().isSendButtonActive) {
                                          Get.find<ChatController>().toggleSendButtonActivity();
                                        }else if(newText.isEmpty && Get.find<ChatController>().isSendButtonActive) {
                                          Get.find<ChatController>().toggleSendButtonActivity();
                                        }
                                      },
                                    ),
                                  ),

                                  // Botón compartir ubicación
                                  InkWell(
                                    onTap: () => _shareLocation(chatController),
                                    child: Icon(Icons.location_on_outlined, color: Theme.of(context).hintColor, size: 22),
                                  ),

                                  const SizedBox(width: 6),

                                  //pick image button
                                  InkWell(
                                    onTap: () async {
                                      PermissionStatus status = await Permission.camera.request();
                                      if (status.isGranted) {
                                        chatController.pickCameraImage();
                                      } else if (status.isPermanentlyDenied) {
                                        openAppSettings();
                                      } else {
                                        showCustomSnackBar('camera_permission_denied'.tr);
                                      }
                                    },
                                    child: Icon(Icons.camera_alt_outlined, color: Theme.of(context).hintColor, size: 25),
                                  ),

                                  const SizedBox(width: Dimensions.paddingSizeDefault),

                                ]),
                              ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeDefault),
                          Container(height: 55, width: 55,
                            decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                              border: Border.all(width: 1, color: Theme.of(context).primaryColor.withValues(alpha: 0.2))
                            ),
                            child: GetBuilder<ChatController>(builder: (chatController) {
                              return !chatController.isLoading ? InkWell(
                                onTap: () => _sendMessage(chatController),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                                  child: Image.asset(
                                    Images.send, width: 25, height: 25,
                                    color: chatController.isSendButtonActive ? Theme.of(context).primaryColor : Theme.of(context).hintColor,
                                  ),
                                ),
                              ) : Padding(padding: const EdgeInsets.all(Dimensions.paddingSizeSmall), child: const Center( child: CircularProgressIndicator())) ;
                            })
                          ),
                        ]),

                      ]),
                  ) : const SizedBox(),
                ]),
              ),
            ),
          )) : const Center(child: Text('Not Login')),
        ),
      );
    }
    );
  }

  /// Obtiene la ubicación GPS actual y la envía como enlace de Google Maps
  Future<void> _shareLocation(ChatController chatController) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showCustomSnackBar('Permiso de ubicación denegado');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        showCustomSnackBar('Habilita la ubicación en ajustes');
        openAppSettings();
        return;
      }

      showCustomSnackBar('Obteniendo ubicación...', isError: false);
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final String locationMsg =
          '📍 Mi ubicación actual:\nhttps://maps.google.com/?q=${pos.latitude},${pos.longitude}';

      _inputMessageController.text = locationMsg;
      if (!chatController.isSendButtonActive) {
        chatController.toggleSendButtonActivity();
      }
      _sendMessage(chatController);
    } catch (e) {
      showCustomSnackBar('No se pudo obtener la ubicación');
    }
  }
}

/// Widget de 3 puntos pulsantes para indicar "escribiendo..."
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final double delay = i * 0.33;
            final double t = (_controller.value - delay).clamp(0.0, 1.0);
            final double scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 7, height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).hintColor,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
