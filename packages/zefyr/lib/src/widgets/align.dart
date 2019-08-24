import 'package:flutter/material.dart';
import 'package:notus/notus.dart';

import 'common.dart';
import 'theme.dart';

/// Represents heading-styled line in [ZefyrEditor].
/// 需要兼容 Heading 效果
class ZefyrAlign extends StatelessWidget {
  ZefyrAlign({Key key, @required this.node})
      : assert(node.style.contains(NotusAttribute.align)),
        super(key: key);

  final LineNode node;

  @override
  Widget build(BuildContext context) {
    final theme = ZefyrTheme.of(context);
    TextStyle textStyle = theme.paragraphTheme.textStyle;

    ///render align if heading has align
    if (node.style.contains(NotusAttribute.heading)) {
      TextStyle headingStyle = themeOf(node, context).textStyle;
      textStyle = textStyle.merge(headingStyle);
    }
    return Center(
      child: RawZefyrLine(
        node: node,
        style: textStyle,
        padding: theme.paragraphTheme.padding,
      ),
    );
  }

  static StyleTheme themeOf(LineNode node, BuildContext context) {
    final theme = ZefyrTheme.of(context);
    final style = node.style.get(NotusAttribute.heading);
    if (style == NotusAttribute.heading.level1) {
      return theme.headingTheme.level1;
    } else if (style == NotusAttribute.heading.level2) {
      return theme.headingTheme.level2;
    } else if (style == NotusAttribute.heading.level3) {
      return theme.headingTheme.level3;
    }
    throw new UnimplementedError('Unsupported heading style $style');
  }
}
