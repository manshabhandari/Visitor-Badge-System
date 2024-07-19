import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'camera.dart';
import 'config_manager.dart';

class UserInfoPage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String? middleName;
  final String dateOfBirth;
  final String gender;
  final String height;
  final String expiryDate;
  final String issueDate;
  final String address;
  final String state;
  final String country;
  final String idNumber;
  final String? badgeExpiry;
  final int? companyId;
  final int? locationId;
  final String? companyDisclaimer;

  UserInfoPage(
      {Key? key,
      required this.firstName,
      required this.lastName,
      this.middleName,
      required this.dateOfBirth,
      required this.gender,
      required this.height,
      required this.expiryDate,
      required this.issueDate,
      required this.address,
      required this.state,
      required this.country,
      required this.idNumber,
      required this.badgeExpiry,
      required this.companyId,
      required this.locationId,
      required this.companyDisclaimer})
      : super(key: key);

  @override
  _UserInfoPageState createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  final _formKey = GlobalKey<FormState>();
  late String firstName;
  late String lastName;
  late String? middleName;
  late String dateOfBirth;
  late String gender;
  late String height;
  late String expiryDate;
  late String issueDate;
  late String address;
  late String state;
  late String country;
  late String idNumber;
  String visitReason = '';
  String visitingWhom = '';
  late String? companyDisclaimer;

  @override
  void initState() {
    super.initState();
    firstName = widget.firstName;
    lastName = widget.lastName;
    middleName = widget.middleName;
    dateOfBirth = widget.dateOfBirth;
    gender = widget.gender;
    height = widget.height;
    expiryDate = widget.expiryDate;
    issueDate = widget.issueDate;
    address = widget.address;
    state = widget.state;
    country = widget.country;
    idNumber = widget.idNumber;
    companyDisclaimer = widget.companyDisclaimer;
  }

  Future<void> addVisitor() async {
    final url = Uri.parse(
        '${ConfigManager.apiBaseUrl}${ConfigManager.addVisitorEndpoint}');
    final requestBody = jsonEncode(<String, dynamic>{
      'id': 0,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'height': height,
      'expiry_date': expiryDate,
      'issue_date': issueDate,
      'address': address,
      'state': state,
      'country': country,
      'id_number': idNumber,
      'visiting_whom': visitingWhom,
      'purpose': visitReason,
      'badge_expiry': widget.badgeExpiry,
      'company_id': widget.companyId,
      'location_id': widget.locationId
    });

    try {
      final response = await http
          .post(
            url,
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: requestBody,
          )
          .timeout(Duration(seconds: ConfigManager.apiRequestTimeout));

      if (response.statusCode == 200) {
        print('Visitor inserted successfully');
      } else {
        print('Failed to insert visitor: Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error inserting visitor: $e');
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
                  children: [
                    const Text(
                      'Visitor Information',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    _buildInfoCard(
                      title: 'First Name',
                      content: firstName,
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      title: 'Last Name',
                      content: lastName,
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Who are you visiting?',
                      onSaved: (value) => visitingWhom = value!,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the name of the person you are visiting';
                        }
                        return null;
                      },
                      icon: Icons.people,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      label: 'Reason for Visit',
                      onSaved: (value) => visitReason = value!,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the reason for your visit';
                        }
                        return null;
                      },
                      icon: Icons.assignment,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          await addVisitor();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CameraPage(
                                firstName: firstName,
                                lastName: lastName,
                                badgeExpiry: widget.badgeExpiry,
                              ),
                            ),
                          );
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
                    const SizedBox(height: 20),
                    _buildDisclaimerText(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      {required String title,
      required String content,
      required IconData icon}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, size: 24, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required Function(String?) onSaved,
    required String? Function(String?) validator,
    required IconData icon,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      onSaved: onSaved,
      validator: validator,
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildDisclaimerText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Disclaimer: $companyDisclaimer',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[800],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
