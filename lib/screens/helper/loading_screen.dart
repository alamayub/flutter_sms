import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/generic_controller.dart';
import '../../config/constants.dart';
import '../../widgets/generic/loader_widget.dart';
import '../../widgets/generic/overlay_widget.dart';

class LoadingScreen {
  LoadingScreen._sharedInstance();
  static final LoadingScreen _shared = LoadingScreen._sharedInstance();
  factory LoadingScreen.instance() => _shared;

  GenericController? _controller;

  void show({required BuildContext context, String text = Strings.loading}) {
    if (_controller?.update(text) ?? false) {
      return;
    } else {
      _controller = showOverlay(context: context, text: text);
    }
  }

  void hide() {
    _controller?.close();
    _controller = null;
  }

  GenericController? showOverlay({
    required BuildContext context,
    required String text,
  }) {
    final state = Overlay.of(context);

    final textController = StreamController<String>();
    textController.add(text);

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final overlay = OverlayEntry(
      builder: (context) {
        return OverlayWidget(
          size: size,
          center: true,
          children: [
            const LoaderWidget(),
            StreamBuilder(
              stream: textController.stream,
              builder: (context, snap) {
                if (snap.hasData) {
                  return Text(snap.data ?? '');
                }
                return Container();
              },
            ),
          ],
        );
      },
    );

    state.insert(overlay);

    return GenericController(
      close: () {
        textController.close();
        overlay.remove();
        return true;
      },
      update: (text) {
        textController.add(text);
        return true;
      },
    );
  }
}
