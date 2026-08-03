import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/features/chat/domain/models/conversation_model.dart';
import 'package:sixam_mart_delivery/features/chat/domain/models/message_model.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_image_widget.dart';
import 'package:sixam_mart_delivery/features/chat/widgets/full_screen_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../common/widgets/custom_snackbar_widget.dart';
import '../../language/controllers/language_controller.dart';
import '../../profile/controllers/profile_controller.dart';
import '../controllers/chat_controller.dart';

class MessageBubbleWidget extends StatelessWidget {
  final Message? previousMessage;
  final Message? nextMessage;
  final Message message;
  final User? user;
  final User? sender;
  final String userType;
  const MessageBubbleWidget({super.key, required this.message, required this.user, required this.userType, required this.sender, required this.previousMessage, required this.nextMessage});

  @override
  Widget build(BuildContext context) {
    ChatController chatController = Get.find<ChatController>();
    int? myId = Get.find<ProfileController>().profileModel?.userInfoId ?? Get.find<ProfileController>().profileModel?.id;
    bool isReply = message.senderId != myId;
    bool isLTR = Get.find<LocalizationController>().isLtr;
    String chatTime = chatController.getChatTime(message.createdAt!, nextMessage?.createdAt);
    String previousMessageHasChatTime = previousMessage != null ? chatController.getChatTime(previousMessage!.createdAt!, message.createdAt) : "";
    bool isSameUserWithPreviousMessage = _isSameUserWithPreviousMessage(previousMessage, message);
    bool isSameUserWithNextMessage = _isSameUserWithNextMessage(message, nextMessage);

    User? otherUser = (sender?.id == myId) ? user : sender;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context, message),
      child: (isReply) ? Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall)),
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          if(chatTime != '')
            Align(alignment: Alignment.center,
              child: Padding(padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault, top: 5),
                child: Text(
                  chatController.getChatTime(message.createdAt!, nextMessage?.createdAt),
                  style: robotoRegular.copyWith(color: Theme.of(context).disabledColor),
                ),
              ),
            ),

          Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.start, children: [
            (isReply && !isSameUserWithPreviousMessage) || ((isReply && isSameUserWithPreviousMessage) && chatController.getChatTimeWithPrevious(message, previousMessage).isNotEmpty)
                ?
            ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: CustomImageWidget(
                fit: BoxFit.cover, width: 40, height: 40,
                image: otherUser?.imageFullUrl ?? user?.imageFullUrl ?? '',
              ),
            ) : isReply ? const SizedBox(width: Dimensions.paddingSizeExtraLarge + 15) : const SizedBox()  ,
            const SizedBox(width: 10),

            Flexible(
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.start, children: [

                if(message.message != null)  Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF8C6), // Light green for receiver
                      borderRadius: isReply && (isSameUserWithNextMessage || isSameUserWithPreviousMessage) ? BorderRadius.only(
                        topLeft: Radius.circular(isSameUserWithNextMessage && isLTR && chatTime ==""? Dimensions.radiusSmall : Dimensions.radiusExtraLarge + 5),
                        bottomLeft: Radius.circular( isSameUserWithPreviousMessage && isLTR && previousMessageHasChatTime == "" ? Dimensions.radiusSmall : Dimensions.radiusExtraLarge + 5),
                        topRight: Radius.circular(isSameUserWithNextMessage && !isLTR && chatTime ==""? Dimensions.radiusSmall : Dimensions.radiusExtraLarge + 5),
                        bottomRight: Radius.circular(isSameUserWithPreviousMessage && !isLTR && previousMessageHasChatTime =="" ? Dimensions.radiusSmall :Dimensions.radiusExtraLarge + 5),

                      ) : BorderRadius.circular(Dimensions.radiusExtraLarge + 5),
                    ),
                    padding: EdgeInsets.all(message.message != null ? Dimensions.paddingSizeDefault : 0),
                    child: Text(message.message ?? '', style: robotoRegular.copyWith(color: Colors.black87)),
                  ),
                ),
                message.filesFullUrl == null ? SizedBox(height: 8.0) : SizedBox.shrink(),

                message.filesFullUrl != null ? GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    childAspectRatio: 1,
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 5,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: message.filesFullUrl!.length,
                  itemBuilder: (BuildContext context, index){
                    return  message.filesFullUrl!.isNotEmpty ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        hoverColor: Colors.transparent,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => FullScreenImageViewer(imageUrl: message.filesFullUrl![index]),
                        )),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall),
                          child: CustomImageWidget(
                            height: 100, width: 100, fit: BoxFit.cover,
                            image: message.filesFullUrl![index],
                          ),
                        ),
                      ),
                    ) : const SizedBox();
                  },
                ) : const SizedBox(),

              ]),
            ),
          ]),
        ]),
      ) :  Container(
            padding: const EdgeInsets.symmetric(horizontal:Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeExtraSmall),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.paddingSizeSmall)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if(chatTime != '')
                Align(alignment: Alignment.center,
                  child: Padding(padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault, top: 5),
                    child: Text(
                      chatController.getChatTime(message.createdAt!, nextMessage?.createdAt),
                      style: robotoRegular.copyWith(color: Theme.of(context).disabledColor),
                    ),
                  ),
                ),

              Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                Flexible(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    (message.message != null && message.message!.isNotEmpty) ?  Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD), // Light blue for sender
                        borderRadius: !isReply && (isSameUserWithNextMessage || isSameUserWithPreviousMessage) ? BorderRadius.only(
                          topRight: Radius.circular(isSameUserWithNextMessage && isLTR && chatTime ==""? Dimensions.radiusSmall : Dimensions.radiusExtraLarge + 5),
                          bottomRight: Radius.circular( isSameUserWithPreviousMessage && isLTR && previousMessageHasChatTime == "" ? Dimensions.radiusSmall : Dimensions.radiusExtraLarge + 5),
                          topLeft: Radius.circular(isSameUserWithNextMessage && !isLTR && chatTime ==""? Dimensions.radiusSmall : Dimensions.radiusExtraLarge + 5),
                          bottomLeft: Radius.circular(isSameUserWithPreviousMessage && !isLTR && previousMessageHasChatTime =="" ? Dimensions.radiusSmall :Dimensions.radiusExtraLarge + 5),
                        ) : BorderRadius.circular(Dimensions.radiusExtraLarge + 5),
                      ),
                      padding: EdgeInsets.all(message.message != null ? Dimensions.paddingSizeDefault : 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(child: Text(message.message??'', style: robotoRegular.copyWith(color: Colors.black87))),
                          const SizedBox(width: 5),
                          // Confirmación de lectura ✓✓
                          Icon(
                            message.isSeen == 1 ? Icons.done_all : Icons.check,
                            size: 16,
                            color: message.isSeen == 1 ? Colors.blue : Colors.blueGrey,
                          ),
                        ],
                      ),
                    ) : const SizedBox(),

                    message.filesFullUrl != null ? Directionality(
                      textDirection: TextDirection.rtl,
                      child: GridView.builder(
                        reverse: true,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          childAspectRatio: 1,
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 5,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: message.filesFullUrl!.length,
                        itemBuilder: (BuildContext context, index){
                          String fileUrl = message.filesFullUrl![index];
                          bool isImage = _isImageFile(fileUrl);
                          bool isPdf = _isPdfFile(fileUrl);
                          bool isVideo = _isVideoFile(fileUrl);
                          bool isDoc = _isDocFile(fileUrl);

                          return  message.filesFullUrl!.isNotEmpty ? GestureDetector(
                            onTap: () {
                              if(isImage) {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(imageUrl: fileUrl),
                                ));
                              } else {
                                _openFile(fileUrl);
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: Dimensions.paddingSizeSmall , right:  0,
                                top: (message.message != null && message.message!.isNotEmpty) ? Dimensions.paddingSizeSmall : 0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                child: isImage ? CustomImageWidget(height: 100, width: 100, fit: BoxFit.cover, image: fileUrl) : Container(height: 100, width: 100,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                    border: Border.all(color: Theme.of(context).disabledColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(isPdf ? Icons.picture_as_pdf
                                            : isVideo ? Icons.video_library
                                            : isDoc ? Icons.description
                                          : Icons.insert_drive_file,
                                        size: 40,
                                        color: isPdf ? Colors.red
                                            : isVideo ? Colors.blue
                                            : Theme.of(context).primaryColor,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        isPdf ? 'PDF'
                                            : isVideo ? 'Video'
                                            : isDoc ? 'DOC'
                                            : 'File',
                                        style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).textTheme.bodyMedium?.color,),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ) : const SizedBox();
                        },
                      ),
                    ) : const SizedBox(),
                  ]),
                ),
              ]),
            ]),
      ),
    );
  }

  /// Menú contextual al hacer long press en un mensaje
  void _showMessageOptions(BuildContext context, Message message) {
    HapticFeedback.mediumImpact();
    final bool hasText = message.message != null && message.message!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (hasText)
              _OptionTile(
                icon: Icons.copy_rounded,
                label: 'Copiar mensaje',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.message!));
                  Navigator.pop(context);
                  showCustomSnackBar('Mensaje copiado', isError: false);
                },
              ),
            _OptionTile(
              icon: Icons.reply_rounded,
              label: 'Responder rápido',
              onTap: () {
                Navigator.pop(context);
                // Rellenar el campo de texto con la cita del mensaje
                showCustomSnackBar('Selecciona una respuesta rápida', isError: false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  bool _isSameUserWithPreviousMessage(Message? previousConversation, Message? currentConversation){
    if(previousConversation?.senderId == currentConversation?.senderId && previousConversation?.message != null && currentConversation?.message !=null){
      return true;
    }
    return false;
  }

  bool _isSameUserWithNextMessage(Message? currentConversation, Message? nextConversation){
    if(currentConversation?.senderId == nextConversation?.senderId && nextConversation?.message != null && currentConversation?.message !=null){
      return true;
    }
    return false;
  }

  bool _isImageFile(String url) {
    String lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.webp') ||
        lowerUrl.endsWith('.bmp');
  }

  bool _isPdfFile(String url) {
    return url.toLowerCase().endsWith('.pdf');
  }

  bool _isVideoFile(String url) {
    String lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mov') ||
        lowerUrl.endsWith('.avi') ||
        lowerUrl.endsWith('.mkv') ||
        lowerUrl.endsWith('.webm');
  }

  bool _isDocFile(String url) {
    String lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.doc') ||
        lowerUrl.endsWith('.docx') ||
        lowerUrl.endsWith('.txt');
  }

  void _openFile(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar('could_not_open_file'.tr);
    }
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
      ),
      title: Text(label, style: robotoMedium),
      onTap: onTap,
    );
  }
}
