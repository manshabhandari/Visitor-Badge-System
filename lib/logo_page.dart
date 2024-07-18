import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'barcode_scanner_page.dart';

class LogoPage extends StatefulWidget {
  final String? companyName;
  final String? companyDisclaimer;
  final String? badgeExpiry;
  final int? companyId;
  final int? locationId;

  const LogoPage({
    Key? key,
    this.companyName,
    this.companyDisclaimer,
    this.badgeExpiry,
    this.companyId,
    this.locationId,
  }) : super(key: key);

  @override
  _LogoPageState createState() => _LogoPageState();
}

class _LogoPageState extends State<LogoPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkBadgeExpiry();
    });
  }

  void checkBadgeExpiry() {
    if (widget.badgeExpiry != null) {
      try {
        // Assume the expiry is for today
        final now = DateTime.now();
        final todayDate =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final expiryDateTime =
            DateTime.parse("$todayDate ${widget.badgeExpiry}");

        if (now.isAfter(expiryDateTime)) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Badge Expired'),
                content: Text(
                    'Your badge has expired. Please contact the administrator.'),
                actions: <Widget>[
                  TextButton(
                    child: Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      SystemNavigator.pop(); // This will close the app
                    },
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        print('Error parsing badge expiry date: $e');
        // Optionally, show an error message to the user
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // This will disable the back button and prevent navigation
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    Text(
                      'Welcome to ${widget.companyName ?? ""}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => BarcodeScannerPage(
                                    companyDisclaimer: widget.companyDisclaimer,
                                    badgeExpiry: widget.badgeExpiry,
                                    companyId: widget.companyId,
                                    locationId: widget.locationId,
                                  )),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'Scan your ID',
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
