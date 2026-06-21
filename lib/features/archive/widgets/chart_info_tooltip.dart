import 'dart:ui';

import 'package:flutter/material.dart';

class ChartInfoSpan {
  final String text;
  final bool isSubHeading;

  const ChartInfoSpan(this.text, {this.isSubHeading = false});
}

class ChartInfoParagraph {
  final List<ChartInfoSpan> spans;

  const ChartInfoParagraph(this.spans);
}

class ChartInfoPart {
  final String title;
  final List<ChartInfoParagraph> paragraphs;

  const ChartInfoPart({
    required this.title,
    required this.paragraphs,
  });
}

class ChartInfoContent {
  final List<ChartInfoPart> parts;

  const ChartInfoContent(this.parts);
}

/// Matches the trailing grid icon size in chart window navigators.
const double kChartInfoIconSize = 16;

/// Shared legend for abbreviated dimension labels in drill-down views.
const String kChartDimensionAbbreviationLegend =
    'Phys = Physiological, Psych = Psychological, Ext = External';

class ChartInfoButton extends StatefulWidget {
  final ChartInfoContent content;

  const ChartInfoButton({
    super.key,
    required this.content,
  });

  @override
  State<ChartInfoButton> createState() => _ChartInfoButtonState();
}

class _ChartInfoButtonState extends State<ChartInfoButton> {
  static OverlayEntry? _activeEntry;
  static _ChartInfoButtonState? _activeOwner;

  OverlayEntry? _localEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    if (_localEntry != null) {
      _removeOverlay();
    }
    super.dispose();
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _removeOverlay();
      return;
    }
    _showOverlay();
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    _activeOwner?._removeOverlay();

    final box = renderObject;
    final origin = box.localToGlobal(Offset.zero);
    final iconSize = box.size;
    final overlaySize = MediaQuery.of(context).size;
    const panelWidth = 286.0;
    const panelTopOffset = 10.0;
    const screenPadding = 8.0;

    var left = origin.dx + iconSize.width - panelWidth;
    left = left.clamp(
      screenPadding,
      overlaySize.width - panelWidth - screenPadding,
    );

    var top = origin.dy + iconSize.height + panelTopOffset;
    final maxHeight = overlaySize.height * 0.62;
    if (top + maxHeight > overlaySize.height - screenPadding) {
      top = (overlaySize.height - maxHeight - screenPadding).clamp(
        screenPadding,
        double.infinity,
      );
    }

    _localEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: panelWidth,
            child: _ChartInfoPanel(
              content: widget.content,
            ),
          ),
        ],
      ),
    );

    overlay.insert(_localEntry!);
    _activeEntry = _localEntry;
    _activeOwner = this;
    if (mounted) {
      setState(() => _isOpen = true);
    }
  }

  void _removeOverlay() {
    _localEntry?.remove();
    if (_activeEntry == _localEntry) {
      _activeEntry = null;
      _activeOwner = null;
    }
    _localEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleOverlay,
      child: Text(
        'ⓘ',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: kChartInfoIconSize,
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w300,
          fontVariations: const [FontVariation('wght', 274)],
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _ChartInfoPanel extends StatelessWidget {
  final ChartInfoContent content;

  const _ChartInfoPanel({required this.content});

  /// Shared with Status Grid dialog glass shell in `chart_analysis_card.dart`.
  static const BorderRadius glassBorderRadius = BorderRadius.all(Radius.circular(16));
  static const EdgeInsets glassPadding = EdgeInsets.fromLTRB(14, 14, 14, 16);
  static const double glassBlurSigma = 25;
  static const Color glassFillColor = Color(0x33FFFFFF);
  static const BorderSide glassBorderSide = BorderSide(color: Colors.white24, width: 0.6);

  static const TextStyle _partTitleStyle = TextStyle(
    color: Color(0xFF0088FF),
    fontSize: 13,
    fontFamily: 'SF Pro',
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 590)],
    height: 1.3,
    decoration: TextDecoration.none,
  );

  static const TextStyle _subHeadingStyle = TextStyle(
    color: Color(0xFF0088FF),
    fontSize: 11,
    fontFamily: 'SF Pro',
    fontWeight: FontWeight.w300,
    height: 1.35,
    decoration: TextDecoration.none,
  );

  static const TextStyle _bodyStyle = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontFamily: 'SF Pro',
    fontWeight: FontWeight.w300,
    height: 1.35,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: glassBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: glassBlurSigma,
          sigmaY: glassBlurSigma,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.62,
          ),
          padding: glassPadding,
          decoration: BoxDecoration(
            color: glassFillColor,
            borderRadius: glassBorderRadius,
            border: Border.fromBorderSide(glassBorderSide),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < content.parts.length; i++) ...[
                  Text(content.parts[i].title, style: _partTitleStyle),
                  for (final paragraph in content.parts[i].paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: RichText(
                        textAlign: TextAlign.left,
                        text: TextSpan(
                          style: _bodyStyle,
                          children: [
                            for (final span in paragraph.spans)
                              TextSpan(
                                text: span.text,
                                style: span.isSubHeading
                                    ? _subHeadingStyle
                                    : _bodyStyle,
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (i != content.parts.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const ChartInfoContent chartInfoLogCalendar = ChartInfoContent([
  ChartInfoPart(
    title: 'Data Rules & Interaction',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'Each cell represents one day. The color intensity reflects how many bowel logs you logged. More logs produce a darker shade, and days without any logs remain blank.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Tip: ', isSubHeading: true),
        ChartInfoSpan(
          'Tap any day to open a panel showing all logs for that date.',
        ),
      ]),
    ],
  ),
  ChartInfoPart(
    title: 'Health Insight',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'Tracking your bowel frequency helps you recognize your personal rhythm. Irregular gaps or sudden spikes may signal dietary changes, stress, or other factors worth noting. A consistent pattern (1-3 times daily, or once every 1-2 days) is generally considered healthy.',
        ),
      ]),
    ],
  ),
]);

