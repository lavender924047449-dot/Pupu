/// 公共动效配置
/// 呼吸周期、页面过渡、曲线（禁止弹跳）

import 'package:flutter/material.dart';
import 'package:pupu/core/constants.dart';

/// 页面过渡时长
final Duration pageTransitionDuration = Duration(
  milliseconds: (durationPageTransitionSec * 1000).round(),
);

/// 呼吸动画时长
final Duration breathDuration = Duration(
  milliseconds: (durationBreathSec * 1000).round(),
);

/// 统一缓动曲线（禁止 bounce/elastic）
const Curve standardCurve = Curves.easeInOut;
