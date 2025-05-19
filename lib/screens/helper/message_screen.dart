import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart' show WidgetRef;

import '../../config/generic_controller.dart';
import '../../providers/global_provider.dart' show globalProvider;
import '../../states/global_state.dart';
import '../../config/constants.dart' show Strings;
import '../../config/extensions.dart' show StringExtensions;
import '../../config/typo_config.dart';
import '../../widgets/generic/overlay_widget.dart';

class MessageScreen {
  MessageScreen._sharedInstance();
  static final MessageScreen _shared = MessageScreen._sharedInstance();
  factory MessageScreen.instance() => _shared;

  GenericController? _controller;

  void show({
    required BuildContext context,
    required GlobalState global,
    required WidgetRef ref,
  }) {
    if (_controller != null) {
      _controller!.update(global.error ?? Strings.errorDesc);
    } else {
      _controller = showOverlay(context: context, global: global, ref: ref);
    }
  }

  void hide() {
    _controller?.close();
    _controller = null;
  }

  GenericController? showOverlay({
    required BuildContext context,
    required GlobalState global,
    required WidgetRef ref,
  }) {
    final overlayState = Overlay.of(context);

    final textController = StreamController<String>();
    textController.add(global.error ?? Strings.errorDesc);

    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? MediaQuery.of(context).size;

    final overlay = OverlayEntry(
      builder: (context) {
        return OverlayWidget(
          size: size,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                global.type.name.capitalize,
                style: typoConfig.textStyle.largeCaptionLabel2Bold,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<String>(
              stream: textController.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    snapshot.data ?? Strings.errorDesc,
                    style: typoConfig.textStyle.smallCaptionSubtitle2,
                  );
                }
                return Container();
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ref.read(globalProvider.notifier).reset();
                  hide();
                },
                child: Text(
                  Strings.dismiss,
                  // style: typoConfig.textStyle.smallCaptionSubtitle1.copyWith(
                  //   color: typoConfig.color.surfaceWhite,
                  // ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(overlay);

    return GenericController(
      close: () {
        textController.close();
        overlay.remove();
        return true;
      },
      update: (text) {
        if (!textController.isClosed) {
          textController.add(text);
        }
        return true;
      },
    );
  }
}
