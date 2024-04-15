// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:qr_code_scanner/qr_code_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qr Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
  _QrCodeScannerState createState() => _QrCodeScannerState();
}

class _QrCodeScannerState extends State<QrCodeScanner> {
  QRViewController? _controller;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  String _scannedCode = '';
  String scaned = '';
  static const String _appId = 'dowell.qrcodescan.app&hl=en&gl=US';
  bool _showScanner = true;
  Map<String, dynamic> _extractedData = {};
  String extractedData = '';
  bool isActive = false;
  List<dynamic> data = [];
  late String scanned;
  late String qrcodeId;
  String redirectLink = '';

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  checkType(String scannedCode) async {
    final splitedString = scannedCode.split(' ');
    print('The splitted string is: $splitedString');
    if (splitedString.length == 1) {
      //either an old qr or link
      setState(() {
        _scannedCode = scannedCode;
        scaned = scannedCode;
        // FFAppState().qr = scannedCode;
        _showScanner = false;
      });

      await launchAppStoreRedirect(_appId);
    } else {
      final qrId = splitedString[4];
      setState(() {
        _scannedCode = qrId;
        scaned = qrId;
        // FFAppState().qr = qrId;
        _showScanner = false;
      });

      await launchAppStoreRedirect(_appId);
    }
  }

