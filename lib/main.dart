import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Add this line
import 'package:super_clipboard/super_clipboard.dart';

import 'clipboard/clipboard_listener.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isServerRunning = false; // Add this line to track the server status
  String _inputText = '';
  Uint8List? _imageData;
  String _ipAddress = '192.168.1.38'; // Add this line to store the IP address
  String _port = '1234';
  HttpServer? _server;
  List<Widget> _outputList = []; // Add this line to store the output list
  Map<int, Uint8List> _clipboardData =
      {}; // Add this line to store the clipboard data
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    listenToClipboardChanges(); // Add this line to start listening to clipboard changes
  }

  Future<void> _startServer() async {
    if (_isServerRunning) {
      await _server?.close();

      setState(() {
        _isServerRunning = false;
      });
    } else {
      final int portNumber = int.tryParse(_port) ?? 1234;
      _server = await HttpServer.bind(InternetAddress.anyIPv4, portNumber);
      print('Server listening on port ${_server!.port}');

      setState(() {
        _isServerRunning = true;
      });

      await for (HttpRequest request in _server!) {
        handleRequest(request);
      }
    }
  }

  // void handleRequest(HttpRequest request) {
  //   // 打印请求方法和路径
  //
  //   // final response = request.response;
  //   // if (request.uri.path == '/image') {
  //   //   if (_imageData != null) {
  //   //     response.headers.contentType = ContentType('image', 'png');
  //   //     response.add(_imageData!);
  //   //   } else {
  //   //     response.statusCode = HttpStatus.notFound;
  //   //   }
  //   // } else {
  //   //   response.statusCode = HttpStatus.notFound;
  //   // }
  //   // response.close();
  // }
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  void handleRequest(HttpRequest request) {
    // 打印请求方法和路径
    print('Request ${request.method}: ${request.uri.path}');

    if (request.method == 'POST' && request.uri.path == '/image') {
      final completer = Completer<List<int>>();
      final chunks = <int>[];
      request.listen(
        (data) => chunks.addAll(data),
        onDone: () => completer.complete(chunks),
        onError: completer.completeError,
        cancelOnError: true,
      );
      completer.future.then((value) {
        final bytes = base64Decode(String.fromCharCodes(value));
        setState(() {
          _imageData = Uint8List.fromList(bytes);
          var index = _outputList.length;
          _clipboardData[_outputList.length] = _imageData!;

          _outputList.add(Padding(
            padding: const EdgeInsets.all(8.0), // Add padding to the image
            child: Align(
              alignment: Alignment.center, // Align the image to the center
              child: GestureDetector(
                onTapDown: (TapDownDetails details) {
                  showMenu(
                    context: context,
                    position: RelativeRect.fromLTRB(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                    ),
                    items: <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'copy',
                        child: Text('Copy to clipboard'),
                      ),
                    ],
                  ).then((String? value) {
                    if (value == 'copy') {
                      // 将图片数据写入剪贴板
                      final item = DataWriterItem();
                      item.add(
                          Formats.png(_clipboardData[index]!)); // 使用当前索引访问图片数据
                      final clipboard = SystemClipboard.instance;
                      clipboard!.write([item]);
                    }
                  });
                },
                child: Image.memory(_imageData!),
              ),
            ),
          ));

          // 将图片数据写入剪贴板
          final item = DataWriterItem();
          item.add(Formats.png(_imageData!));
          final clipboard = SystemClipboard.instance;
          clipboard!.write([item]);

          _scrollToBottom(); // Scroll to bottom after a small delay
        });
        request.response
          ..statusCode = HttpStatus.ok
          ..close();
      });
    } else if (request.uri.path == '/text') {
      final completer = Completer<List<int>>();
      final chunks = <int>[];
      request.listen(
        (data) => chunks.addAll(data),
        onDone: () => completer.complete(chunks),
        onError: completer.completeError,
        cancelOnError: true,
      );
      completer.future.then((value) {
        final text = utf8.decode(value); // Use UTF-8 to decode the characters
        setState(() {
          // _outputList.add(Text(text));
          _outputList.add(GestureDetector(
            onTapDown: (TapDownDetails details) {
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                  details.globalPosition.dx,
                  details.globalPosition.dy,
                  details.globalPosition.dx,
                  details.globalPosition.dy,
                ),
                items: <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'copy',
                    child: Text('Copy to clipboard'),
                  ),
                ],
              ).then((String? value) {
                if (value == 'copy') {
                  Clipboard.setData(ClipboardData(text: text));
                }
              });
            },
            child: Text(text),
          ));

          Clipboard.setData(ClipboardData(text: text));

          _scrollToBottom(); // Scroll to bottom after a small delay
        });
        request.response
          ..statusCode = HttpStatus.ok
          ..close();
      });
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
    }
  }

  void _scrollToBottom() {
    // todo 通过延时来让列表数据更新后再滚动到底部, 有没有其他更好的方法？
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // void _selfSendText(String text) {
  //   final now = DateTime.now();
  //   final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
  //   final formattedDate = formatter.format(now);
  //
  //   setState(() {
  //     _outputList.add(Text('自己 [$formattedDate]\n$text'));
  //   });
  //
  //   _scrollToBottom();
  // }

  void _selfSendText(Widget content) {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final formattedDate = formatter.format(now);

    setState(() {
      _outputList.add(Padding(
        padding: const EdgeInsets.all(0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自己 [$formattedDate]'),
            content,
          ],
        ),
      ));
    });

    _scrollToBottom();
  }

  Future<void> _copyClipboardContent() async {
    if (_inputText.isNotEmpty) {
      // 将输入框的文本数据发送给 localhost:1234/text
      final client = HttpClient();
      final request =
          await client.postUrl(Uri.parse('http://$_ipAddress:$_port/text'));
      request.headers.contentType = ContentType.text;
      request.write(_inputText);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        print('HTTP request failed, status: ${response.statusCode}.');
      }
      await response.drain();
      client.close();

      _selfSendText(Text(_inputText));

      // 清空输入框的内容
      setState(() {
        _inputText = '';
      });
      return;
    }

    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return; // Clipboard API is not supported on this platform.
    }
    final reader = await clipboard.read();

    if (reader.canProvide(Formats.png)) {
      reader.getFile(Formats.png, (file) async {
        final stream = file.getStream();
        final completer = Completer<List<int>>();
        final chunks = <int>[];
        stream.listen(
          (data) => chunks.addAll(data),
          onDone: () => completer.complete(chunks),
          onError: completer.completeError,
          cancelOnError: true,
        );
        final bytes = Uint8List.fromList(await completer.future);
        // setState(() {
        //   _imageData = bytes;
        // });

        // 将读取到的图片数据base64编码后发送给 localhost:1234/image
        final client = HttpClient();
        // final request = await client.postUrl(
        //     Uri.parse('http://127.0.0.1:1234/image'));
        final request =
            await client.postUrl(Uri.parse('http://$_ipAddress:$_port/image'));
        request.headers
            .set(HttpHeaders.contentTypeHeader, 'application/base64');
        request.write(base64Encode(bytes!));
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          print('HTTP request failed, status: ${response.statusCode}.');
        }
        await response.drain();
        client.close();

        _selfSendText(Image.memory(bytes));
      });
    } else if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);

      if (text == null || text.trim().isEmpty) {
        return;
      }

      // 将读取到的文本数据发送给 localhost:1234/text
      final client = HttpClient();
      final request =
          await client.postUrl(Uri.parse('http://$_ipAddress:$_port/text'));
      request.headers.contentType = ContentType.text;
      request.write(text);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        print('HTTP request failed, status: ${response.statusCode}.');
      }
      await response.drain();
      client.close();

      _selfSendText(Text(text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: <Widget>[
              //_imageData != null ? Image.memory(_imageData!) : Container(),
              // ClipboardListenerWidget(), // Add this line
              TextField(
                onChanged: (value) {
                  _ipAddress =
                      value; // Update the IP address when the user types
                },
                decoration: InputDecoration(
                  labelText: 'Enter IP address',
                ),
                controller: TextEditingController(
                    text:
                        _ipAddress), // Set the default value to the current IP address
              ),
              TextField(
                onChanged: (value) {
                  _port = value;
                },
                decoration: InputDecoration(
                  labelText: 'Enter port number',
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: _port),
              ),
              // 添加一个间隙
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _startServer,
                child: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                    _isServerRunning ? Colors.red : Colors.green,
                  ),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.separated(
                    controller: _scrollController, // Use the ScrollController
                    itemCount: _outputList.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey),
                    itemBuilder: (context, index) {
                      return _outputList[index];
                    },
                    padding:
                        EdgeInsets.only(bottom: 6.0), // 不加这个边框导致最后一行文字部分被遮挡
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      onChanged: (value) {
                        _inputText = value;
                      },
                      decoration: InputDecoration(
                        labelText: 'Enter your data',
                      ),
                      controller: TextEditingController.fromValue(
                        TextEditingValue(
                          text: _inputText,
                          selection: TextSelection.collapsed(
                              offset: _inputText.length),
                        ),
                      ),
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: _copyClipboardContent,
                    tooltip: 'Send',
                    child: const Icon(Icons.send),
                  ),
                ],
              )
            ],
          )),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _copyClipboardContent,
      //   tooltip: 'Send',
      //   child: const Icon(Icons.send),
      // ),
    );
  }
}
