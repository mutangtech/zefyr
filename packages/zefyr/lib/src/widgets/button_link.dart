import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notus/notus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'scope.dart';
import 'theme.dart';
import 'toolbar.dart';

class InsertLinkButton extends StatefulWidget {
  const InsertLinkButton({Key key}) : super(key: key);

  @override
  _InsertLinkButtonState createState() => _InsertLinkButtonState();
}

class _InsertLinkButtonState extends State<InsertLinkButton> {
  final TextEditingController _inputController = TextEditingController();
  Key _inputKey;
  bool _formatError = false;
  ZefyrScope _editor;

  bool get isEditing => _inputKey != null;

  final TextEditingController _titleCtr = TextEditingController();
  final TextEditingController _linkCtr = TextEditingController();

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
//    _titleCtr.dispose();
//    _linkCtr.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    final editor = toolbar.editor;
    final enabled =
        hasLink(editor.selectionStyle) || !editor.selection.isCollapsed;

    return toolbar.buildButton(
      context,
      ZefyrToolbarAction.link,
      onPressed: showOverlay,
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

  /// 提取选中的地方的链接文字内容
  String getLinkTitle() {
    final editor = ZefyrToolbar.of(context).editor;
    final attrs = editor.selectionStyle;
    print('=======attrs ${attrs.values} ${editor.selection}  ');
    if (hasLink(attrs)) {
      //todo
    }
    return '';
  }

  void showOverlay() {
    final toolbar = ZefyrToolbar.of(context);
    String link = getLink("https://");
    showTextFieldAlertDialog(context, '设置链接', getLinkTitle(), link, _titleCtr,
        _linkCtr, _onConfirmDialog, null);
  }

  void _onConfirmDialog(String title, String link) {
    print('输入链接内容 ${title} ${link}');
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
    final body = isEditing
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

Future<String> showTextFieldAlertDialog(
    BuildContext context,
    String dialogTitle,
    String linkTitle,
    String linkContent,
    TextEditingController titleCtr,
    TextEditingController linkCtr,
    Function confirmCallback,
    Function cancelCallback) async {
  TextStyle style = TextStyle(fontSize: 12.0);
  var dialog = AlertDialog(
    title: Text(dialogTitle),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('标题', style: style),
            SizedBox(width: 8.0),
            Expanded(
              child: TextField(
                  style: style,
                  keyboardType: TextInputType.text,
                  autofocus: true,
                  controller: titleCtr),
            )
          ],
        ),
        Row(
          children: <Widget>[
            Text('链接', style: style),
            SizedBox(width: 8.0),
            Expanded(
              child: TextField(
                style: style,
                keyboardType: TextInputType.url,
//              focusNode: _focusNode,
                controller: linkCtr,
                decoration: new InputDecoration(
                  hintText: 'https://',
                  filled: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(10.0),
                ),
              ),
            )
          ],
        ),
      ],
    ),
    actions: <Widget>[
      FlatButton(
        child: Text(
          '取消',
          style: TextStyle(color: Colors.grey[700]),
        ),
        onPressed: () {
          Navigator.pop(context);
          if (cancelCallback != null) {
            cancelCallback();
          }
        },
      ),
      FlatButton(
        child: Text('确定'),
        onPressed: () {
          print('输入链接内容11 ${titleCtr.text} ${linkCtr.text}');
          if (confirmCallback != null) {
            confirmCallback(titleCtr.text, linkCtr.text);
          }
          Navigator.pop(context);
        },
      )
    ],
  );

  if (titleCtr != null && linkTitle != null && linkTitle.isNotEmpty) {
    titleCtr.text = linkTitle;
  }
  if (linkCtr != null && linkContent != null && linkContent.isNotEmpty) {
    linkCtr.text = linkContent;
  }
  print("链接内容 ${linkContent}");
  return await showDialog<String>(
      context: context,
      builder: (context) {
        return dialog;
      });
}
