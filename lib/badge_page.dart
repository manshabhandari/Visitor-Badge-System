import 'dart:io';
import 'dart:ui' as ui;
import 'package:another_brother/label_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:another_brother/printer_info.dart' as brother;
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';

class BadgePage extends StatefulWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String firstName;
  final String lastName;
  final String? badgeExpiry;

  BadgePage({
    this.imagePath,
    this.imageBytes,
    required this.firstName,
    required this.lastName,
    this.badgeExpiry,
  }) : assert(imagePath != null || imageBytes != null);

  @override
  _BadgePageState createState() => _BadgePageState();
}

class _BadgePageState extends State<BadgePage> {
  brother.Printer? _printer;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    print("BadgePage initState called");
    _initPrinter();
  }

  Future<void> _initPrinter() async {
    print("_initPrinter started");
    if (!await Permission.bluetoothScan.request().isGranted ||
        !await Permission.bluetoothConnect.request().isGranted) {
      print("Bluetooth permissions not granted");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Bluetooth permissions are required to print.")),
      );
      return;
    }
    print("Bluetooth permissions granted");

    _printer = brother.Printer();
    print("Printer instance created");
    brother.PrinterInfo printInfo = brother.PrinterInfo();
    printInfo.printerModel = brother.Model.QL_820NWB;
    printInfo.printMode = brother.PrintMode.FIT_TO_PAGE;
    printInfo.isAutoCut = true;
    printInfo.port = brother.Port.BLUETOOTH;
    printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W62.getId());

    print("Setting printer info");
    try {
      await _printer!.setPrinterInfo(printInfo);
      print("Printer info set successfully");
    } catch (e) {
      print("Error setting printer info: $e");
    }

    print("Searching for Bluetooth printers");
    List<brother.BluetoothPrinter> printers = [];
    try {
      printers = await _printer!
          .getBluetoothPrinters([brother.Model.QL_820NWB.getName()]);
      print("Found ${printers.length} printers");
    } catch (e) {
      print("Error searching for printers: $e");
    }

    if (printers.isNotEmpty) {
      printInfo.macAddress = printers.first.macAddress;
      print("Setting MAC address: ${printInfo.macAddress}");
      try {
        await _printer!.setPrinterInfo(printInfo);
        print("Printer info updated with MAC address");
        setState(() => _isConnected = true);
        print("Printer connected successfully");
      } catch (e) {
        print("Error updating printer info with MAC address: $e");
      }
    } else {
      print("No QL-820NWB printer found");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No QL-820NWB printer found.")),
      );
    }
  }

  Future<void> _printBadge() async {
    print("_printBadge started");
    if (!_isConnected) {
      print("Printer not connected");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Printer is not connected.")),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('EEE M/d').format(now).toUpperCase();
      final expirationString = _formatBadgeExpiry(widget.badgeExpiry);

      print("Updating printer settings");
      brother.PrinterInfo printInfo = await _printer!.getPrinterInfo();
      printInfo.isAutoCut = true;
      printInfo.isCutAtEnd = true;
      printInfo.labelNameIndex = QL700.ordinalFromID(QL700.W62.getId());
      printInfo.printMode = brother.PrintMode.FIT_TO_PAGE;
      printInfo.align = brother.Align.CENTER;
      printInfo.valign = brother.VAlign.MIDDLE;
      await _printer!.setPrinterInfo(printInfo);
      print("Printer settings updated");

      // Create a composite image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      const labelWidth = 696.0; // for 62mm label width (at 300 dpi)
      const labelHeight = 1040.0; // reduced height to fit content

      // White background
      canvas.drawRect(const Rect.fromLTWH(0, 0, labelWidth, labelHeight),
          Paint()..color = Colors.white);

      // Draw formatted date with larger font size
      _drawText(
          canvas, formattedDate, 140, const Offset(labelWidth / 2, 100), true);

      // Draw image
      if (widget.imageBytes != null || widget.imagePath != null) {
        ui.Image photo;
        if (widget.imageBytes != null) {
          final codec = await ui.instantiateImageCodec(widget.imageBytes!);
          final frame = await codec.getNextFrame();
          photo = frame.image;
        } else {
          final file = File(widget.imagePath!);
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          photo = frame.image;
        }
        const photoRect =
            Rect.fromLTWH(labelWidth / 2 - 250, 200, 500, 700); // 500x700 size
        canvas.drawImageRect(
            photo,
            Rect.fromLTWH(
                0, 0, photo.width.toDouble(), photo.height.toDouble()),
            photoRect,
            Paint());
      }

      if (widget.firstName.length + widget.lastName.length > 19) {
        // Draw name (reduced gap)
        _drawText(canvas, '${widget.firstName} ${widget.lastName}', 45,
            const Offset(labelWidth / 2, 950), true);
      } else {
        // Draw name
        _drawText(canvas, '${widget.firstName} ${widget.lastName}', 60,
            const Offset(labelWidth / 2, 950), true);
      }

      // Draw expiration (reduced gap, increased font size)
      _drawText(canvas, 'EXPIRES: $expirationString', 36,
          const Offset(labelWidth / 2, 1020), true);

      // Convert to image
      final picture = recorder.endRecording();
      final img =
          await picture.toImage(labelWidth.toInt(), labelHeight.toInt());
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes != null) {
        print("Composite image created, printing");
        await _printer!.printImage(
            await decodeImageFromList(pngBytes.buffer.asUint8List()));
        print("Composite image printed");

        // Show success dialog
        await _showPrintSuccessDialog();

        // Navigate to SignInPage after successful printing
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SignInPage()),
        );
      } else {
        throw Exception("Failed to create composite image");
      }
    } catch (e) {
      print("Error during printing: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to print: $e")),
      );
    }
  }

  Future<void> _showPrintSuccessDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success!'),
          content:
              const Text('Your badge is being printed. Please collect it.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _formatBadgeExpiry(String? badgeExpiry) {
    if (badgeExpiry == null) {
      final now = DateTime.now();
      final defaultExpiry = DateTime(now.year, now.month, now.day, 17, 0);
      return DateFormat('h:mm a  (M/d)').format(defaultExpiry);
    }

    final timeParts = badgeExpiry.split(':');
    if (timeParts.length >= 2) {
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      final now = DateTime.now();
      final expiryTime = DateTime(now.year, now.month, now.day, hour, minute);
      return DateFormat('h:mm a (M/d)').format(expiryTime);
    }

    return badgeExpiry; // Return as-is if parsing fails
  }

  void _drawText(
      Canvas canvas, String text, double fontSize, Offset center, bool isBold) {
    final textStyle = ui.TextStyle(
      color: Colors.black,
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: fontSize,
    );
    final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(text);
    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(
        width: 696.0)); // Use full label width for layout
    canvas.drawParagraph(paragraph,
        center.translate(-paragraph.width / 2, -paragraph.height / 2));
  }

  @override
  Widget build(BuildContext context) {
    print("Building BadgePage widget");
    final now = DateTime.now();
    final formattedDate = DateFormat('EEE M/d').format(now);
    final formattedExpiry = _formatBadgeExpiry(widget.badgeExpiry);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formattedDate.toUpperCase(),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: widget.imageBytes != null
                    ? Image.memory(widget.imageBytes!, fit: BoxFit.cover)
                    : Image.file(File(widget.imagePath!), fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              Text(
                '${widget.firstName} ${widget.lastName}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'EXPIRES: $formattedExpiry',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isConnected
                    ? () {
                        print("Print Badge button pressed");
                        _printBadge();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Print Badge',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
