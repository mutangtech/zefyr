import 'package:example/src/zefyr_utils.dart';
import 'package:flutter/material.dart';
import 'package:zefyr/zefyr.dart';

class CustomImageDelegate extends ZefyrDefaultImageDelegate {
  BuildContext context;

  CustomImageDelegate(this.context);

  @override
  Widget buildImage(BuildContext context, String imageSource) {
    // We use custom "asset" scheme to distinguish asset images from other files.
    print("加载图片 imageSource=$imageSource");
    if (imageSource.startsWith('asset://')) {
      final asset = new AssetImage(imageSource.replaceFirst('asset://', ''));
      return new Image(image: asset);
    } else if (imageSource.startsWith("http://") ||
        imageSource.startsWith("https://")) {
      return Image(image: NetworkImage(imageSource));
    } else {
      return super.buildImage(context, imageSource);
    }
  }

  @override
  Future<String> pickImage(ZefyrImageDelegateType source) {
    if (source == ZefyrImageDelegateType.http) {
      return _pickImageByHttp(context);
    }
    return super.pickImage(source);
  }

  Future<String> _pickImageByHttp(BuildContext context) async {
    String inputUrl;
    var dialog = AlertDialog(
      content: TextField(
        autofocus: true,
        decoration: InputDecoration(
            hintText: 'https:// 或者 http:// 链接',
            labelText: '输入图片网址',
            focusColor: Colors.blueAccent),
        onChanged: (value) {
          if (!isHttp(value)) {
            print('错误的图片链接');
            return;
          }
          inputUrl = value;
        },
      ),
      actions: <Widget>[
        FlatButton(
          child: Text(
            '取消',
            style: TextStyle(color: Colors.grey[700]),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        FlatButton(
          child: Text('确定'),
          onPressed: () {
            if (!isHttp(inputUrl)) {
              return;
            }
            Navigator.of(context).pop(inputUrl);
          },
        )
      ],
    );
    return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return dialog;
        });
  }
}
