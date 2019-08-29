// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notus/notus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'button_insert_text.dart';
import 'buttons.dart';
import 'scope.dart';
import 'theme.dart';

/// List of all button actions supported by [ZefyrToolbar] buttons.
enum ZefyrToolbarAction {
  undo,
  indent,
  lineBreak,
  center,
  bold,
  italic,
  link,
  unlink,
  clipboardCopy,
  openInBrowser,
  heading,
  headingLevel1,
  headingLevel2,
  headingLevel3,
  bulletList,
  numberList,
  code,
  quote,
  horizontalRule,
  image,
  cameraImage,
  galleryImage,
  httpImage,
  hideKeyboard,
  close,
  confirm,
}

final kZefyrToolbarAttributeActions = <ZefyrToolbarAction, NotusAttributeKey>{
  ZefyrToolbarAction.center: NotusAttribute.align.center,
  ZefyrToolbarAction.bold: NotusAttribute.bold,
  ZefyrToolbarAction.italic: NotusAttribute.italic,
  ZefyrToolbarAction.link: NotusAttribute.link,
  ZefyrToolbarAction.heading: NotusAttribute.heading,
  ZefyrToolbarAction.headingLevel1: NotusAttribute.heading.level1,
  ZefyrToolbarAction.headingLevel2: NotusAttribute.heading.level2,
  ZefyrToolbarAction.headingLevel3: NotusAttribute.heading.level3,
  ZefyrToolbarAction.bulletList: NotusAttribute.block.bulletList,
  ZefyrToolbarAction.numberList: NotusAttribute.block.numberList,
  ZefyrToolbarAction.code: NotusAttribute.block.code,
  ZefyrToolbarAction.quote: NotusAttribute.block.quote,
  ZefyrToolbarAction.horizontalRule: NotusAttribute.embed.horizontalRule,
};

/// Allows customizing appearance of [ZefyrToolbar].
abstract class ZefyrToolbarDelegate {
  /// Builds toolbar button for specified [action].
  ///
  /// Returned widget is usually an instance of [ZefyrButton].
  Widget buildButton(BuildContext context, ZefyrToolbarAction action,
      {VoidCallback onPressed});
}

/// Scaffold for [ZefyrToolbar].
class ZefyrToolbarScaffold extends StatelessWidget {
  const ZefyrToolbarScaffold({
    Key key,
    @required this.body,
    this.trailing,
    this.autoImplyTrailing: true,
  }) : super(key: key);

  final Widget body;
  final Widget trailing;
  final bool autoImplyTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = ZefyrTheme.of(context).toolbarTheme;
    final toolbar = ZefyrToolbar.of(context);
    final constraints =
        BoxConstraints.tightFor(height: ZefyrToolbar.kToolbarHeight);
    final children = <Widget>[
      Expanded(child: body),
    ];

    if (trailing != null) {
      children.add(trailing);
    } else if (autoImplyTrailing) {
      children.add(toolbar.buildButton(context, ZefyrToolbarAction.close));
    }
    return new Container(
      constraints: constraints,
      child: Material(color: theme.color, child: Row(children: children)),
    );
  }
}

/// Toolbar for [ZefyrEditor].
class ZefyrToolbar extends StatefulWidget implements PreferredSizeWidget {
  static const kToolbarHeight = 50.0;

  const ZefyrToolbar({
    Key key,
    @required this.editor,
    this.autoHide: true,
    this.delegate,
  }) : super(key: key);

  final ZefyrToolbarDelegate delegate;
  final ZefyrScope editor;

  /// Whether to automatically hide this toolbar when editor loses focus.
  final bool autoHide;

  static ZefyrToolbarState of(BuildContext context) {
    final _ZefyrToolbarScope scope =
        context.inheritFromWidgetOfExactType(_ZefyrToolbarScope);
    return scope?.toolbar;
  }

  @override
  ZefyrToolbarState createState() => ZefyrToolbarState();

  @override
  ui.Size get preferredSize => new Size.fromHeight(ZefyrToolbar.kToolbarHeight);
}

class _ZefyrToolbarScope extends InheritedWidget {
  _ZefyrToolbarScope({Key key, @required Widget child, @required this.toolbar})
      : super(key: key, child: child);

