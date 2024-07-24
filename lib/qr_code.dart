// // Automatic FlutterFlow imports
// import '/flutter_flow/flutter_flow_theme.dart';
// import '/flutter_flow/flutter_flow_util.dart';
// import '/custom_code/widgets/index.dart'; // Imports other custom widgets
// import '/custom_code/actions/index.dart'; // Imports custom actions
// import '/flutter_flow/custom_functions.dart'; // Imports custom functions
// import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:intl/intl.dart';

import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:qr_code_scanner/qr_code_scanner.dart';

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
  String _scannedCode = "";
  static const String _appId = 'dowell.qrcodescan.app&hl=en&gl=US';
  bool _showScanner = true;
  late String workspace_id;
  late String portfolio_name;
  bool success = true;
  String message = "";
  bool childScanned = false;
  bool masterScanned = false;

  String extractedData = '';
  bool _isLoading = false;
  List<dynamic> childQrs = [];
  List<dynamic> data = [];
  late String qrcodeId;
  String redirectLink = '';
  late double lat;
  late double long;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future getLocation() async {
    // Add your function code here!

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }

      Position position = await Geolocator.getCurrentPosition();

// Extract the latitude and longitude from the position object
      lat = position.latitude;
      long = position.longitude;
      // FFAppState().latitude = latitude.toString();
      // FFAppState().longitude = longitude.toString();
      // final coordinates = Coordinates(latitude, longitude);
      // final addresses = await Geocoder.local.geocode(coordinates);
      // final address = addresses.first;

