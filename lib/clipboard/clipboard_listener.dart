// import 'package:clipboard_listener/clipboard_listener.dart';
// import 'package:flutter/material.dart';
import 'package:clipboard_listener/clipboard_listener.dart';
import 'package:flutter/services.dart';
//
// class ClipboardListenerWidget extends StatefulWidget {
//   @override
//   _ClipboardListenerWidgetState createState() =>
//       _ClipboardListenerWidgetState();
// }
//
// class _ClipboardListenerWidgetState extends State<ClipboardListenerWidget> {
//   String _clipboardData = '';
//
//   @override
//   void initState() {
//     super.initState();
//     ClipboardListener.addListener(() async {
//       final data = await Clipboard.getData(Clipboard.kTextPlain);
//       if (data != null) {
//         setState(() {
//           _clipboardData = data.text ?? '';
//         });
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     ClipboardListener.removeListener(() { });
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Text('Clipboard data: $_clipboardData');
//   }
// }

void readFromClipboard() async {
  ClipboardData? clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
  String? clipboardText = clipboardData?.text;
  print('Text from clipboard: $clipboardText');
}
void listenToClipboardChanges() {
  //Clipboard.setData(ClipboardData(text: "Initial text")); // 设置初始文本
  ClipboardListener.addListener(() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null) {
      print('Clipboard text changed: ${data.text}');
    }
  });
}
