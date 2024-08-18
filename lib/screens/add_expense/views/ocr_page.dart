import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class OCRPage extends StatefulWidget {
  final Function(String?) onAmountExtracted;
  final Function(String) onImageUploaded;

  const OCRPage({super.key, required this.onAmountExtracted, required this.onImageUploaded});

  @override
  _OCRPageState createState() => _OCRPageState();
}

class _OCRPageState extends State<OCRPage> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  CameraController? _cameraController;
  bool _cameraOpened = false;
  bool _imageCaptured = false;
  bool _isProcessing = false;
  File? _imageFile;
  String? _extractedAmount;

  @override
  void initState() {
    super.initState();
    //_initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.high,
    );

    await _cameraController?.initialize();

    setState(() {
      _cameraOpened = true;
    });
  }

  Future<void> _pickImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile? photo = await _cameraController!.takePicture();
      setState(() {
        _imageFile = File(photo!.path);
        _imageCaptured = true;
      });
      await _processImage(photo!.path);
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  Future<void> _processImage(String imagePath) async {
    setState(() {
      _isProcessing = true;
    });

    // Resmi firebase'e yükle
    String? photoUrl = await _uploadImageToFirebase(imagePath);

    if (photoUrl != null) {
      widget.onImageUploaded(photoUrl);
    }

    File croppedImage = await _cropImage(imagePath);

    final inputImage = InputImage.fromFilePath(croppedImage.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    String text = recognizedText.text;
    print('Extracted text: $text'); // Hata ayıklama
    _preprocessText(text);

    setState(() {
      _isProcessing = false;
    });
  }

  Future<File> _cropImage(String imagePath) async {
    final File imageFile = File(imagePath);
    final img.Image? image = img.decodeImage(imageFile.readAsBytesSync());

    if (image == null) {
      return imageFile;
    }

    // Calculate crop dimensions based on the red-bordered container
    // double topPercent = 500 / MediaQuery.of(context).size.height;
    // double leftPercent = 20 / MediaQuery.of(context).size.width;
    // double widthPercent = (MediaQuery.of(context).size.width - 40);
    // double heightPercent = (MediaQuery.of(context).size.height * 0.08);

    double imageRatio = image.width / image.height;
    double screenRatio = MediaQuery.of(context).size.width / MediaQuery.of(context).size.height;

    double cropRatio = screenRatio / imageRatio;

    double topPercent = 0.8; // sayı küçülürse daha fazla alanı kapsar
    double leftPercent = 0.075;
    double rightPercent = 0.075;
    double bottomPercent = 0.01; // sayı büyürse daha fazla alanı kapsar

    int x = (image.width * leftPercent).round();
    int y = (image.height * topPercent * cropRatio).round();
    int w = (image.width * (1 - leftPercent - rightPercent)).round();
    int h = (image.height * (1 - topPercent - bottomPercent) * cropRatio).round();

    // resmi kırp
    img.Image croppedImage = img.copyCrop(image, x: x, y: y, width: w, height: h);

    // kırpılmış resmi geçici bir dosyaya kaydet
    final tempDir = await getTemporaryDirectory();
    File croppedFile = File('${tempDir.path}/cropped_image.jpg');
    croppedFile.writeAsBytesSync(img.encodeJpg(croppedImage));

    return croppedFile;
  }

  Future<String?> _uploadImageToFirebase(String imagePath) async {
    try {
      File file = File(imagePath);
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('receipts').child(fileName);
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  void _preprocessText(String text) {
    // Metni temizleme ve işleme
    String cleanedText = text.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    cleanedText = cleanedText.replaceAllMapped(RegExp(r'(\d)\s+,\s+(\d)'), (match) => '${match.group(1)},${match.group(2)}');
    cleanedText = cleanedText.replaceAll(RegExp(r',\s+'), ',');
    print('Cleaned text: $cleanedText'); // Hata ayıklama
    _extractTotalAmount(cleanedText);
  }

  void _extractTotalAmount(String text) {
    final kdvliToplamRegex = RegExp(r"KDV\'li TOPLAM\s*[:\-\s]*([\d\.,]+)", caseSensitive: false);
    final kdvliLliToplamRegex = RegExp(r"KDV\'Lİ TOPLAM\s*[:\-\s]*([\d\.,]+)", caseSensitive: false);
    final kdvToplamRegex = RegExp(r"KDV TOPLAM\s*[:\-\s]*([\d\.,]+)", caseSensitive: false);

    final kdvliToplamMatch = kdvliToplamRegex.firstMatch(text);
    final kdvliLliToplamMatch = kdvliLliToplamRegex.firstMatch(text);
    final kdvToplamMatch = kdvToplamRegex.firstMatch(text);

    if (kdvliToplamMatch != null || kdvliLliToplamMatch != null || kdvToplamMatch != null) {
      if (!(text.toUpperCase().contains('NAKİT') || text.toUpperCase().contains('NAKIT'))) {
        final amountToRemove = kdvliToplamMatch?.group(1) ?? kdvliLliToplamMatch?.group(1);
        if (amountToRemove != null) {
          text = text.replaceFirst(RegExp(amountToRemove), '');
        }
      }
    }

    // Tüm miktarları bul
    final allAmountsRegex = RegExp(r'(\d+[.,]\d{2})', caseSensitive: false);
    final matches = allAmountsRegex.allMatches(text);

    if (matches.isNotEmpty) {
      List<double> amounts = [];
      for (final match in matches) {
        final amount = match.group(0)?.replaceAll(',', '.');
        final parsedAmount = double.tryParse(amount ?? '');
        if (parsedAmount != null) {
          amounts.add(parsedAmount);
        }
      }
      amounts.sort((a, b) => b.compareTo(a)); // Sırala

      double? selectedAmount;
      if ((text.toUpperCase().contains('NAKİT') || text.toUpperCase().contains('NAKIT')) ||
          text.toUpperCase().contains('AKIT') ||
          text.toUpperCase().contains('ALINAN PARA') && amounts.length > 1) {
        selectedAmount = amounts[1]; // Second highest amount
      } else {
        selectedAmount = amounts[0]; // Highest amount
      }

      final formattedAmount = selectedAmount.toStringAsFixed(2);
      print('Extracted amount: $formattedAmount');
      _extractedAmount = formattedAmount;
      widget.onAmountExtracted(formattedAmount);
    } else {
      print('No amount found');
      widget.onAmountExtracted(null);
    }
  }

  void _retryCapture() {
    setState(() {
      _imageCaptured = false;
      _imageFile = null;
    });
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
      ),
      body: _imageCaptured ? _buildImagePreview() : _buildCameraPreview(),
    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (!_cameraOpened)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Please take a picture of the receipt',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.tertiary
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton(
                    onPressed: _initializeCamera,
                    child: const Text(
                      'Open Camera',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_cameraOpened && _cameraController != null && _cameraController!.value.isInitialized)
          Stack(
            alignment: Alignment.center,
            children: [
              CameraPreview(_cameraController!),
              Positioned.fill(
                child: CustomPaint(
                  painter: HoleDrawer(
                    hole: Rect.fromLTRB(
                      MediaQuery.of(context).size.width * 0.075,
                      MediaQuery.of(context).size.height * 0.55,
                      MediaQuery.of(context).size.width * 0.925,
                      MediaQuery.of(context).size.height * 0.67,
                    ),
                    opacity: 0.5,
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.5,
                child: const Text(
                  'Place total amount in the red box',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.55,
                left: MediaQuery.of(context).size.width * 0.075,
                right: (MediaQuery.of(context).size.width * 0.075),
                bottom: (MediaQuery.of(context).size.height * 0.15),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2.0),
                  ),
                ),
              ),
              if (_isProcessing)
                const Center(
                  child: CircularProgressIndicator(),
                ),
              Positioned(
                bottom: 20,
                child: FloatingActionButton(
                  shape: const CircleBorder(),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  onPressed: _pickImage,
                  child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                            Theme.of(context).colorScheme.tertiary
                          ],
                        ),
                      ),
                      child: const Icon(Icons.camera)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0),
          child: RichText(
              text: TextSpan(children: [
            const TextSpan(
              text: "Total amount extracted from the receipt is: ",
              style: TextStyle(
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: "$_extractedAmount. ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const TextSpan(
                text: "If you think the amount is incorrect, please try again.",
                style: TextStyle(
                  color: Colors.black,
                ))
          ])),
        ),
        const SizedBox(height: 20),
        if (_imageFile != null)
          Image.file(
            File(_imageFile!.path),
            height: MediaQuery.of(context).size.height * 0.6,
          ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: _retryCapture,
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class HoleDrawer extends CustomPainter {
  final Rect hole;
  final double opacity;

  HoleDrawer({required this.hole, this.opacity = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(opacity);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(hole),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