  final ZefyrToolbarState toolbar;

  @override
  bool updateShouldNotify(_ZefyrToolbarScope oldWidget) {
    return toolbar != oldWidget.toolbar;
  }
}

class ZefyrToolbarState extends State<ZefyrToolbar>
    with SingleTickerProviderStateMixin {
  final Key _toolbarKey = UniqueKey();
  final Key _overlayKey = UniqueKey();

  ZefyrToolbarDelegate _delegate;
  AnimationController _overlayAnimation;
  WidgetBuilder _overlayBuilder;
  Completer<void> _overlayCompleter;

  TextSelection _selection;

  void markNeedsRebuild() {
    setState(() {
      if (_selection != editor.selection) {
        _selection = editor.selection;
        closeOverlay();
      }
    });
  }

  Widget buildButton(BuildContext context, ZefyrToolbarAction action,
      {VoidCallback onPressed}) {
    return _delegate.buildButton(context, action, onPressed: onPressed);
  }

  Future<void> showOverlay(WidgetBuilder builder) async {
    assert(_overlayBuilder == null);
    final completer = new Completer<void>();
    setState(() {
      _overlayBuilder = builder;
      _overlayCompleter = completer;
      _overlayAnimation.forward();
    });
    return completer.future;
  }

  void closeOverlay() {
    if (!hasOverlay) return;
    _overlayAnimation.reverse().whenComplete(() {
      setState(() {
        _overlayBuilder = null;
        _overlayCompleter?.complete();
        _overlayCompleter = null;
      });
    });
  }

  bool get hasOverlay => _overlayBuilder != null;

  ZefyrScope get editor => widget.editor;

  @override
  void initState() {
    super.initState();
    _delegate = widget.delegate ?? new _DefaultZefyrToolbarDelegate();
    _overlayAnimation = new AnimationController(
        vsync: this, duration: Duration(milliseconds: 100));
    _selection = editor.selection;
  }

  @override
  void didUpdateWidget(ZefyrToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.delegate != oldWidget.delegate) {
      _delegate = widget.delegate ?? new _DefaultZefyrToolbarDelegate();
    }
  }

  @override
  void dispose() {
    _overlayAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layers = <Widget>[];

    // Must set unique key for the toolbar to prevent it from reconstructing
    // new state each time we toggle overlay.
    final toolbar = ZefyrToolbarScaffold(
      key: _toolbarKey,
      body: ZefyrButtonList(buttons: _buildButtons(context)),
      trailing: buildButton(context, ZefyrToolbarAction.hideKeyboard),
    );

    layers.add(toolbar);

    if (hasOverlay) {
      Widget widget = new Builder(builder: _overlayBuilder);
      assert(widget != null);
      final overlay = FadeTransition(
        key: _overlayKey,
        opacity: _overlayAnimation,
        child: widget,
      );
      layers.add(overlay);
    }

    final constraints =
        BoxConstraints.tightFor(height: ZefyrToolbar.kToolbarHeight);
    return _ZefyrToolbarScope(
      toolbar: this,
      child: Container(
        constraints: constraints,
        child: Stack(children: layers),
      ),
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    final buttons = <Widget>[
      //custom
      InsertTextButton(ZefyrToolbarAction.indent),
      InsertTextButton(ZefyrToolbarAction.lineBreak),
      buildButton(context, ZefyrToolbarAction.center),

//      buildButton(context, ZefyrToolbarAction.bold),
//      buildButton(context, ZefyrToolbarAction.italic),
//      InsertLinkButton(),
      HeadingButton(),
      ImageButton(),
//      LinkButton(),
      buildButton(context, ZefyrToolbarAction.bulletList),
      buildButton(context, ZefyrToolbarAction.numberList),
      buildButton(context, ZefyrToolbarAction.quote),
      buildButton(context, ZefyrToolbarAction.code),
      buildButton(context, ZefyrToolbarAction.horizontalRule),
    ];
    return buttons;
  }
}

/// Scrollable list of toolbar buttons.
class ZefyrButtonList extends StatefulWidget {
  const ZefyrButtonList({Key key, @required this.buttons}) : super(key: key);
  final List<Widget> buttons;

  @override
  _ZefyrButtonListState createState() => _ZefyrButtonListState();
}

