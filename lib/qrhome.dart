// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QrCodeScanner extends StatefulWidget {
  const QrCodeScanner({super.key, this.width, this.height, this.productType});

  final double? width;
  final double? height;
  final String? productType;

  @override
  State<QrCodeScanner> createState() => _QrCodeScannerState();
}

class _QrCodeScannerState extends State<QrCodeScanner> {
  QRViewController? _controller;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  String _scannedCode = '';
  static const String _appId = 'dowell.qrcodescan.app&hl=en&gl=US';
  bool _showScanner = true;
  late String workspace_id;
  late String portfolio_name;

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

  // Future<Map<String, double>?> getUserLocation() async {
  //   try {
  //     LocationPermission permission = await Geolocator.checkPermission();
  //     if (permission == LocationPermission.denied ||
  //         permission == LocationPermission.deniedForever) {
  //       permission = await Geolocator.requestPermission();
  //       if (permission == LocationPermission.denied ||
  //           permission == LocationPermission.deniedForever) {
  //         return null;
  //       }
  //     }
  //     Position position = await Geolocator.getCurrentPosition();
  //     return {'latitude': position.latitude, 'longitude': position.longitude};
  //   } catch (e) {
  //     print('Error getting location: $e');
  //     return null;
  //   }
  // }

  Future<void> sendQrCodeData({
    required String qrId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      String url =
          'https://www.qrcodereviews.uxlivinglab.online/api/v6/qrcode-data/';
      String timezone = DateTime.now().timeZoneName;

      Map<String, String> payload = {
        'qrcode_id': qrId,
        'timezone': "Asia/Kolkata",
        'lat': latitude.toString(),
        'long': longitude.toString(),
      };

      http.Response response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        print('Data sent successfully');
      } else {
        print('Failed to send data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending data: $e');
    }
  }

