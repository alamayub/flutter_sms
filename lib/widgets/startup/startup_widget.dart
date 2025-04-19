import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../config/typo_config.dart';

class StartupWidget extends StatelessWidget {
  final Widget widget;
  const StartupWidget({super.key, required this.widget});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.primary,
      body: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          widget,
          Positioned(
            bottom: 30,
            child: Column(
              children: [
                Text(
                  'BOOK',
                  style: typoConfig.textStyle.largeBodyBodyBold.copyWith(
                    height: 1,
                    fontSize: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your knowledge hub'.toUpperCase(),
                  style: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
                    height: 1,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// "Study2ool – Your Gateway to Global Education & Career Success!" 🚀📚
// "Study2ool – Empowering Your Future, One Lesson at a Time!" 🎓✨
// "Study2ool – Learn. Prepare. Succeed." 🎯📚
// "Study2ool – The Right Tool for Your Education & Future!" 🔧🎓
// "Study2ool – The Ultimate Tool for Learning, Growth & Success!" 🎓🔧✨
// "Study2ool – The Ultimate Tool for Learning and Success!" 🎓🔧🚀
// "Study2ool – The Ultimate Tool for Learning, Preparing, and Achieving!" 🎓🔧🌟
// "Study2ool – Your Pathway to Learning, Growth, and Success!" 🎓🌍🚀
// "Study2ool – Unlock Your Potential!" 🚀
// "Study2ool – Your Future Starts Here!" 🌟
