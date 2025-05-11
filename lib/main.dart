import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pax_printer_utility/flutter_pax_printer_utility.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impresora de Bolsillo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Impresora de Bolsillo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _imageFile;
  bool _printing = false;
  String? _status;

  Future<void> _pickImage() async {
    if (Platform.isAndroid) {
      // Request storage permissions for Android 6.0
      if (await Permission.storage.status.isDenied) {
        final status = await Permission.storage.request();
        if (status.isDenied) {
          setState(() {
            _status = 'Storage permission denied.';
          });
          return;
        }
      }

      // Check if storage permission is permanently denied
      if (await Permission.storage.isPermanentlyDenied) {
        setState(() {
          _status =
              'Storage permission permanently denied. Please enable it in settings.';
        });
        return;
      }
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _status = 'Image selected successfully!';
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _status = 'Error picking image: $e';
      });
    }
  }

  Future<void> _printImage() async {
    if (_imageFile == null) return;
    setState(() {
      _printing = true;
      _status = null;
    });
    try {
      print('Initializing printer...');
      await FlutterPaxPrinterUtility.init;

      // Add delay after initialization
      await Future.delayed(const Duration(milliseconds: 500));

      // Set font and spacing like in the example
      await FlutterPaxPrinterUtility.fontSet(
        EFontTypeAscii.FONT_24_24,
        EFontTypeExtCode.FONT_24_24,
      );
      await FlutterPaxPrinterUtility.spaceSet(0, 10);

      // Set maximum gray level for best quality
      await FlutterPaxPrinterUtility.setGray(4);

      // Print header with better spacing
      await FlutterPaxPrinterUtility.printStr('\nPRINTING IMAGE\n\n', null);
      await FlutterPaxPrinterUtility.step(2);

      // Read image bytes
      Uint8List bytes = await _imageFile!.readAsBytes();

      // Print the bitmap with delay before and after
      print('Printing image...');
      await Future.delayed(const Duration(milliseconds: 300));
      await FlutterPaxPrinterUtility.printBitmap(bytes);
      await Future.delayed(const Duration(milliseconds: 500));

      // Add more spacing and start printing
      await FlutterPaxPrinterUtility.step(200);
      var status = await FlutterPaxPrinterUtility.start();

      // Add final delay to ensure complete printing
      await Future.delayed(const Duration(milliseconds: 1000));

      print('Print status: $status');
      setState(() {
        _status = 'Image printed successfully!';
      });
    } catch (e) {
      print('Error printing image: $e');
      setState(() {
        _status = 'Image print failed: $e';
      });
    } finally {
      setState(() {
        _printing = false;
      });
    }
  }

  Future<void> _printTestQRCode() async {
    setState(() {
      _printing = true;
      _status = null;
    });
    try {
      print('Initializing printer...');
      await FlutterPaxPrinterUtility.init;

      // Set font and spacing like in the example
      await FlutterPaxPrinterUtility.fontSet(
        EFontTypeAscii.FONT_24_24,
        EFontTypeExtCode.FONT_24_24,
      );
      await FlutterPaxPrinterUtility.spaceSet(0, 10);
      await FlutterPaxPrinterUtility.setGray(1);

      // Print header text
      await FlutterPaxPrinterUtility.printStr('SCAN QR CODE BELOW', null);
      await FlutterPaxPrinterUtility.printStr('\n\n', null);

      // Print QR code with larger size (512x512 like in example)
      print('Printing QR code...');
      await FlutterPaxPrinterUtility.printQRCode('TEST123', 512, 512);

      // Add some spacing and start printing
      await FlutterPaxPrinterUtility.step(150);
      var status = await FlutterPaxPrinterUtility.start();

      print('Print status: $status');
      setState(() {
        _status = 'Print completed!';
      });
    } catch (e) {
      print('Error during printing: $e');
      setState(() {
        _status = 'Print failed: $e';
      });
    } finally {
      setState(() {
        _printing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            // Column is also a layout widget. It takes a list of children and
            // arranges them vertically. By default, it sizes itself to fit its
            // children horizontally, and tries to be as tall as its parent.
            //
            // Column has various properties to control how it sizes itself and
            // how it positions its children. Here we use mainAxisAlignment to
            // center the children vertically; the main axis here is the vertical
            // axis because Columns are vertical (the cross axis would be
            // horizontal).
            //
            // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
            // action in the IDE, or press "p" in the console), to see the
            // wireframe for each widget.
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _imageFile != null
                  ? Image.file(_imageFile!, height: 200)
                  : const Text('No se ha seleccionado ninguna imagen.'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _printing ? null : _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Seleccionar imagen de la galería'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _printing || _imageFile == null ? null : _printImage,
                icon: const Icon(Icons.print),
                label:
                    _printing
                        ? const Text('Imprimiendo...')
                        : const Text('Imprimir imagen'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _printing ? null : _printTestQRCode,
                icon: const Icon(Icons.qr_code),
                label: const Text('Imprimir código QR de prueba'),
              ),
              if (_status != null) ...[
                const SizedBox(height: 16),
                Text(
                  _status!,
                  style: TextStyle(
                    color:
                        _status!.contains('falló') ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
