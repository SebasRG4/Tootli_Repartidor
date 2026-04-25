import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart_delivery/api/api_client.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_app_bar_widget.dart';
import 'package:sixam_mart_delivery/common/widgets/custom_snackbar_widget.dart';
import 'package:sixam_mart_delivery/util/app_constants.dart';
import 'package:sixam_mart_delivery/util/dimensions.dart';
import 'package:sixam_mart_delivery/util/styles.dart';

class TootliDirectTrackingChatScreen extends StatefulWidget {
  final int orderId;

  const TootliDirectTrackingChatScreen({super.key, required this.orderId});

  @override
  State<TootliDirectTrackingChatScreen> createState() =>
      _TootliDirectTrackingChatScreenState();
}

class _TdMsg {
  final int id;
  final String sender;
  final String body;

  _TdMsg({
    required this.id,
    required this.sender,
    required this.body,
  });
}

class _TootliDirectTrackingChatScreenState
    extends State<TootliDirectTrackingChatScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<_TdMsg> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _chatClosed = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (widget.orderId <= 0) {
      Future.microtask(() {
        if (!mounted) {
          return;
        }
        setState(() => _loading = false);
        showCustomSnackBar('Error', isError: true);
        Get.back();
      });
      return;
    }
    _load(handleError: true);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_chatClosed) {
        _load(handleError: false);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({required bool handleError}) async {
    final ApiClient client = Get.find<ApiClient>();
    final Response res = await client.getData(
      '${AppConstants.tootliDirectTrackingChatUri}?order_id=${widget.orderId}',
      handleError: handleError,
    );
    if (!mounted) {
      return;
    }
    if (res.statusCode != 200) {
      if (handleError) {
        setState(() => _loading = false);
      }
      return;
    }
    final List<_TdMsg> out = [];
    final dynamic raw = res.body;
    if (raw is Map && raw['messages'] is List) {
      for (final dynamic m in raw['messages'] as List) {
        if (m is! Map) {
          continue;
        }
        final Map<String, dynamic> map = Map<String, dynamic>.from(m);
        out.add(
          _TdMsg(
            id: (map['id'] as num?)?.toInt() ?? 0,
            sender: map['sender']?.toString() ?? '',
            body: map['body']?.toString() ?? '',
          ),
        );
      }
    }
    final bool chatClosed =
        raw is Map && raw['chat_closed'] == true;
    if (chatClosed) {
      _poll?.cancel();
      _poll = null;
    }
    setState(() {
      _messages = out;
      _loading = false;
      _chatClosed = chatClosed;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _messages.isNotEmpty) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    if (_chatClosed) {
      return;
    }
    final String text = _text.text.trim();
    if (text.isEmpty) {
      return;
    }
    if (_sending) {
      return;
    }
    setState(() => _sending = true);
    final ApiClient client = Get.find<ApiClient>();
    final Response res = await client.postData(
      AppConstants.tootliDirectTrackingChatUri,
      {'order_id': widget.orderId, 'message': text},
      handleError: false,
    );
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (res.statusCode == 200) {
      _text.clear();
      await _load(handleError: false);
    } else {
      if (res.statusCode == 403) {
        await _load(handleError: false);
      }
      showCustomSnackBar(res.statusText ?? 'Error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxBubble = MediaQuery.sizeOf(context).width * 0.78;
    return Scaffold(
      appBar: CustomAppBarWidget(title: 'tootli_direct_chat_title'.tr),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'tootli_direct_chat_subtitle'.tr,
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _chatClosed
                                ? 'tootli_direct_chat_closed_hint'.tr
                                : 'tootli_direct_chat_no_messages'.tr,
                            textAlign: TextAlign.center,
                            style: robotoRegular,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final _TdMsg m = _messages[i];
                          final bool mine = m.sender == 'delivery_man';
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              constraints: BoxConstraints(maxWidth: maxBubble),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.15)
                                    : Theme.of(context)
                                        .disabledColor
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(m.body, style: robotoRegular),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: _chatClosed && _messages.isEmpty
                  ? const SizedBox.shrink()
                  : _chatClosed
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          child: Text(
                            'tootli_direct_chat_closed_hint'.tr,
                            textAlign: TextAlign.center,
                            style: robotoRegular.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        )
                      : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'tootli_direct_chat_hint'.tr,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                onPressed: _send,
                                icon: const Icon(Icons.send),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
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
}
