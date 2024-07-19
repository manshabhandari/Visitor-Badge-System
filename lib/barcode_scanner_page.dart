import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'user_info.dart';
import 'main.dart';

class BarcodeScannerPage extends StatefulWidget {
  final String? badgeExpiry;
  final int? companyId;
  final int? locationId;
  final String? companyDisclaimer;

  const BarcodeScannerPage({
    Key? key,
    this.companyDisclaimer,
    this.badgeExpiry,
    this.companyId,
    this.locationId,
  }) : super(key: key);

  @override
  _BarcodeScannerPageState createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  CameraController? _cameraController;
  late BarcodeScanner _barcodeScanner;
  bool _isDetecting = false;
  bool _showTickMark = false;
  Rect? _barcodeRect;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _barcodeScanner = BarcodeScanner();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    _cameraController = CameraController(firstCamera, ResolutionPreset.high);
    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
      _cameraController!.startImageStream(_processImage);
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final InputImageRotation imageRotation = InputImageRotation.rotation0deg;

    final InputImageFormat inputImageFormat = InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );

    final barcodes = await _barcodeScanner.processImage(inputImage);

    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      setState(() {
        _showTickMark = true;
        _barcodeRect = barcode.boundingBox;
      });
      await Future.delayed(const Duration(seconds: 1));
      _parseAAMVAData(barcode.rawValue);
    } else {
      setState(() {
        _showTickMark = false;
        _barcodeRect = null;
      });
    }

    _isDetecting = false;
  }

  void _parseAAMVAData(String? data) {
    final lines = data?.split('\n');
    String firstName = '';
    String lastName = '';
    String? middleName;
    String dateOfBirth = '';
    String gender = '';
    String height = '';
    String expiryDate = '';
    String issueDate = '';
    String address = '';
    String city = '';
    String postalCode = '';
    String state = '';
    String country = '';
    String idNumber = '';

    for (var line in lines ?? []) {
      print(line);
    }

    for (var line in lines ?? []) {
      if (line.startsWith("DAC")) {
        firstName = line.substring(3).trim();
      } else if (line.startsWith("DCS")) {
        lastName = line.substring(3).trim();
      } else if (line.startsWith("DAD")) {
        middleName = line.substring(3).trim();
      } else if (line.startsWith("DBB")) {
        dateOfBirth = _formatDate(line.substring(3).trim());
      } else if (line.startsWith("DBC")) {
        gender = line.startsWith("1", 3) ? "MALE" : "FEMALE";
      } else if (line.startsWith("DAU")) {
        height = line.substring(3).trim();
      } else if (line.startsWith("DBA")) {
        expiryDate = _formatDate(line.substring(3).trim());
      } else if (line.startsWith("DBD")) {
        issueDate = _formatDate(line.substring(3).trim());
      } else if (line.startsWith("DAG")) {
        address = line.substring(3).trim();
      } else if (line.startsWith("DAI")) {
        city = line.substring(3).trim();
      } else if (line.startsWith("DAJ")) {
        state = line.substring(3).trim();
      } else if (line.startsWith("DCG")) {
        country = line.substring(3).trim();
      } else if (line.startsWith("DAQ")) {
        idNumber = line.substring(3).trim();
      } else if (line.startsWith("DAK")) {
        postalCode = line.substring(3, 8).trim();
      }
    }

    address += ", $city, $postalCode";

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      if (_isIdExpired(expiryDate)) {
        _showExpirationAlert();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserInfoPage(
              firstName: firstName,
              lastName: lastName,
              middleName: middleName,
              dateOfBirth: dateOfBirth,
              gender: gender,
              height: height,
              expiryDate: expiryDate,
              issueDate: issueDate,
              address: address,
              state: state,
              country: country,
              idNumber: idNumber,
              badgeExpiry: widget.badgeExpiry,
              companyId: widget.companyId,
              locationId: widget.locationId,
              companyDisclaimer: widget.companyDisclaimer,
            ),
          ),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    if (dateString.length != 8) {
      return dateString;
    }
    return "${dateString.substring(0, 2)}/${dateString.substring(2, 4)}/${dateString.substring(4)}";
  }

  bool _isIdExpired(String expiryDate) {
    print("Received expiry date string: '$expiryDate'");

    if (expiryDate.length != 10) {
      print(
          "Invalid expiry date format: '$expiryDate' (length: ${expiryDate.length})");
      return false;
    }

    try {
      List<String> parts = expiryDate.split('/');
      int month = int.parse(parts[0]);
      int day = int.parse(parts[1]);
      int year = int.parse(parts[2]);

      final parsedDate = DateTime(year, month, day);
      print("Successfully parsed date: $parsedDate");

      final currentDate = DateTime.now();
      print("Current date: $currentDate");

      return parsedDate.isBefore(currentDate);
    } catch (e) {
      print("Error parsing expiry date: $e");
      print("Expiry date string: '$expiryDate'");
      return false;
    }
  }

  void _showExpirationAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("ID Expired"),
          content: const Text("Your ID has expired. Please use a valid ID."),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MyApp()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan ID")),
      body: _isCameraInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController!),
                CustomPaint(
                  painter: BarcodeOverlayPainter(_barcodeRect),
                ),
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.5,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                  ),
                ),
                if (_showTickMark)
                  const Center(
                    child: Icon(Icons.check_circle,
                        size: 100, color: Colors.green),
                  ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Text(
                    _showTickMark
                        ? "Barcode successfully detected!"
                        : "Place the barcode at the back of your ID within the green frame",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }
}

class BarcodeOverlayPainter extends CustomPainter {
  final Rect? barcodeRect;

  BarcodeOverlayPainter(this.barcodeRect);

  @override
  void paint(Canvas canvas, Size size) {
    if (barcodeRect != null) {
      final paintRect = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final adjustedRect = Rect.fromLTRB(
        barcodeRect!.left * size.width,
        barcodeRect!.top * size.height,
        barcodeRect!.right * size.width,
        barcodeRect!.bottom * size.height,
      );

      canvas.drawRect(adjustedRect, paintRect);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