const ChartInfoContent chartInfoOverallStatusDistribution = ChartInfoContent([
  ChartInfoPart(
    title: 'Data Rules & Interaction',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'Each log is classified into one of five statuses based on your log details.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Ideal: ', isSubHeading: true),
        ChartInfoSpan(
          'smooth result, minimal effort, complete evacuation, well-formed consistency, no discomfort.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Dry / Hard: ', isSubHeading: true),
        ChartInfoSpan(
          'excessive straining, hard or pellet-like consistency, prolonged effort.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Incomplete / Not Smooth: ', isSubHeading: true),
        ChartInfoSpan(
          'residual sensation, blocked feeling, and a need for positional changes or assistance.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Soft / Urgent: ', isSubHeading: true),
        ChartInfoSpan(
          'loose consistency, strong urgency, and difficulty holding.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Unsuccessful: ', isSubHeading: true),
        ChartInfoSpan('attempted but unable to pass stool.'),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan(
          'Each answer contributes weighted points toward one or more statuses. The highest total score becomes the primary classification. When conflicting statuses score highly at the same time, that log is excluded to keep the distribution reliable. The chart shows each status share across the selected 7- or 30-day window.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Tip: ', isSubHeading: true),
        ChartInfoSpan(
          'Tap each segment to see the exact count and percentage for that status.',
        ),
      ]),
    ],
  ),
  ChartInfoPart(
    title: 'Health Insight',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'This chart reveals your dominant bowel pattern. A high proportion of Ideal suggests stable digestive function. Frequent Dry / Hard may indicate insufficient hydration or fiber intake. Repeated Soft / Urgent may be linked to dietary irritants or stress. Use this overview to identify patterns worth discussing with your healthcare provider.',
        ),
      ]),
    ],
  ),
]);

