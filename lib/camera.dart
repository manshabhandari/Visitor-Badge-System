import 'dart:io';
import 'package:flutter/material.dart';
import 'package:face_camera/face_camera.dart';
import 'badge_page.dart';

class CameraPage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String? badgeExpiry;

  const CameraPage({
    Key? key,
    required this.firstName,
    required this.lastName,
    this.badgeExpiry,
  }) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  File? _capturedImage;
  late FaceCameraController controller;

  @override
  void initState() {
    super.initState();
    controller = FaceCameraController(
      autoCapture: false,
      defaultCameraLens: CameraLens.front,
      onCapture: (File? image) {
        setState(() => _capturedImage = image);
      },
      onFaceDetected: (Face? face) {
        // You can add face detection logic here if needed
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Your Photo'),
      ),
      body: Center(
        child: Builder(builder: (context) {
          if (_capturedImage != null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Image.file(
                    _capturedImage!,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await controller.startImageStream();
                        setState(() => _capturedImage = null);
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text('Retake Photo'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BadgePage(
                              imagePath: _capturedImage!.path,
                              firstName: widget.firstName,
                              lastName: widget.lastName,
                              badgeExpiry: widget.badgeExpiry,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ],
            );
          }
          return Container(
            width: 300,
            height: 400,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SmartFaceCamera(
                controller: controller,
                showCameraLensControl: false,
                showFlashControl: false,
                messageBuilder: (context, face) {
                  if (face == null) {
                    return _message('Place your face in the camera');
                  }
                  if (!face.wellPositioned) {
                    return _message('Center your face in the frame');
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _message(String msg) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: Colors.white),
        ),
      );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