  Future<Map<String, dynamic>> getQrCodeById(String id) async {
    final url = Uri.parse(
        'https://www.qrcodereviews.uxlivinglab.online/api/v5/update-qr-code/$id/');
    final response = await http.get(url);
    return json.decode(response.body);
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
      rethrow;
    }
  }

  bool _isLink(String data) {
    final Uri? uri = Uri.tryParse(data);
    return uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty;
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
      });
      print('The scanned data is: $extractedData');

      if (extractedData.contains('Decrypt it then Activate and Rescan')) {
        final regex = RegExp(r'encrypted with (\S+) and (\S+)');
        final match = regex.firstMatch(extractedData);
        if (match != null) {
          qrcodeId = match.group(1)!;
          print('QR code ID: $qrcodeId');
          // Make GET request to fetch QR code data by ID
          final qrCodeData = await getQrCodeById(qrcodeId);
          print('The data from the get request is: $qrCodeData ');
          final decryptedData = await decryptQrcode(
            qrcodeId,
          );
          data = decryptedData['response'];
          print('The extracted data from decrypt endpoint: $decryptedData');
          setState(() {
            _extractedData = decryptedData;
            print(_extractedData);
            _showScanner = false;
          });

          if (data.isNotEmpty) {
            final Map<String, dynamic> decryptqrCodeData = data.first;
            isActive = decryptqrCodeData['is_active'] ?? false;
            redirectLink = decryptqrCodeData['redirect_link'];
          }
          // setState(() {
          //   _extractedData = extractedData;
          // });
        }
      } else if (_isLink(extractedData)) {
        final Uri uri = Uri.parse(extractedData);
        qrcodeId = uri.pathSegments.last;
        print('QR code ID: $qrcodeId');
        final qrCodeData = await getQrCodeById(qrcodeId);
        print('The data from the get request is: $qrCodeData ');
        final decryptedData = await decryptQrcode(
          qrcodeId,
        );
        data = decryptedData['response'];
        print('The extracted data from decrypt endpoint: $decryptedData');
        setState(() {
          _extractedData = decryptedData;
          print(_extractedData);
          _showScanner = false;
        });

        if (data.isNotEmpty) {
          final Map<String, dynamic> decryptqrCodeData = data.first;
          isActive = decryptqrCodeData['is_active'] ?? false;
          redirectLink = decryptqrCodeData['redirect_link'] ?? '';
        }
        if (isActive) {
          // await _launchURL(redirectLink);
          await _launchInBrowserView(Uri.parse(redirectLink));
        }
        // await _launchURL(extractedData);
      } else if (extractedData.contains('Deactivated')) {
        final splitedString = extractedData.split(' ');
        if (splitedString.length > 4) {
          final qrId = splitedString[4];
          print('The QR ID to fetch: $qrId');
          // FFAppState().qr = qrId;
          // Make GET request to fetch QR code data by ID
          final qrCodeData = await getQrCodeById(qrId);
          print('The data from the get request is: $qrCodeData ');
          // Extract qrcode_id and iv from qrCodeData
          final qrcodeId = qrCodeData['qrcode_id'];
          final productName = qrCodeData['response'][0]['product_name'];
          final qrcodeImageUrl = qrCodeData['response'][0]['qrcode_image_url'];
          final createdBy = qrCodeData['response'][0]['created_by'];

          // final decryptedData = await decryptQrcode(qrcodeId, iv);
          // final decryptData = decryptedData['qrcode_id'];
          // print('The extracted data from decrypt endpoint: $decryptData');
          setState(() {
            _extractedData = qrCodeData;
            print(_extractedData);
            _showScanner = false;
          });
          // setState(() {
          //   _extractedData = extractedData;
          // });
        }
      } else {
        // Add a delay of 2 seconds before calling checkType
        checkType(scanned);
      }
    });
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

  Future<void> _launchInBrowserView(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    late final List<dynamic> itemList = data;
    print("The item list of the extracted data is:  $itemList");
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: _showScanner == true
                ? QRView(
                    key: _qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: QrScannerOverlayShape(
                      borderColor: const Color.fromARGB(30, 65, 137, 67),
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 350,
                    ),
                  )
                : itemList.isEmpty == true
                    ? Container(
                        height: 250,
                        width: 500,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                        ),
                        child: const Center(child: CircularProgressIndicator()))
                    : isActive == false
                        // Show alert dialog if is_active is false
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 28.0,
                                right: 28,
                                top: 250,
                              ),
                              child: Container(
                                child: Column(
                                  children: [
                                    Text(
                                      'QR Code Not Activated',
                                      style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 20),
                                    SelectableText(
                                      'The QR code is not activated yet. Use the QR code app to activate your QR code.',
                                      style: TextStyle(
                                        fontSize: 18,
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : isActive == true
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 28.0,
                                    right: 28,
                                    top: 250,
                                  ),
                                  child: InkWell(
                                    onTap: () async {
                                      // _launchURL(redirectLink);
                                      await _launchInBrowserView(
                                          Uri.parse(redirectLink));
                                    },
                                    child: Text(
                                      redirectLink,
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 15.0,
                                      right: 15.0,
                                      bottom: 30,
                                    ),
                                    child: ListView.separated(
                                      itemCount: itemList.length,
                                      separatorBuilder:
                                          (BuildContext context, int index) =>
                                              const SizedBox(height: 18),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        final Map<String, dynamic>? item =
                                            itemList[index];
                                        print('The items are: $item');
                                        if (item != null) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              // boxShadow: [
                                              //   BoxShadow(
                                              //     offset: const Offset(0, 5),
                                              //     blurRadius: 10.0,
                                              //     color: Colors.black.withOpacity(0.5),
                                              //   ),
                                              // ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children:
                                                  item.entries.map((entry) {
                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 15,
                                                      vertical: 18),
                                                  child: TextFormField(
                                                    textAlign: TextAlign.start,
                                                    initialValue:
                                                        ' ${entry.value ?? 'N/A'}',
                                                    cursorColor: Colors.black,
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 15,
                                                    ),
                                                    readOnly: true,
                                                    onTap: () {
                                                      // Enable text selection when tapped
                                                      FocusScope.of(context)
                                                          .requestFocus(
                                                              FocusNode());
                                                    },
                                                    // Ensure text is displayed within a single line
                                                    maxLines: 1,
                                                    decoration: InputDecoration(
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .fromLTRB(4.0,
                                                              0.0, 4.0, 0.0),
                                                      filled: false,
                                                      fillColor:
                                                          Colors.transparent,
                                                      labelText: entry.key,
                                                      labelStyle:
                                                          const TextStyle(
                                                        color:
                                                            Color(0xFF187B2B),
                                                        fontSize: 20,
                                                      ),
                                                      border:
                                                          OutlineInputBorder(
                                                        gapPadding: 0.0,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        borderSide:
                                                            const BorderSide(
                                                                color: Color(
                                                                    0xFF187B2B)),
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                        gapPadding: 0.0,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        borderSide:
                                                            const BorderSide(
                                                                width: 3,
                                                                color: Color(
                                                                    0xFF187B2B)),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          );
                                        }

                                        return const SizedBox(
                                          child: Text(
                                              'Error extracting the qrcode details. '),
                                        ); // Return an empty SizedBox if item is null or index is out of bounds
                                      },
                                    ),
                                  ),
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
