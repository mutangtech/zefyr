import 'package:flutter/material.dart';

import '../../zefyr.dart';
import 'toolbar.dart';

const _InsertTextMap = {
  ZefyrToolbarAction.indent: '    ',
  ZefyrToolbarAction.lineBreak: '\n'
};

class InsertTextButton extends StatefulWidget {
  final ZefyrToolbarAction action;

  const InsertTextButton(this.action, {Key key}) : super(key: key);

  @override
  _InsertTextButtonState createState() => _InsertTextButtonState();
}

class _InsertTextButtonState extends State<InsertTextButton> {
  @override
  Widget build(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    return toolbar.buildButton(
      context,
      widget.action,
      onPressed: _doInsert,
    );
  }

  void _doInsert() {
    if (!_InsertTextMap.containsKey(widget.action)) {
      return;
    }
    String value = _InsertTextMap[widget.action];

    final editor = ZefyrToolbar.of(context).editor;
    int pos = editor.selection.baseOffset;
    editor.controller.document.insert(pos, value);

    editor.updateSelection(
        TextSelection.fromPosition(TextPosition(offset: pos + value.length)),
        source: ChangeSource.local);
    print('Insert value ${value}');
  }
}