class _ZefyrButtonListState extends State<ZefyrButtonList> {
  final ScrollController _controller = new ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
    // Workaround to allow scroll controller attach to our ListView so that
    // we can detect if overflow arrows need to be shown on init.
    // TODO: find a better way to detect overflow
    Timer.run(_handleScroll);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZefyrTheme.of(context).toolbarTheme;
    final color = theme.iconColor;
    final list = ListView(
      scrollDirection: Axis.horizontal,
      controller: _controller,
      children: widget.buttons,
      physics: ClampingScrollPhysics(),
    );

    final leftArrow = _showLeftArrow
        ? Icon(Icons.arrow_left, size: 18.0, color: color)
        : null;
    final rightArrow = _showRightArrow
        ? Icon(Icons.arrow_right, size: 18.0, color: color)
        : null;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 12.0,
          height: ZefyrToolbar.kToolbarHeight,
          child: Container(child: leftArrow, color: theme.color),
        ),
        Expanded(child: ClipRect(child: list)),
        SizedBox(
          width: 12.0,
          height: ZefyrToolbar.kToolbarHeight,
          child: Container(child: rightArrow, color: theme.color),
        ),
      ],
    );
  }

  void _handleScroll() {
    setState(() {
      _showLeftArrow =
          _controller.position.minScrollExtent != _controller.position.pixels;
      _showRightArrow =
          _controller.position.maxScrollExtent != _controller.position.pixels;
    });
  }
}

class _DefaultZefyrToolbarDelegate implements ZefyrToolbarDelegate {
  static const kDefaultButtonIcons = {
    ZefyrToolbarAction.undo: Icons.undo,
    ZefyrToolbarAction.indent: Icons.format_indent_increase,
    ZefyrToolbarAction.lineBreak: Icons.play_for_work,
    ZefyrToolbarAction.center: Icons.format_align_center,

    ZefyrToolbarAction.bold: Icons.format_bold,
    ZefyrToolbarAction.italic: Icons.format_italic,
    ZefyrToolbarAction.link: Icons.link,
    ZefyrToolbarAction.unlink: Icons.link_off,
    ZefyrToolbarAction.clipboardCopy: Icons.content_copy,
    ZefyrToolbarAction.openInBrowser: Icons.open_in_new,
//    ZefyrToolbarAction.heading: Icons.format_size,
    ZefyrToolbarAction.headingLevel3: Icons.title,
    ZefyrToolbarAction.bulletList: Icons.format_list_bulleted,
    ZefyrToolbarAction.numberList: Icons.format_list_numbered,
    ZefyrToolbarAction.code: Icons.code,
    ZefyrToolbarAction.quote: Icons.format_quote,
    ZefyrToolbarAction.horizontalRule: Icons.remove,
    ZefyrToolbarAction.image: Icons.photo,
    ZefyrToolbarAction.cameraImage: Icons.photo_camera,
    ZefyrToolbarAction.galleryImage: Icons.photo_library,
    ZefyrToolbarAction.httpImage: Icons.http,
    ZefyrToolbarAction.hideKeyboard: Icons.keyboard_hide,
    ZefyrToolbarAction.close: Icons.close,
    ZefyrToolbarAction.confirm: Icons.check,
  };

  static const kDefaultButtonNames = {
    ZefyrToolbarAction.undo: '撤销',
    ZefyrToolbarAction.indent: '缩进',
    ZefyrToolbarAction.lineBreak: '换行',
    ZefyrToolbarAction.center: '居中',
    ZefyrToolbarAction.link: '链接',
    ZefyrToolbarAction.headingLevel3: '标题',
    ZefyrToolbarAction.bulletList: '列表',
    ZefyrToolbarAction.numberList: '列表',
    ZefyrToolbarAction.code: '代码',
    ZefyrToolbarAction.quote: '引用',
    ZefyrToolbarAction.horizontalRule: '分割线',
    ZefyrToolbarAction.image: '图片',
  };

  static const kSpecialIconSizes = {
    ZefyrToolbarAction.unlink: 20.0,
    ZefyrToolbarAction.clipboardCopy: 20.0,
    ZefyrToolbarAction.openInBrowser: 20.0,
    ZefyrToolbarAction.close: 20.0,
    ZefyrToolbarAction.confirm: 20.0,
  };