  Future<Map<String, dynamic>> getChildQrCodeDetails(String id) async {
    final url = Uri.parse(
        'https://www.qrcodereviews.uxlivinglab.online/api/v6/qrcodes/22-$id');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Extract necessary fields from the response
        var isActiveValue = responseData['is_active'];

        if (isActiveValue is String) {
          isActive = isActiveValue.toLowerCase() == 'true';
        } else if (isActiveValue is bool) {
          isActive = isActiveValue;
        } else {
          isActive =
              false; // Default to false if the type is neither String nor bool
        }

        redirectLink = responseData['redirect_link'] ?? '';

        debugPrint('isActive: $isActive');
        debugPrint('redirectLink: $redirectLink');

        // Return the entire responseData or any other relevant part
        return responseData;
      } else {
        throw Exception(
            'Failed to get QR code details. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error occurred during GET request: $error');
      throw error;
    }
  }

  Future<Map<String, dynamic>> getMasterQrCodeDetails(String id) async {
    final url = Uri.parse(
        'https://www.qrcodereviews.uxlivinglab.online/api/v6/master-qrcodes/?action=master_qr_code_id&master_qr_code_id=$id');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception(
            'Failed to get QR code details. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error occurred during GET request: $error');
      throw error;
    }
  }

  bool _isLink(String data) {
    final Uri? uri = Uri.tryParse(data);
    return uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty;
  }

  bool _isValidQrCodeId(String id) {
    final uuidWithPrefixRegex = RegExp(
        r'^22-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidWithPrefixRegex
        .hasMatch('22-$id'); // Add '22-' prefix for validation
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
        // FFAppState().textChanged = true;
      });
      print('The scanned data is: $extractedData');
      final dynamic lastSegment;
      if (_isLink(extractedData)) {
        final Uri uri = Uri.parse(extractedData);
        lastSegment = uri.pathSegments.last;
        print('Last segment of URL: $lastSegment');

        if (lastSegment.startsWith("22-")) {
          qrcodeId = lastSegment.substring(3);
          print('Extracted QR code ID: $qrcodeId');

          if (_isValidQrCodeId(qrcodeId)) {
            print('QR code ID is valid: $qrcodeId');

            await getChildQrCodeDetails(qrcodeId);

            // Get user location
            // final location = await getUserLocation();
            // if (location != null) {
            //   double latitude = location['latitude']!;
            //   double longitude = location['longitude']!;

            double lat = double.parse(FFAppState().latitude);
            double long = double.parse(FFAppState().longitude);
            await sendQrCodeData(
              qrId: lastSegment,
              latitude: lat,
              longitude: long,
            );
            // } else {
            //   print('Unable to get user location.');
            // }

            if (FFAppState().response != null) {
              final Map<String, dynamic> responseMap = FFAppState().response;
              if (responseMap.containsKey('product') == 'all') {
                if (responseMap.containsKey('org_id')) {
                  FFAppState().workspaceId = responseMap['org_id'];
                  workspace_id = FFAppState().workspaceId;
                }

                if (responseMap.containsKey('portfolio_name')) {
                  FFAppState().portfolioId = responseMap['portfolio_name'];
                  portfolio_name = FFAppState().portfolioId;
                } else {
                  // Handle the case where "response" is not present
                  print('WARNING: response not found.');
                }
              }
            }

            if (isActive == true) {
              if (widget.productType != null) {
                if (widget.productType == "waste") {
                  if (redirectLink.contains(
                      "https://100093.pythonanywhere.com/linklanding")) {
                    print("Assigned Team ${FFAppState().assignedTeamName}");
                    final Uri refinedRedirectUri = Uri.parse(redirectLink);

                    await _launchInBrowserView(
                        Uri.parse(refinedRedirectUri.replace(queryParameters: {
                      ...refinedRedirectUri.queryParameters,
                      'team_name': FFAppState().assignedTeamName
                    }).toString()));
                  }
                } else if (widget.productType == "school" ||
                    widget.productType == "bus") {
                  if (redirectLink.contains(
                      "https://100093.pythonanywhere.com/userdetails")) {
                    /*final Map<String, dynamic> newQueryParams = {
                      'workspace_id': workspace_id,
                      'portfolio_name': portfolio_name
                    };*/
                    final Uri refinedRedirectUri = Uri.parse(redirectLink);

                    await _launchInBrowserView(
                        Uri.parse(refinedRedirectUri.replace(queryParameters: {
                      ...refinedRedirectUri.queryParameters,
                      'workspace_id': workspace_id,
                      'portfolio_name': portfolio_name
                    }).toString()));
                  }
                }
              } else {
                await _launchInBrowserView(Uri.parse(redirectLink));
              }
            }

            setState(() {
              _showScanner = false;
              _isLoading = false;
            });
          } else {
            setState(() {
              _scannedCode =
                  'This QR Code was not generated by DoWell QR Code Generator app';
              _showScanner = false;
              _isLoading = false;
            });

            Future.delayed(Duration(seconds: 3), () {
              // _launchView(Uri.parse(extractedData));
              _showNewAlertDialog(extractedData);
            });
          }
        } else if (lastSegment.startsWith("11-")) {
          qrcodeId = lastSegment;
          // final location = await getUserLocation();
          // if (location != null) {
          //   double latitude = location['latitude']!;
          //   double longitude = location['longitude']!;

          double lat = double.parse(FFAppState().latitude);
          double long = double.parse(FFAppState().longitude);
          await sendQrCodeData(
            qrId: lastSegment,
            latitude: lat,
            longitude: long,
          );
          // } else {
          //   print('Unable to get user location.');
          // }

          final masterQrCodeDetails = await getMasterQrCodeDetails(qrcodeId);
          final childQRCodes =
              masterQrCodeDetails['qr_code_details'] as List<dynamic>;

          showModalBottomSheet(
            context: context,
            isDismissible: false,
            isScrollControlled: true,
            builder: (BuildContext context) {
              return DraggableScrollableSheet(
                expand: false,
                builder:
                    (BuildContext context, ScrollController scrollController) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 25.0),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Select a QR Code',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: childQRCodes.length,
                            itemBuilder: (BuildContext context, int index) {
                              final childQRCode = childQRCodes[index];
                              return Card(
                                child: ListTile(
                                  leading: Image.network(
                                    childQRCode['qrcode_image_url'],
                                    height: 100,
                                    width: 100,
                                  ),
                                  title: Text(childQRCode['qr_id']),
                                  onTap: () async {
                                    setState(() {
                                      _showScanner = false;
                                      _isLoading = true;
                                    });
                                    Navigator.of(context).pop();
                                    qrcodeId =
                                        childQRCode['qr_id'].substring(3);

                                    if (_isValidQrCodeId(qrcodeId)) {
                                      print('QR code ID is valid: $qrcodeId');

                                      await getChildQrCodeDetails(qrcodeId);

                                      if (isActive == true) {
                                        await _launchInBrowserView(
                                            Uri.parse(redirectLink));
                                      }
                                      setState(() {
                                        _showScanner = false;
                                        _isLoading = false;
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );

          setState(() {
            _showScanner = false;
            _isLoading = false;
          });
        } else {
          setState(() {
            _scannedCode =
                'Invalid QR Code format. Please scan a valid Dowell QR Code.';
            _showScanner = false;
            _isLoading = false;
          });

          Future.delayed(Duration(seconds: 3), () {
            // _launchView(Uri.parse(extractedData));
            _showNewAlertDialog(extractedData);
          });
        }
      } else {
        setState(() {
          _scannedCode =
              'This QR Code was not generated by DoWell QR Code Generator app';
          _showScanner = false;
          _isLoading = false;
        });

        Future.delayed(Duration(seconds: 3), () {
          // _launchView(Uri.parse(extractedData));
          _showAlertDialog();
        });
      }
    });
  }

  void _showNewAlertDialog(String url) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          content: Text(
            "Do you still want to open?",
            style: TextStyle(
              fontSize: 18,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(Colors.green.shade700),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _launchView(Uri.parse(url));
                  // await launchAppStoreRedirect(_appId);
                },
                child: Text("Yes",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                    )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.red),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("No",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    )),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAlertDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          content: Text(
            "Do you still want to open?",
            style: TextStyle(
              fontSize: 18,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(Colors.green.shade700),
                ),
                onPressed: () async {
                  String uri =
                      "https://www.qrcodereviews.uxlivinglab.online/api/v6/redirect_link/11-6489c987-c8b0-4001-ac45-4caef62c74c3/";
                  Navigator.of(context).pop();
                  await _launchView(Uri.parse(uri));
                  // await launchAppStoreRedirect(_appId);
                },
                child: Text(
                  "Yes",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.red),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("No",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    )),
              ),
            ),
          ],
        );
      },
    );
  }

  // Future<void> launchAppStoreRedirect(String appId) async {
  //   if (await canLaunchUrl(Uri.parse('market://details?id=$appId'))) {
  //     await launchUrl(Uri.parse('market://details?id=$appId'));
  //   } else if (await canLaunchUrl(
  //       Uri.parse('https://play.google.com/store/apps/details?id=$appId'))) {
  //     await launchUrl(
  //         Uri.parse('https://play.google.com/store/apps/details?id=$appId'));
  //   } else {}
  // }

  Future<void> _launchView(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _launchInBrowserView(Uri url) async {
    try {
      if (Platform.isAndroid) {
        await launchUrl(url,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: WebViewConfiguration(
              enableJavaScript: true,
            ));
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
    return Column(
      children: [
        Expanded(
          child: _showScanner == true
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
        if (isActive == true)
          InkWell(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 25.0, right: 25, bottom: 10, top: 10),
              child: InkWell(
                onTap: () async {
                  if (Platform.isAndroid)
                    await _launchInBrowserView(Uri.parse(redirectLink));

                  if (Platform.isIOS) {
                    await _launchView(Uri.parse(redirectLink));
                  }
                },
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
          ),
        if (!_showScanner)
          InkWell(
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 25.0, right: 25, bottom: 30, top: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showScanner = true;
                    _scannedCode = '';
                    extractedData = '';
                    isActive = null;
                    //  FFAppState().textChanged = false;
                  });
                },
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
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
      // final Uri redirectUri = Uri.parse(redirectLink);
      // final Map<String, dynamic> newQueryParams = {
      //   'workspace_id': workspace_id,
      //   'portfolio_name': portfolio_name
      // };
      // final Uri updatedRedirectUrl =
      //     redirectUri.replace(queryParameters: newQueryParams);
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

  Widget buildActiveQRCodeWidget(String updatedUrl) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 28.0, right: 28),
        child: Text(
          updatedUrl,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