// Print the latitude and longitude
      print('Latitude: $lat');
      print('Longitude: $long');
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }

    // return {'Latitude': latitude, 'Longitude': longitude};
  }

  Future<void> saveQrStats({
    required String qrId,
    required double latitude,
    required double longitude,
    String workspaceId = '',
  }) async {
    try {
      String url =
          'https://www.qrcode.uxlivinglab.online/api/v1/statistics/save-stats/?qrcodeId=$qrId&latitude=$latitude&longitude=$longitude&workspaceId=$workspaceId';

      http.Response response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('Data sent successfully');
      } else {
        print('Failed to send data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending data: $e');
    }
  }

  Future<Map<String, dynamic>> scanChildQrCode(
      dynamic id, double latitude, double longitude) async {
    final url = Uri.parse(
        'https://www.qrcode.uxlivinglab.online/api/v1/qrcode/scan-child-qrcode/?childQrcodeId=$id&latitude=$latitude&longitude=$longitude');
    print(url.toString());
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        success = responseData['success'];
        if (success == false) {
          message = responseData['message'];
          print('Message: $message');
        } else {
          redirectLink = responseData['response']['childQrcodeLink'];
          print('Redirect Link: $redirectLink');
        }

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

  Future<Map<String, dynamic>> scanMasterQrCode(
    dynamic id,
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse(
        'https://www.qrcode.uxlivinglab.online/api/v1/qrcode/scan-master-qrcode/?masterQrcodeId=$id&latitude=$latitude&longitude=$longitude');
    print(url.toString());
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        success = responseData['success'];
        if (success == false) {
          message = responseData['message'];
          print('Message: $message');
        } else {
          childQrs = responseData['response'];
        }

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
    return uuidWithPrefixRegex.hasMatch('22-$id');
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
          qrcodeId = lastSegment;
          print('Extracted QR code ID: $qrcodeId');

          if (_isValidQrCodeId(qrcodeId)) {
            print('QR code ID is valid: $qrcodeId');

            // double lat = double.parse(FFAppState().latitude);
            // double long = double.parse(FFAppState().longitude);
            await saveQrStats(qrId: qrcodeId, latitude: lat, longitude: long);
            await scanChildQrCode(qrcodeId, lat, long);

            if (success == false) {
              setState(() {
                _scannedCode = message;
              });
            } else {
              await _launchInBrowserView(Uri.parse(redirectLink));
            }

            setState(() {
              _showScanner = false;
              _isLoading = false;
              childScanned = true;
            });
          } else {
            setState(() {
              _scannedCode =
                  'This QR Code was not generated by DoWell QR Code Generator app';
              _showScanner = false;
              _isLoading = false;
            });

            Future.delayed(Duration(seconds: 3), () {
              _showNewAlertDialog(extractedData);
            });
          }
        } else if (lastSegment.startsWith("11-")) {
          qrcodeId = lastSegment;
          // double lat = double.parse(FFAppState().latitude);
          // double long = double.parse(FFAppState().longitude);
          await saveQrStats(qrId: qrcodeId, latitude: lat, longitude: long);

          await scanMasterQrCode(qrcodeId, lat, long);

          if (success == false) {
            setState(() {
              _scannedCode = message;
            });
          } else {
            setState(() {
              _showScanner = false;
              // For displaying the list of child QRs on the screen
              masterScanned = true;
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _scannedCode =
                'Invalid QR Code format. Please scan a valid Dowell QR Code.';
            _showScanner = false;
            _isLoading = false;
          });

          Future.delayed(Duration(seconds: 3), () {
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

        // Future.delayed(Duration(seconds: 3), () {
        //   _showAlertDialog();
        // });
      }
    });
  }

  void _showNewAlertDialog(String url) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Invalid QR Code'),
          content: Text(
              'This QR Code was not generated by DoWell QR Code Generator app'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _launchInBrowserView(Uri.parse(url));
              },
              child: Text('Open Link'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchView(Uri url) async {
    if (!await launchUrl(
      url,
      mode: LaunchMode.inAppBrowserView,
    )) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _launchInBrowserView(Uri url) async {
    try {
      if (Platform.isAndroid) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Handle other platforms if needed
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

  // Future<void> _launchInBrowserView(Uri url) async {
  //   if (await canLaunch(url.toString())) {
  //     await launch(
  //       url.toString(),
  //       forceSafariVC: false,
  //       forceWebView: false,
  //     );
  //   } else {
  //     throw 'Could not launch $url';
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_showScanner == true)
            Expanded(
              child: QRView(
                key: _qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Color.fromARGB(30, 65, 137, 67),
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 300,
                ),
              ),
            ),
          if (_showScanner == false)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMessageWidget(),
                  ],
                ),
              ),
            ),
          if (_showScanner == false)
            InkWell(
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 25.0, right: 25, bottom: 30, top: 10),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _scannedCode = '';
                      _showScanner = true;
                      _isLoading = false;
                      masterScanned = false;
                      childQrs.clear(); // Clear the list of child QRs
                      // FFAppState().textChanged = false;
                    });
                    _controller!.resumeCamera();
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
                        'Scan Again',
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
          if (childScanned == true || masterScanned == true)
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
        ],
      ),
    );
  }

  Widget _buildMessageWidget() {
    if (_isLoading) {
      return CircularProgressIndicator();
    } else if (_scannedCode != "") {
      return Text(
        _scannedCode,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          color: Colors.black,
        ),
      );
    } else if (childQrs.isNotEmpty) {
      return Column(children: [
        Text(
          'Avalible QrCode(s)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 20),
        buildAvailableChildQr()
      ]);
    } else {
      return Text(
        'Scanning not started yet',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          color: Colors.black,
        ),
      );
    }
  }

  Widget buildAvailableChildQr() {
    return Expanded(
      child: ListView.builder(
        // controller: scrollController,
        itemCount: childQrs.length,
        itemBuilder: (BuildContext context, int index) {
          final childQRCode = childQrs[index];
          return Card(
            child: ListTile(
              leading: Image.network(
                childQRCode['childQrcodeImageUrl'],
                height: 100,
                width: 100,
              ),
              title: Text(childQRCode["fieldsData"]["name"]),
              subtitle: Text(childQRCode["fieldsData"]["description"]),
              onTap: () async {
                setState(() {
                  _showScanner = false;
                  _isLoading = true;
                });
                Navigator.of(context).pop();
                // double lat = double.parse(FFAppState().latitude);
                // double long = double.parse(FFAppState().longitude);
                await saveQrStats(
                    qrId: qrcodeId, latitude: lat, longitude: long);
                await scanChildQrCode(qrcodeId, lat, long);

                if (success == false) {
                  setState(() {
                    _scannedCode = message;
                  });
                } else {
                  await _launchInBrowserView(Uri.parse(redirectLink));
                }

                setState(() {
                  _showScanner = false;
                  _isLoading = false;
                  childScanned = true;
                });
              },
            ),
          );
        },
      ),
    );
  }
}
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Expanded(
//           child: _showScanner == true
//               ? QRView(
//                   key: _qrKey,
//                   onQRViewCreated: _onQRViewCreated,
//                   overlay: QrScannerOverlayShape(
//                     borderColor: Color.fromARGB(30, 65, 137, 67),
//                     borderRadius: 10,
//                     borderLength: 30,
//                     borderWidth: 10,
//                     cutOutSize: 350,
//                   ),
//                 )
//               : _isLoading
//                   ? Center(child: CircularProgressIndicator())
//                   : _buildMessageWidget(),
//         ),
//         if (isActive == true)
//           InkWell(
//             child: Padding(
//               padding: const EdgeInsets.only(
//                   left: 25.0, right: 25, bottom: 10, top: 10),
//               child: InkWell(
//                 onTap: () async {
//                   if (Platform.isAndroid)
//                     await _launchInBrowserView(Uri.parse(redirectLink));

//                   if (Platform.isIOS) {
//                     await _launchView(Uri.parse(redirectLink));
//                   }
//                 },
//                 child: Container(
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(25),
//                     color: Colors.grey.shade600,
//                   ),
//                   width: MediaQuery.of(context).size.width,
//                   height: 60,
//                   child: Center(
//                     child: Text(
//                       'Open URL',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         if (!_showScanner)
//           InkWell(
//             child: Padding(
//               padding: const EdgeInsets.only(
//                   left: 25.0, right: 25, bottom: 30, top: 10),
//               child: InkWell(
//                 onTap: () {
//                   setState(() {
//                     _showScanner = true;
//                     _scannedCode = '';
//                     extractedData = '';
//                     isActive = null;
//                     FFAppState().textChanged = false;
//                   });
//                 },
//                 child: Container(
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(25),
//                     color: Colors.grey.shade600,
//                   ),
//                   width: MediaQuery.of(context).size.width,
//                   height: 60,
//                   child: Center(
//                     child: Text(
//                       'Rescan',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _buildMessageWidget() {
//     if (_scannedCode.isNotEmpty) {
//       return Padding(
//         padding: const EdgeInsets.all(20),
//         child: Center(
//           child: Text(
//             _scannedCode,
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.red,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ),
//       );
//     } else if (isActive != null && !isActive!) {
//       return buildInactiveQRCodeWidget();
//     } else if (isActive == true) {
//       // final Uri redirectUri = Uri.parse(redirectLink);
//       // final Map<String, dynamic> newQueryParams = {
//       //   'workspace_id': workspace_id,
//       //   'portfolio_name': portfolio_name
//       // };
//       // final Uri updatedRedirectUrl =
//       //     redirectUri.replace(queryParameters: newQueryParams);
//       return buildActiveQRCodeWidget(redirectLink);
//     } else {
//       return SizedBox.shrink();
//     }
//   }

//   Widget buildInactiveQRCodeWidget() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.only(
//           left: 28.0,
//           right: 28,
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             SelectableText(
//               'The QR code is not activated yet. Use the QR code app to activate your QR code.',
//               style: TextStyle(
//                 fontSize: 16,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             SizedBox(height: 20),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildActiveQRCodeWidget(String updatedUrl) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.only(left: 28.0, right: 28),
//         child: Text(
//           updatedUrl,
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//             color: Colors.grey.shade800,
//           ),
//           textAlign: TextAlign.center,
//         ),
//       ),
//     );
//   }
// }