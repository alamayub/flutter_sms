import 'package:flutter/material.dart';

class OverlayWidget extends StatelessWidget {
  final Size size;
  final List<Widget> children;
  final bool center;
  const OverlayWidget({
    super.key,
    required this.size,
    required this.children,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(150),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: size.width * 0.8,
            maxHeight: size.height * 0.8,
            minWidth: size.width * 0.2,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
