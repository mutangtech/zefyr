// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:notus/notus.dart';
import 'package:zefyr/src/widgets/image.dart';

import 'scope.dart';
import 'theme.dart';
import 'toolbar.dart';

/// A button used in [ZefyrToolbar].
///
/// Create an instance of this widget with [ZefyrButton.icon] or
/// [ZefyrButton.text] constructors.
///
/// Toolbar buttons are normally created by a [ZefyrToolbarDelegate].
class ZefyrButton extends StatelessWidget {
  /// Creates a toolbar button with an icon.
  ZefyrButton.icon({
    @required this.action,
    @required IconData icon,
    double iconSize,
    this.onPressed,
    String text,
    TextStyle textStyle,
  })  : assert(action != null),
        assert(icon != null),
        _icon = icon,
        _iconSize = iconSize,
        _text = text,
        _textStyle = textStyle,
        super();

  /// Creates a toolbar button containing text.
  ///
  /// Note that [ZefyrButton] has fixed width and does not expand to accommodate
  /// long texts.
  ZefyrButton.text({
    @required this.action,
    @required String text,
    TextStyle style,
    this.onPressed,
  })  : assert(action != null),
        assert(text != null),
        _icon = null,
        _iconSize = null,
        _text = text,
        _textStyle = style,
        super();

  /// Toolbar action associated with this button.
  final ZefyrToolbarAction action;
  final IconData _icon;
  final double _iconSize;
  final String _text;
  final TextStyle _textStyle;

  /// Callback to trigger when this button is tapped.
  final VoidCallback onPressed;

  bool get isAttributeAction {
    return kZefyrToolbarAttributeActions.keys.contains(action);
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    final editor = toolbar.editor;
    final toolbarTheme = ZefyrTheme.of(context).toolbarTheme;
    final pressedHandler = _getPressedHandler(editor, toolbar);
    final iconColor = (pressedHandler == null)
        ? toolbarTheme.disabledIconColor
        : toolbarTheme.iconColor;
    if (_icon != null && _text != null) {
      var style = _textStyle ?? new TextStyle();
      style = style.copyWith(color: iconColor).copyWith(fontSize: 8.0,fontWeight: FontWeight.w100);
      return RawZefyrButton(
        action: action,
        color: _getColor(editor, toolbarTheme),
        child: Column(
          children: <Widget>[
            new Icon(_icon, size: _iconSize, color: iconColor),
            new Text(_text, style: style)
          ],
        ),
        onPressed: _getPressedHandler(editor, toolbar),
      );
    } else if (_icon != null) {
      return RawZefyrButton.icon(
        action: action,
        icon: _icon,
        size: _iconSize,
        iconColor: iconColor,
        color: _getColor(editor, toolbarTheme),
        onPressed: _getPressedHandler(editor, toolbar),
      );
    } else {
      assert(_text != null);
      var style = _textStyle ?? new TextStyle();
      style = style.copyWith(color: iconColor);
      return RawZefyrButton(
        action: action,
        child: new Text(_text, style: style),
        color: _getColor(editor, toolbarTheme),
        onPressed: _getPressedHandler(editor, toolbar),
      );
    }
  }

  Color _getColor(ZefyrScope editor, ZefyrToolbarTheme theme) {
    if (isAttributeAction) {
      final attribute = kZefyrToolbarAttributeActions[action];
      final isToggled = (attribute is NotusAttribute)
          ? editor.selectionStyle.containsSame(attribute)
          : editor.selectionStyle.contains(attribute);
      return isToggled ? theme.toggleColor : null;
    }
    return null;
  }

  VoidCallback _getPressedHandler(
      ZefyrScope editor, ZefyrToolbarState toolbar) {
    if (onPressed != null) {
      return onPressed;
    } else if (isAttributeAction) {
      final attribute = kZefyrToolbarAttributeActions[action];
      if (attribute is NotusAttribute) {
        return () => _toggleAttribute(attribute, editor);
      }
    } else if (action == ZefyrToolbarAction.close) {
      return () => toolbar.closeOverlay();
    } else if (action == ZefyrToolbarAction.hideKeyboard) {
      return () => editor.hideKeyboard();
    }

    return null;
  }

  void _toggleAttribute(NotusAttribute attribute, ZefyrScope editor) {
    final isToggled = editor.selectionStyle.containsSame(attribute);
    if (isToggled) {
      editor.formatSelection(attribute.unset);
    } else {
      editor.formatSelection(attribute);
    }
  }
}