  static const kDefaultButtonTexts = {
    ZefyrToolbarAction.headingLevel1: 'H1',
    ZefyrToolbarAction.headingLevel2: 'H2',
    ZefyrToolbarAction.headingLevel3: 'H3',
  };

  @override
  Widget buildButton(BuildContext context, ZefyrToolbarAction action,
      {VoidCallback onPressed}) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.caption
        .copyWith(fontWeight: FontWeight.bold, fontSize: 14.0);
    if (kDefaultButtonIcons.containsKey(action)) {
      final icon = kDefaultButtonIcons[action];
      final size = kSpecialIconSizes[action];
      return ZefyrButton.icon(
        action: action,
        icon: icon,
        iconSize: size,
        onPressed: onPressed,
        textStyle: textStyle,
        text: kDefaultButtonNames[action],
      );
    } else {
      final text = kDefaultButtonTexts[action];
      assert(text != null);
      return ZefyrButton.text(
        action: action,
        text: text,
        style: textStyle,
        onPressed: onPressed,
      );
    }
  }
}

class LinkButton extends StatefulWidget {
  const LinkButton({Key key}) : super(key: key);

  @override
  _LinkButtonState createState() => _LinkButtonState();
}

class _LinkButtonState extends State<LinkButton> {
  final TextEditingController _inputController = TextEditingController();
  Key _inputKey;
  bool _formatError = false;
  ZefyrScope _editor;

  bool get isEditing => _inputKey != null;

  @override
  Widget build(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    final editor = toolbar.editor;
    final enabled =
        hasLink(editor.selectionStyle) || !editor.selection.isCollapsed;

    return toolbar.buildButton(
      context,
      ZefyrToolbarAction.link,
      onPressed: enabled ? showOverlay : null,
    );
  }

  bool hasLink(NotusStyle style) => style.contains(NotusAttribute.link);

  String getLink([String defaultValue]) {
    final editor = ZefyrToolbar.of(context).editor;
    final attrs = editor.selectionStyle;
    if (hasLink(attrs)) {
      return attrs.value(NotusAttribute.link);
    }
    return defaultValue;
  }

  void showOverlay() {
    final toolbar = ZefyrToolbar.of(context);
    toolbar.showOverlay(buildOverlay).whenComplete(cancelEdit);
  }

  void closeOverlay() {
    final toolbar = ZefyrToolbar.of(context);
    toolbar.closeOverlay();
  }

  void edit() {
    final toolbar = ZefyrToolbar.of(context);
    setState(() {
      _inputKey = new UniqueKey();
      _inputController.text = getLink('https://');
      _inputController.addListener(_handleInputChange);
      toolbar.markNeedsRebuild();
    });
  }

  void doneEdit() {
    final toolbar = ZefyrToolbar.of(context);
    setState(() {
      var error = false;
      if (_inputController.text.isNotEmpty) {
        try {
          var uri = Uri.parse(_inputController.text);
          if ((uri.isScheme('https') || uri.isScheme('http')) &&
              uri.host.isNotEmpty) {
            toolbar.editor.formatSelection(
                NotusAttribute.link.fromString(_inputController.text));
          } else {
            error = true;
          }
        } on FormatException {
          error = true;
        }
      }
      if (error) {
        _formatError = error;
        toolbar.markNeedsRebuild();
      } else {
        _inputKey = null;
        _inputController.text = '';
        _inputController.removeListener(_handleInputChange);
        toolbar.markNeedsRebuild();
        toolbar.editor.focus();
      }
    });
  }

  void cancelEdit() {
    if (mounted) {
      final editor = ZefyrToolbar.of(context).editor;
      setState(() {
        _inputKey = null;
        _inputController.text = '';
        _inputController.removeListener(_handleInputChange);
        editor.focus();
      });
    }
  }

  void unlink() {
    final editor = ZefyrToolbar.of(context).editor;
    editor.formatSelection(NotusAttribute.link.unset);
    closeOverlay();
  }

  void copyToClipboard() {
    var link = getLink();
    assert(link != null);
    Clipboard.setData(new ClipboardData(text: link));
  }

