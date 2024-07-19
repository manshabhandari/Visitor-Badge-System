import 'package:flutter/material.dart';
import 'package:face_camera/face_camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'logo_page.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:async';
import 'config_manager.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FaceCamera.initialize();
  await ConfigManager.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visitor Badge System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<Widget>(
        future: _checkVersionAndBuildHome(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data ?? SignInPage();
          }
          return CircularProgressIndicator();
        },
      ),
    );
  }

  Future<Widget> _checkVersionAndBuildHome() async {
    if (ConfigManager.maintenanceMode) {
      return MaintenancePage();
    }

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    if (ConfigManager.needsForceUpdate) {
      return UpdatePage();
    }

    return SignInPage();
  }
}

class MaintenancePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              ConfigManager.maintenanceTitle,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              ConfigManager.maintenanceMessage,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: Text('OK'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdatePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.system_update, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              ConfigManager.updateTitle,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              ConfigManager.updateMessage,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: Text('Okay'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _serialNumberController = TextEditingController();

  String? serialNumber;
  String? badgeExpiry;
  int? companyId;
  int? locationId;

  int? companyIdFromCompanyAPI;
  String? companyName;
  String? companyDisclaimer;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _getDeviceId();
  }

  Future<void> _getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String id = '';

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        id = androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        id = iosInfo.identifierForVendor!;
      }

      setState(() {
        _serialNumberController.text = id;
      });

      await getDeviceInfo();
    } catch (e) {
      print('Error getting device ID: $e');
      setState(() {
        errorMessage = 'Error getting device ID';
      });
    }
  }

  Future<bool> getDeviceInfo() async {
    final url =
        '${ConfigManager.apiBaseUrl}${ConfigManager.getDeviceInfoEndpoint}/${_serialNumberController.text}';
    print('Calling Device API: $url');

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: ConfigManager.apiRequestTimeout));

      print('Device API Response Status Code: ${response.statusCode}');
      print('Device API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final deviceData = json.decode(response.body);
        print('Decoded Device Data: $deviceData');
        setState(() {
          serialNumber = deviceData['serial_number'];
          badgeExpiry = deviceData['badge_expiry'];
          companyId = deviceData['company_id'];
          locationId = deviceData['location_id'];
          errorMessage = null;
        });
        print(
            'Stored Device Info: serialNumber=$serialNumber, badgeExpiry=$badgeExpiry, companyId=$companyId, locationId=$locationId');

        if (companyId != null) {
          await getCompanyInfo();
        }
        return true;
      } else {
        setState(() {
          errorMessage = 'Current Device is not registered';
        });
        print('Failed to get device info');
        return false;
      }
    } catch (e) {
      print('Error getting device info: $e');
      setState(() {
        errorMessage = 'Error getting device info';
      });
      return false;
    }
  }

  Future<bool> getCompanyInfo() async {
    final url =
        '${ConfigManager.apiBaseUrl}${ConfigManager.getCompanyInfoEndpoint}/$companyId';
    print('Calling Company API: $url');

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: ConfigManager.apiRequestTimeout));

      print('Company API Response Status Code: ${response.statusCode}');
      print('Company API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final companyData = json.decode(response.body);
        print('Decoded Company Data: $companyData');
        setState(() {
          companyIdFromCompanyAPI = companyData['id'];
          companyName = companyData['name'];
          companyDisclaimer = companyData['disclaimer'];
          errorMessage = null;
        });
        print(
            'Stored Company Info: companyIdFromCompanyAPI=$companyIdFromCompanyAPI, companyName=$companyName, companyDisclaimer=$companyDisclaimer');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LogoPage(
              companyName: companyName,
              companyDisclaimer: companyDisclaimer,
              badgeExpiry: badgeExpiry,
              companyId: companyId,
              locationId: locationId,
            ),
          ),
        );
        return true;
      } else {
        setState(() {
          errorMessage = 'Failed to get company info';
        });
        print('Failed to get company info');
        return false;
      }
    } catch (e) {
      print('Error getting company info: $e');
      setState(() {
        errorMessage = 'Error getting company info';
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Hello, Welcome!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Serial Number',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _serialNumberController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                    Icons.confirmation_number,
                                    color: Colors.blue),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide:
                                      const BorderSide(color: Colors.blue),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                      color: Colors.blue, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the serial number';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (errorMessage != null)
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          print(
                              'Serial Number entered: ${_serialNumberController.text}');
                          await getDeviceInfo();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: ConfigManager.primaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