/// Raw button widget used by [ZefyrToolbar].
///
/// See also:
///
///   * [ZefyrButton], which wraps this widget and implements most of the
///     action-specific logic.
class RawZefyrButton extends StatelessWidget {
  const RawZefyrButton({
    Key key,
    @required this.action,
    @required this.child,
    @required this.color,
    @required this.onPressed,
  }) : super(key: key);

  /// Creates a [RawZefyrButton] containing an icon.
  RawZefyrButton.icon({
    @required this.action,
    @required IconData icon,
    double size,
    Color iconColor,
    @required this.color,
    @required this.onPressed,
  })  : child = new Icon(icon, size: size, color: iconColor),
        super();

  /// Toolbar action associated with this button.
  final ZefyrToolbarAction action;

  /// Child widget to show inside this button. Usually an icon.
  final Widget child;

  /// Background color of this button.
  final Color color;

  /// Callback to trigger when this button is pressed.
  final VoidCallback onPressed;

  /// Returns `true` if this button is currently toggled on.
  bool get isToggled => color != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = theme.buttonTheme.constraints.minHeight + 4.0;
    final constraints = theme.buttonTheme.constraints.copyWith(
        minWidth: width, maxHeight: theme.buttonTheme.constraints.minHeight);
    final radius = BorderRadius.all(Radius.circular(3.0));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 6.0),
      child: RawMaterialButton(
        shape: RoundedRectangleBorder(borderRadius: radius),
        elevation: 0.0,
        fillColor: color,
        constraints: constraints,
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

/// Controls heading styles.
///
/// When pressed, this button displays overlay toolbar with three
/// buttons for each heading level.
class HeadingButton extends StatefulWidget {
  const HeadingButton({Key key}) : super(key: key);

  @override
  _HeadingButtonState createState() => _HeadingButtonState();
}

class _HeadingButtonState extends State<HeadingButton> {
  @override
  Widget build(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    return toolbar.buildButton(
      context,
      ZefyrToolbarAction.headingLevel3,
//      onPressed: showOverlay,
    );
  }

  void showOverlay() {
    final toolbar = ZefyrToolbar.of(context);
    toolbar.showOverlay(buildOverlay);
  }

  Widget buildOverlay(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    final buttons = Row(
      children: <Widget>[
        SizedBox(width: 8.0),
        toolbar.buildButton(context, ZefyrToolbarAction.headingLevel1),
        toolbar.buildButton(context, ZefyrToolbarAction.headingLevel2),
        toolbar.buildButton(context, ZefyrToolbarAction.headingLevel3),
      ],
    );
    return ZefyrToolbarScaffold(body: buttons);
  }
}

/// Controls image attribute.
///
/// When pressed, this button displays overlay toolbar with three
/// buttons for each heading level.
class ImageButton extends StatefulWidget {
  const ImageButton({Key key}) : super(key: key);

  @override
  _ImageButtonState createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  @override
  Widget build(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    return toolbar.buildButton(
      context,
      ZefyrToolbarAction.image,
      onPressed: showOverlay,
    );
  }

  void showOverlay() {
    final toolbar = ZefyrToolbar.of(context);
    toolbar.showOverlay(buildOverlay);
  }

  Widget buildOverlay(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    final buttons = Row(
      children: <Widget>[
        SizedBox(width: 8.0),
        toolbar.buildButton(context, ZefyrToolbarAction.cameraImage,
            onPressed: _pickFromCamera),
        toolbar.buildButton(context, ZefyrToolbarAction.galleryImage,
            onPressed: _pickFromGallery),
        toolbar.buildButton(context, ZefyrToolbarAction.httpImage,
            onPressed: _pickeFromHttp),
      ],
    );
    return ZefyrToolbarScaffold(body: buttons);
  }

  void _pickFromCamera() async => _pickerImage(ZefyrImageDelegateType.camera);

  void _pickFromGallery() async => _pickerImage(ZefyrImageDelegateType.gallery);

  void _pickeFromHttp() async => _pickerImage(ZefyrImageDelegateType.http);

  void _pickerImage(ZefyrImageDelegateType type) async {
    final editor = ZefyrToolbar
        .of(context)
        .editor;
    final image = await editor.imageDelegate.pickImage(type);
    if (image != null)
      editor.formatSelection(NotusAttribute.embed.image(image));
  }
}
