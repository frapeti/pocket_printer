import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pax_printer_utility/flutter_pax_printer_utility.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

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
  int _grayLevel = 4;
  bool _useDefaultImage = false;
  String _selectedAlgorithm = 'Floyd-Steinberg';

  // Definir el canal para comunicarse con el código nativo
  static const platform = MethodChannel(
    'com.example.pax_printer_app/shared_image',
  );

  @override
  void initState() {
    super.initState();

    // Verificar si se compartió alguna imagen al iniciar la app
    _checkForSharedImage();

    // Set default image if none is loaded
    if (_imageFile == null) {
      _imageFile = null; // Clear any existing file reference
      _status = 'Imagen de prueba cargada por defecto';
      _useDefaultImage = true; // Set flag to true when using default image
    }
  }

  // Método para verificar si hay una imagen compartida
  Future<void> _checkForSharedImage() async {
    try {
      final String? imagePath = await platform.invokeMethod(
        'getSharedImagePath',
      );
      if (imagePath != null && imagePath.isNotEmpty) {
        _handleSharedImage(imagePath);
      }
    } on PlatformException catch (e) {
      print("Error al obtener la imagen compartida: ${e.message}");
    }
  }

  void _handleSharedImage(String path) {
    setState(() {
      _imageFile = File(path);
      _status = 'Imagen recibida lista para imprimir';
      _useDefaultImage = false; // Ensure the default image is not used
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

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
          _useDefaultImage =
              false; // Set flag to false when a new image is selected
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
    if (_imageFile == null && !_useDefaultImage) return;
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
      await FlutterPaxPrinterUtility.setGray(_grayLevel);

      // Read image bytes
      Uint8List bytes;
      if (_useDefaultImage) {
        final ByteData data = await rootBundle.load(
          'assets/images/test_image.png',
        );
        bytes = data.buffer.asUint8List();
      } else {
        bytes = await _imageFile!.readAsBytes();
      }

      // Print the bitmap with minimal delay
      print('Printing image...');
      await Future.delayed(const Duration(milliseconds: 300));
      await FlutterPaxPrinterUtility.printBitmap(bytes);
      await Future.delayed(const Duration(milliseconds: 300));

      // Add minimal spacing and start printing
      await FlutterPaxPrinterUtility.step(50);
      var status = await FlutterPaxPrinterUtility.start();

      // Add final delay to ensure complete printing
      await Future.delayed(const Duration(milliseconds: 500));

      print('Print status: $status');
      setState(() {
        _status = '¡Imagen impresa correctamente!';
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

  // Map slider values to different dithering algorithms
  String _getDitheringAlgorithm(int grayLevel) {
    switch (grayLevel) {
      case 0:
        return 'Floyd-Steinberg';
      case 1:
        return 'Atkinson';
      case 2:
        return 'Jarvis-Judice-Ninke';
      case 3:
        return 'Stucki';
      default:
        return 'Floyd-Steinberg';
    }
  }

  // Show progress to the user
  Future<void> _printImageWithProgress() async {
    if (_imageFile == null && !_useDefaultImage) return;
    setState(() {
      _printing = true;
      _status = 'Procesando imagen...';
    });
    try {
      print('Initializing printer with $_selectedAlgorithm dithering...');
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
      await FlutterPaxPrinterUtility.setGray(_grayLevel);

      // Read image bytes and apply dithering
      Uint8List bytes;
      if (_useDefaultImage) {
        final ByteData data = await rootBundle.load(
          'assets/images/test_image.png',
        );
        bytes = data.buffer.asUint8List();
      } else {
        bytes = await _imageFile!.readAsBytes();
      }
      Uint8List ditheredBytes;
      switch (_selectedAlgorithm) {
        case 'Floyd-Steinberg':
          ditheredBytes = applyDithering(bytes);
          break;
        case 'Atkinson':
          ditheredBytes = applyAtkinsonDithering(bytes);
          break;
        case 'Jarvis-Judice-Ninke':
          ditheredBytes = applyJarvisJudiceNinkeDithering(bytes);
          break;
        case 'Stucki':
          ditheredBytes = applyStuckiDithering(bytes);
          break;
        default:
          ditheredBytes = applyDithering(bytes);
      }

      // Print the bitmap with minimal delay
      print('Printing image with $_selectedAlgorithm dithering...');
      await Future.delayed(const Duration(milliseconds: 300));
      await FlutterPaxPrinterUtility.printBitmap(ditheredBytes);
      await Future.delayed(const Duration(milliseconds: 300));

      // Add minimal spacing and start printing
      await FlutterPaxPrinterUtility.step(50);
      var status = await FlutterPaxPrinterUtility.start();

      // Add final delay to ensure complete printing
      await Future.delayed(const Duration(milliseconds: 500));

      print('Print status: $status');
      setState(() {
        _status =
            '¡Imagen impresa con $_selectedAlgorithm dithering correctamente!';
      });
    } catch (e) {
      print('Error printing image with dithering: $e');
      setState(() {
        _status = 'Image print with dithering failed: $e';
      });
    } finally {
      setState(() {
        _printing = false;
      });
    }
  }

  // Update the _showDitheringDialog method to print immediately after selection
  void _showDitheringDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar Calidad de Dithering'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: const Text('Baja Calidad (Floyd-Steinberg)'),
                subtitle: const Text('Mejor para imágenes con alto contraste'),
                onTap: () {
                  setState(() {
                    _selectedAlgorithm = 'Floyd-Steinberg';
                  });
                  Navigator.of(context).pop();
                  _printImageWithProgress(); // Print immediately
                },
              ),
              ListTile(
                title: const Text('Calidad Media (Atkinson)'),
                subtitle: const Text('Balance entre detalle y velocidad'),
                onTap: () {
                  setState(() {
                    _selectedAlgorithm = 'Atkinson';
                  });
                  Navigator.of(context).pop();
                  _printImageWithProgress(); // Print immediately
                },
              ),
              ListTile(
                title: const Text('Alta Calidad (Jarvis-Judice-Ninke)'),
                subtitle: const Text('Mejor para imágenes con detalles finos'),
                onTap: () {
                  setState(() {
                    _selectedAlgorithm = 'Jarvis-Judice-Ninke';
                  });
                  Navigator.of(context).pop();
                  _printImageWithProgress(); // Print immediately
                },
              ),
              ListTile(
                title: const Text('Muy Alta Calidad (Stucki)'),
                subtitle: const Text('Máximo detalle, más lento'),
                onTap: () {
                  setState(() {
                    _selectedAlgorithm = 'Stucki';
                  });
                  Navigator.of(context).pop();
                  _printImageWithProgress(); // Print immediately
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_imageFile != null || _useDefaultImage) ...[
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child:
                        _useDefaultImage
                            ? Image.asset(
                              'assets/images/test_image.png',
                              fit: BoxFit.contain,
                            )
                            : Image.file(_imageFile!, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_status != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Text(_status!),
                  ),
                if (_imageFile != null && !_useDefaultImage)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        const Text(
                          '¡Imagen recibida por compartir!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _printing ? null : _printImage,
                          icon: const Icon(Icons.print),
                          label:
                              _printing
                                  ? const Text('Imprimiendo...')
                                  : const Text('Imprimir sin Dithering'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _printing ? null : _showDitheringDialog,
                          icon: const Icon(Icons.tune),
                          label:
                              _printing
                                  ? const Text('Procesando...')
                                  : const Text('Imprimir con Dithering'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ElevatedButton.icon(
                    onPressed: _printing ? null : _printImage,
                    icon: const Icon(Icons.print),
                    label:
                        _printing
                            ? const Text('Imprimiendo...')
                            : const Text('Imprimir sin Dithering'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _printing ? null : _showDitheringDialog,
                    icon: const Icon(Icons.tune),
                    label:
                        _printing
                            ? const Text('Procesando...')
                            : const Text('Imprimir con Dithering'),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Ajustá el nivel de negro para la impresión (más alto = más oscuro, más bajo = más claro)',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _grayLevel.toDouble(),
                  min: 0,
                  max: 4,
                  divisions: 4,
                  label: 'Nivel de negro: $_grayLevel',
                  onChanged:
                      _printing
                          ? null
                          : (double value) {
                            setState(() {
                              _grayLevel = value.round();
                            });
                          },
                ),
                const SizedBox(height: 80), // Espacio adicional para el FAB
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        tooltip: 'Seleccionar Imagen',
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }
}

// Ensure all functions are properly defined
Uint8List applyAtkinsonDithering(Uint8List imageBytes) {
  // Decode the image
  img.Image? image = img.decodeImage(imageBytes);
  if (image == null) {
    print('Failed to decode image');
    return imageBytes;
  }

  // Apply Atkinson dithering
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      int oldPixel = img.getLuminance(image.getPixel(x, y));
      int newPixel = oldPixel > 128 ? 255 : 0;
      int quantError = oldPixel - newPixel;

      image.setPixel(x, y, img.getColor(newPixel, newPixel, newPixel));

      if (x + 1 < image.width) {
        int neighbor = img.getLuminance(image.getPixel(x + 1, y));
        neighbor = (neighbor + (quantError * 1) / 8).clamp(0, 255).toInt();
        image.setPixel(x + 1, y, img.getColor(neighbor, neighbor, neighbor));
      }
      if (x + 2 < image.width) {
        int neighbor = img.getLuminance(image.getPixel(x + 2, y));
        neighbor = (neighbor + (quantError * 1) / 8).clamp(0, 255).toInt();
        image.setPixel(x + 2, y, img.getColor(neighbor, neighbor, neighbor));
      }
      if (y + 1 < image.height) {
        if (x > 0) {
          int neighbor = img.getLuminance(image.getPixel(x - 1, y + 1));
          neighbor = (neighbor + (quantError * 1) / 8).clamp(0, 255).toInt();
          image.setPixel(
            x - 1,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        int neighbor = img.getLuminance(image.getPixel(x, y + 1));
        neighbor = (neighbor + (quantError * 1) / 8).clamp(0, 255).toInt();
        image.setPixel(x, y + 1, img.getColor(neighbor, neighbor, neighbor));
        if (x + 1 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 1, y + 1));
          neighbor = (neighbor + (quantError * 1) / 8).clamp(0, 255).toInt();
          image.setPixel(
            x + 1,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
      }
      if (y + 2 < image.height) {
        int neighbor = img.getLuminance(image.getPixel(x, y + 2));
        neighbor = (neighbor + (quantError * 1) / 8).clamp(0, 255).toInt();
        image.setPixel(x, y + 2, img.getColor(neighbor, neighbor, neighbor));
      }
    }
  }

  // Encode the image back to Uint8List
  return Uint8List.fromList(img.encodePng(image));
}

// Implement Jarvis, Judice, and Ninke Dithering
Uint8List applyJarvisJudiceNinkeDithering(Uint8List imageBytes) {
  img.Image? image = img.decodeImage(imageBytes);
  if (image == null) {
    print('Failed to decode image');
    return imageBytes;
  }

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      int oldPixel = img.getLuminance(image.getPixel(x, y));
      int newPixel = oldPixel > 128 ? 255 : 0;
      int quantError = oldPixel - newPixel;

      image.setPixel(x, y, img.getColor(newPixel, newPixel, newPixel));

      if (x + 1 < image.width) {
        int neighbor = img.getLuminance(image.getPixel(x + 1, y));
        neighbor = (neighbor + (quantError * 7) / 48).clamp(0, 255).toInt();
        image.setPixel(x + 1, y, img.getColor(neighbor, neighbor, neighbor));
      }
      if (x + 2 < image.width) {
        int neighbor = img.getLuminance(image.getPixel(x + 2, y));
        neighbor = (neighbor + (quantError * 5) / 48).clamp(0, 255).toInt();
        image.setPixel(x + 2, y, img.getColor(neighbor, neighbor, neighbor));
      }
      if (y + 1 < image.height) {
        if (x > 0) {
          int neighbor = img.getLuminance(image.getPixel(x - 1, y + 1));
          neighbor = (neighbor + (quantError * 3) / 48).clamp(0, 255).toInt();
          image.setPixel(
            x - 1,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        int neighbor = img.getLuminance(image.getPixel(x, y + 1));
        neighbor = (neighbor + (quantError * 5) / 48).clamp(0, 255).toInt();
        image.setPixel(x, y + 1, img.getColor(neighbor, neighbor, neighbor));
        if (x + 1 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 1, y + 1));
          neighbor = (neighbor + (quantError * 7) / 48).clamp(0, 255).toInt();
          image.setPixel(
            x + 1,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        if (x + 2 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 2, y + 1));
          neighbor = (neighbor + (quantError * 5) / 48).clamp(0, 255).toInt();
          image.setPixel(
            x + 2,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
      }
      if (y + 2 < image.height) {
        if (x > 0) {
          int neighbor = img.getLuminance(image.getPixel(x - 1, y + 2));
          neighbor = (neighbor + (quantError * 1) / 48).clamp(0, 255).toInt();
          image.setPixel(
            x - 1,
            y + 2,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        int neighbor = img.getLuminance(image.getPixel(x, y + 2));
        neighbor = (neighbor + (quantError * 3) / 48).clamp(0, 255).toInt();
        image.setPixel(x, y + 2, img.getColor(neighbor, neighbor, neighbor));
        if (x + 1 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 1, y + 2));
          neighbor = (neighbor + (quantError * 5) / 48).clamp(0, 255).toInt();
          image.setPixel(
            x + 1,
            y + 2,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        if (x + 2 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 2, y + 2));
          neighbor = (neighbor + (quantError * 3) / 48).clamp(0, 255).toInt();
          image.setPixel(
            x + 2,
            y + 2,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
      }
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}

// Implement Stucki Dithering
Uint8List applyStuckiDithering(Uint8List imageBytes) {
  img.Image? image = img.decodeImage(imageBytes);
  if (image == null) {
    print('Failed to decode image');
    return imageBytes;
  }

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      int oldPixel = img.getLuminance(image.getPixel(x, y));
      int newPixel = oldPixel > 128 ? 255 : 0;
      int quantError = oldPixel - newPixel;

      image.setPixel(x, y, img.getColor(newPixel, newPixel, newPixel));

      if (x + 1 < image.width) {
        int neighbor = img.getLuminance(image.getPixel(x + 1, y));
        neighbor = (neighbor + (quantError * 8) / 42).clamp(0, 255).toInt();
        image.setPixel(x + 1, y, img.getColor(neighbor, neighbor, neighbor));
      }
      if (x + 2 < image.width) {
        int neighbor = img.getLuminance(image.getPixel(x + 2, y));
        neighbor = (neighbor + (quantError * 4) / 42).clamp(0, 255).toInt();
        image.setPixel(x + 2, y, img.getColor(neighbor, neighbor, neighbor));
      }
      if (y + 1 < image.height) {
        if (x > 0) {
          int neighbor = img.getLuminance(image.getPixel(x - 1, y + 1));
          neighbor = (neighbor + (quantError * 2) / 42).clamp(0, 255).toInt();
          image.setPixel(
            x - 1,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        int neighbor = img.getLuminance(image.getPixel(x, y + 1));
        neighbor = (neighbor + (quantError * 4) / 42).clamp(0, 255).toInt();
        image.setPixel(x, y + 1, img.getColor(neighbor, neighbor, neighbor));
        if (x + 1 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 1, y + 1));
          neighbor = (neighbor + (quantError * 8) / 42).clamp(0, 255).toInt();
          image.setPixel(
            x + 1,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        if (x + 2 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 2, y + 1));
          neighbor = (neighbor + (quantError * 4) / 42).clamp(0, 255).toInt();
          image.setPixel(
            x + 2,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
      }
      if (y + 2 < image.height) {
        if (x > 0) {
          int neighbor = img.getLuminance(image.getPixel(x - 1, y + 2));
          neighbor = (neighbor + (quantError * 1) / 42).clamp(0, 255).toInt();
          image.setPixel(
            x - 1,
            y + 2,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        int neighbor = img.getLuminance(image.getPixel(x, y + 2));
        neighbor = (neighbor + (quantError * 2) / 42).clamp(0, 255).toInt();
        image.setPixel(x, y + 2, img.getColor(neighbor, neighbor, neighbor));
        if (x + 1 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 1, y + 2));
          neighbor = (neighbor + (quantError * 4) / 42).clamp(0, 255).toInt();
          image.setPixel(
            x + 1,
            y + 2,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        if (x + 2 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 2, y + 2));
          neighbor = (neighbor + (quantError * 2) / 42).clamp(0, 255).toInt();
          image.setPixel(
            x + 2,
            y + 2,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
      }
    }
  }

  return Uint8List.fromList(img.encodePng(image));
}

// Add a dithering function
Uint8List applyDithering(Uint8List imageBytes, {int threshold = 128}) {
  // Decode the image
  img.Image? image = img.decodeImage(imageBytes);
  if (image == null) {
    print('Failed to decode image');
    return imageBytes;
  }

  // Apply Floyd-Steinberg dithering with adjustable threshold
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      int oldPixel = img.getLuminance(image.getPixel(x, y));
      int newPixel = oldPixel > threshold ? 255 : 0;
      int quantError = oldPixel - newPixel;

      image.setPixel(x, y, img.getColor(newPixel, newPixel, newPixel));

      if (x + 1 < image.width) {
        int neighbor = img.getLuminance(image.getPixel(x + 1, y));
        neighbor = (neighbor + (quantError * 7) / 16).clamp(0, 255).toInt();
        image.setPixel(x + 1, y, img.getColor(neighbor, neighbor, neighbor));
      }
      if (y + 1 < image.height) {
        if (x > 0) {
          int neighbor = img.getLuminance(image.getPixel(x - 1, y + 1));
          neighbor = (neighbor + (quantError * 3) / 16).clamp(0, 255).toInt();
          image.setPixel(
            x - 1,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
        int neighbor = img.getLuminance(image.getPixel(x, y + 1));
        neighbor = (neighbor + (quantError * 5) / 16).clamp(0, 255).toInt();
        image.setPixel(x, y + 1, img.getColor(neighbor, neighbor, neighbor));
        if (x + 1 < image.width) {
          int neighbor = img.getLuminance(image.getPixel(x + 1, y + 1));
          neighbor = (neighbor + (quantError * 1) / 16).clamp(0, 255).toInt();
          image.setPixel(
            x + 1,
            y + 1,
            img.getColor(neighbor, neighbor, neighbor),
          );
        }
      }
    }
  }

  // Encode the image back to Uint8List
  return Uint8List.fromList(img.encodePng(image));
}
