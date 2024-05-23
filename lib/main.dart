// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:qr_code_scanner/qr_code_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Qr Code',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const QrCodeScanner(),
    );
  }
}

class QrCodeScanner extends StatefulWidget {
  const QrCodeScanner({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<QrCodeScanner> createState() => _QrCodeScannerState();
}

class _QrCodeScannerState extends State<QrCodeScanner> {
  QRViewController? _controller;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  String _scannedCode = '';
  static const String _appId = 'dowell.qrcodescan.app&hl=en&gl=US';
  bool _showScanner = true;
  String extractedData = '';
  bool? isActive;
  bool _isLoading = false;
  List<dynamic> data = [];
  late String qrcodeId;
  String redirectLink = '';

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> getQrCodeById(String id) async {
    final url = Uri.parse(
        'https://www.qrcodereviews.uxlivinglab.online/api/v5/decrypt-qrcode/?id=$id');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final Map<String, dynamic> qrResponse = responseData['response'];
        print('qrResponse: $qrResponse');

        if (qrResponse.containsKey('data')) {
          final List<dynamic> qrDataList = qrResponse['data'];
          print("qrdatalist : $qrDataList");

          if (qrDataList.isNotEmpty) {
            final Map<String, dynamic> qrData = qrDataList.first;
            if (qrData['is_active'] is String) {
              isActive = qrData['is_active'] == "true";
            } else {
              // If it's not a String, assume it's already a bool
              isActive = qrData['is_active'] ?? false;
            }
            print("qrdatalist isActive : $isActive");
            redirectLink = qrData['redirect_link'] ?? '';
            print("qrdatalist redirectLink: $redirectLink");

            return responseData;
          } else {
            throw Exception('No data found for QR code ID: $id');
          }
        } else {
          throw Exception('No data key found in response.');
        }
      } else {
        // Request failed
        print('GET request failed with status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(
            'Failed to get QR code data. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      // An error occurred
      print('Error occurred during GET request: $error');
      throw error;
    }
  }

  // Function to make a POST API request to decrypt QR code
  Future<Map<String, dynamic>> decryptQrcode(String qrcodeId) async {
    final url = Uri.parse(
        'https://www.qrcodereviews.uxlivinglab.online/api/v5/decrypt/$qrcodeId/');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Request was successful
        print('POST request successful');
        print('Response body: ${response.body}');

        // Parse the response JSON
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData;
      } else {
        // Request failed
        print('POST request failed with status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(
            'Failed to decrypt QR code. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      // An error occurred
      print('Error occurred during POST request: $error');
      throw error;
    }
  }

  bool _isLink(String data) {
    final Uri? uri = Uri.tryParse(data);
    return uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty;
  }

  bool _isValidQrCodeId(String id) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(id);
  }

  void _onQRViewCreated(QRViewController controller) async {
    setState(() {
      _controller = controller;
    });

    _controller!.scannedDataStream.listen((scanData) async {
      final scanned = scanData.code!;
      setState(() {
        extractedData = scanned;
        _showScanner = false;
        _isLoading = true;
        _scannedCode = scanned;
      });
      print('The scanned data is: $extractedData');

      if (_isLink(extractedData)) {
        final Uri uri = Uri.parse(extractedData);
        qrcodeId = uri.pathSegments.last;

        if (_isValidQrCodeId(qrcodeId)) {
          print('QR code ID: $qrcodeId');
          final decryptedData = await decryptQrcode(qrcodeId);
          data = decryptedData['response'];
          print('The extracted data from decrypt endpoint: $decryptedData');
          await getQrCodeById(qrcodeId);

          if (isActive!) {
            setState(() {
              _showScanner = false;
              _isLoading = false;
            });
          } else {
            setState(() {
              _scannedCode =
                  'The QR code is not activated yet. Use the QR code app to activate your QR code.';
              _showScanner = false;
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _scannedCode =
                'This QR Code was not generated by DoWell QR Code Generator app';
            _showScanner = false;
            _isLoading = false;
          });
          _showAlertDialog();
        }
      } else {
        setState(() {
          _scannedCode =
              'This QR Code was not generated by DoWell QR Code Generator app';
          _showScanner = false;
          _isLoading = false;
        });
        _showAlertDialog();
      }
    });
  }

  void _showAlertDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          content: Text("Do you still want to open?", style: TextStyle(
            fontSize: 16,
          ),),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all(Colors.green.shade700),
                ),
                onPressed: () async {
                  Navigator.of(context).pop(); // Close the dialog
                  await launchAppStoreRedirect(_appId);
                },
                child: Text("Yes",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Colors.red),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: Text("No",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    )),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> launchAppStoreRedirect(String appId) async {
    // Handle platform-specific redirection
    if (await canLaunchUrl(Uri.parse('market://details?id=$appId'))) {
      await launchUrl(Uri.parse('market://details?id=$appId')); // Play Store
    } else if (await canLaunchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$appId'))) {
      await launchUrl(Uri.parse(
          'https://play.google.com/store/apps/details?id=$appId')); // Web fallback
    } else {
      // Handle cases where redirection is not possible
    }
  }

  Future<void> _launchView(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _launchInBrowserView(Uri url) async {
    try {
      if (Platform.isAndroid) {
        await launchUrl(url, mode: LaunchMode.inAppWebView);
      }
    } on PlatformException catch (error) {
      _handleError(context, error);
    } catch (error) {
      _handleError(context, error);
    }
  }

  void _handleError(BuildContext context, error) {
    print("Error launching URL: $error");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to launch URL: $error'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: _showScanner
                ? QRView(
                    key: _qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: QrScannerOverlayShape(
                      borderColor: Color.fromARGB(30, 65, 137, 67),
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 350,
                    ),
                  )
                : _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _buildMessageWidget(),
          ),
          if(isActive == true)
            InkWell(
              onTap: () async {
                await _launchInBrowserView(Uri.parse(redirectLink));
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25, bottom: 10, top: 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.grey.shade600,
                  ),
                  width: MediaQuery.of(context).size.width,
                  height: 60,
                  child: Center(
                    child: Text(
                      'Open URL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          if (!_showScanner)
            InkWell(
              onTap: () {
                setState(() {
                  _showScanner = true;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25, bottom: 30, top: 10),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.grey.shade600,
                  ),
                  width: MediaQuery.of(context).size.width,
                  height: 60,
                  child: Center(
                    child: Text(
                      'Rescan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        //fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),

        ],
      ),
    );
  }

  Widget _buildMessageWidget() {
    if (_scannedCode.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            _scannedCode,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (isActive != null && !isActive!) {
      return buildInactiveQRCodeWidget();
    } else if (isActive == true) {
      return buildActiveQRCodeWidget(redirectLink);
    } else {
      return SizedBox.shrink();
    }
  }

  Widget buildInactiveQRCodeWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 28.0,
          right: 28,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SelectableText(
              'The QR code is not activated yet. Use the QR code app to activate your QR code.',
              style: TextStyle(
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget buildActiveQRCodeWidget(String redirectLink) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 28.0, right: 28),
        child: Text(
          redirectLink,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
