import 'package:flutter/widgets.dart';

class QuestionnaireLayoutTokens {
  final double width;
  final double height;
  final double scaleX;
  final double scaleY;

  const QuestionnaireLayoutTokens._({
    required this.width,
    required this.height,
    required this.scaleX,
    required this.scaleY,
  });

  factory QuestionnaireLayoutTokens.full({
    required Size screenSize,
  }) {
    final height = screenSize.height * (636 / 852);
    final scaleX = screenSize.width / 393;
    final scaleY = height / 636;
    return QuestionnaireLayoutTokens._(
      width: screenSize.width,
      height: height,
      scaleX: scaleX,
      scaleY: scaleY,
    );
  }

  const QuestionnaireLayoutTokens.compact()
      : this._(
          width: 284,
          height: 406,
          scaleX: 284 / 393,
          scaleY: 406 / 636,
        );

  double sx(double value) => value * scaleX;
  double sy(double value) => value * scaleY;

  double scaledFont(double value) {
    final factor = (scaleX + scaleY) / 2;
    return value * factor;
  }
}