  void openInBrowser() async {
    final editor = ZefyrToolbar.of(context).editor;
    var link = getLink();
    assert(link != null);
    if (await canLaunch(link)) {
      editor.hideKeyboard();
      await launch(link, forceWebView: true);
    }
  }

  void _handleInputChange() {
    final toolbar = ZefyrToolbar.of(context);
    setState(() {
      _formatError = false;
      toolbar.markNeedsRebuild();
    });
  }

  Widget buildOverlay(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    final style = toolbar.editor.selectionStyle;

    String value = 'Tap to edit link';
    if (style.contains(NotusAttribute.link)) {
      value = style.value(NotusAttribute.link);
    }
    final clipboardEnabled = value != 'Tap to edit link';
    final body = !isEditing
        ? _LinkView(value: value, onTap: edit)
        : _LinkInput(
      key: _inputKey,
      controller: _inputController,
      formatError: _formatError,
    );
    final items = <Widget>[Expanded(child: body)];
    if (!isEditing) {
      final unlinkHandler = hasLink(style) ? unlink : null;
      final copyHandler = clipboardEnabled ? copyToClipboard : null;
      final openHandler = hasLink(style) ? openInBrowser : null;
      final buttons = <Widget>[
        toolbar.buildButton(context, ZefyrToolbarAction.unlink,
            onPressed: unlinkHandler),
        toolbar.buildButton(context, ZefyrToolbarAction.clipboardCopy,
            onPressed: copyHandler),
        toolbar.buildButton(
          context,
          ZefyrToolbarAction.openInBrowser,
          onPressed: openHandler,
        ),
      ];
      items.addAll(buttons);
    }
    final trailingPressed = isEditing ? doneEdit : closeOverlay;
    final trailingAction =
    isEditing ? ZefyrToolbarAction.confirm : ZefyrToolbarAction.close;

    return ZefyrToolbarScaffold(
      body: Row(children: items),
      trailing: toolbar.buildButton(
        context,
        trailingAction,
        onPressed: trailingPressed,
      ),
    );
  }
}

class _LinkInput extends StatefulWidget {
  final TextEditingController controller;
  final bool formatError;

  const _LinkInput(
      {Key key, @required this.controller, this.formatError: false})
      : super(key: key);

  @override
  _LinkInputState createState() {
    return new _LinkInputState();
  }
}

class _LinkInputState extends State<_LinkInput> {
  final FocusNode _focusNode = FocusNode();

  ZefyrScope _editor;
  bool _didAutoFocus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFocus) {
      FocusScope.of(context).requestFocus(_focusNode);
      _didAutoFocus = true;
    }

    final toolbar = ZefyrToolbar.of(context);

    if (_editor != toolbar.editor) {
      _editor?.toolbarFocusNode = null;
      _editor = toolbar.editor;
      _editor.toolbarFocusNode = _focusNode;
    }
  }

  @override
  void dispose() {
    _editor?.toolbarFocusNode = null;
    _focusNode.dispose();
    _editor = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolbarTheme = ZefyrTheme.of(context).toolbarTheme;
    final color =
    widget.formatError ? Colors.redAccent : toolbarTheme.iconColor;
    final style = theme.textTheme.subhead.copyWith(color: color);
    return TextField(
      style: style,
      keyboardType: TextInputType.url,
      focusNode: _focusNode,
      controller: widget.controller,
      autofocus: true,
      decoration: new InputDecoration(
        hintText: 'https://',
        filled: true,
        fillColor: toolbarTheme.color,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(10.0),
      ),
    );
  }
}

class _LinkView extends StatelessWidget {
  const _LinkView({Key key, @required this.value, this.onTap})
      : super(key: key);
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolbarTheme = ZefyrTheme.of(context).toolbarTheme;
    Widget widget = new ClipRect(
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          Container(
            alignment: AlignmentDirectional.centerStart,
            constraints: BoxConstraints(minHeight: ZefyrToolbar.kToolbarHeight),
            padding: const EdgeInsets.all(10.0),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.subhead
                  .copyWith(color: toolbarTheme.disabledIconColor),
            ),
          )
        ],
      ),
    );
    if (onTap != null) {
      widget = GestureDetector(
        child: widget,
        onTap: onTap,
      );
    }
    return widget;
  }
}