const ChartInfoContent chartInfoStatusTrends = ChartInfoContent([
  ChartInfoPart(
    title: 'Data Rules & Interaction',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'Each data point represents a daily Bowel Health Score (0-100), derived from five weighted dimensions: ',
        ),
        ChartInfoSpan('Result (20%), ', isSubHeading: true),
        ChartInfoSpan('Straining (15%), ', isSubHeading: true),
        ChartInfoSpan('Evacuation (20%), ', isSubHeading: true),
        ChartInfoSpan('Consistency (20%), ', isSubHeading: true),
        ChartInfoSpan('and Pain & Discomfort (25%).', isSubHeading: true),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan(
          'Each dimension is scored based on your log details, then combined using its weight. If multiple valid logs exist on one day, the chart uses their average score. Higher scores indicate better bowel health for that day.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Tip: ', isSubHeading: true),
        ChartInfoSpan(
          'Tap any data point to expand the score breakdown and see each dimension contribution.',
        ),
      ]),
    ],
  ),
  ChartInfoPart(
    title: 'Health Insight',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'This trend helps you spot gradual improvements or declines over time. A rising trend suggests healthier bowel patterns, while a declining trend may indicate diet, stress, or routine factors that need review. Consistent scores above 70 generally indicate healthy bowel function.',
        ),
      ]),
    ],
  ),
]);

const ChartInfoContent chartInfoRadarView = ChartInfoContent([
  ChartInfoPart(
    title: 'Data Rules & Interaction',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'Issue signals from your log details are grouped into three dimensions: ',
        ),
        ChartInfoSpan('Physiological, ', isSubHeading: true),
        ChartInfoSpan('Psychological, ', isSubHeading: true),
        ChartInfoSpan('and External.', isSubHeading: true),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan(
          'Each dimension is scored from core indicators and companion indicators, then normalized to percentages. The radar shape shows the period average across all valid logs in the selected 7- or 30-day window.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Tip: ', isSubHeading: true),
        ChartInfoSpan(
          'Tap any axis or grid area to view the exact percentage and number of contributing logs for that dimension.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan(kChartDimensionAbbreviationLegend),
      ]),
    ],
  ),
  ChartInfoPart(
    title: 'Health Insight',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'This chart shows which category of factors affects your bowel health most. A shape skewed toward Physiological may suggest physical symptom management is needed. A Psychological skew can indicate stress-driven patterns. External dominance points to environment or routine triggers. A smaller, balanced shape is the ideal direction.',
        ),
      ]),
    ],
  ),
]);

const ChartInfoContent chartInfoStackedBarView = ChartInfoContent([
  ChartInfoPart(
    title: 'Data Rules & Interaction',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'Each bar represents one day and is split into Physiological, Psychological, and External percentages. The segment proportions show which category dominated that day.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan(
          'When multiple logs exist on a day, they are merged using a weighted average, and logs with stronger physical core symptoms receive more weight. Days without valid log data show no bar.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Tip: ', isSubHeading: true),
        ChartInfoSpan(
          'Tap any bar to see individual log breakdowns and how each log contributed to the daily total.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan(kChartDimensionAbbreviationLegend),
      ]),
    ],
  ),
  ChartInfoPart(
    title: 'Health Insight',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'This view reveals day-to-day variation in your issue drivers. Use recurring spikes to identify practical triggers, such as stressful workdays or travel periods, and adjust your routine more precisely.',
        ),
      ]),
    ],
  ),
]);

const ChartInfoContent chartInfoLineView = ChartInfoContent([
  ChartInfoPart(
    title: 'Data Rules & Interaction',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'Three lines track daily percentages for Physiological, Psychological, and External factors over the selected 7- or 30-day window. For each day, the three percentages sum to 100%.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan(
          'Days without valid log data are skipped, and the trend line connects days that do contain valid data.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan('Tip: ', isSubHeading: true),
        ChartInfoSpan(
          'Tap any data point to see the exact percentages and log count for that day.',
        ),
      ]),
      ChartInfoParagraph([
        ChartInfoSpan(kChartDimensionAbbreviationLegend),
      ]),
    ],
  ),
  ChartInfoPart(
    title: 'Health Insight',
    paragraphs: [
      ChartInfoParagraph([
        ChartInfoSpan(
          'Use this view to track how issue composition shifts over time. A declining Physiological line after diet changes suggests improvement, while a rising Psychological line in busy periods highlights stress impact. This helps you choose targeted lifestyle adjustments and verify whether they work.',
        ),
      ]),
    ],
  ),
]);
