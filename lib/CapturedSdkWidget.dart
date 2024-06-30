import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:captur/ScannedDataCubit.dart';
import 'package:capturesdk_flutter/capturesdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class CapturedSdkWidget extends StatefulWidget {
  final String title;

  const CapturedSdkWidget({Key? key, required this.title}) : super(key: key);

  @override
  CapturedSdkWidgetState createState() => CapturedSdkWidgetState();
}

class CapturedSdkWidgetState extends State<CapturedSdkWidget> {
  late AppInfo appInfo;
  static const routeName = '/CapturedSdkScreen';

  String _status = 'starting';
  String _message = '--';
  List<DeviceInfo> _devices = [];
  List<DecodedData> _decodedDataList = [];
  Capture? _capture;
  Capture? _deviceCapture;
  Capture? _bleDeviceManagerCapture;
  CaptureEvent? _currentscan;
  Capture? _socketcamDevice;
  bool _useSocketCam = false;
  bool _isOpen = false;
  bool _isLoading = true;

  Future<void> closeBluetooth() async {
    try {
      print('Closing Bluetooth...');
      await _closeCapture();
      print('Bluetooth closed.');
    } catch (error) {
      print('Error closing Bluetooth: $error');
    }
  }

  Future<void> openBluetooth() async {
    try {
      print('Opening Bluetooth...');
      await initializeCapture();
      print('Bluetooth opened.');
    } catch (error) {
      print('Error opening Bluetooth: $error');
    }
  }

  Logger logger = Logger((message, arg) {
    if (message.isNotEmpty) {
      // ignore: avoid_print
      print('CAPTURE FLUTTER: $message $arg\n\n');
    } else {
      // ignore: avoid_print
      print('CAPTURE FLUTTER: $arg\n\n');
    }
  });

  void _updateVals(String stat, String mess,
      [String? method, String? details]) {
    if (!mounted) return;
    setState(() {
      _status = stat;
      String tempMsg = mess;
      if (method != null) {
        tempMsg += '\n Method: ' + method + '\n';
      }
      if (details != null) {
        tempMsg += '\n Details: ' + details + '\n';
      }
      _message = tempMsg;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize state variables
    _status = 'starting';
    _message = '--';
    _devices = [];
    _decodedDataList = [];
    _isOpen = false;
    appInfo = Provider.of<AppInfo>(context, listen: false);
    print("appInfo");

    print(appInfo);
    if (Platform.isAndroid) {
      // Need to start service if you do not want to manually open Socket Mobile Companion
      // start capture service for companion before using Socket Cam on Android
      requestNetworkPermission(context);
    } else if (Platform.isIOS) {
      //requestIOSPermissions();
      // Future.delayed(Duration(seconds: 3), () async {
      //   try {
      //     await _openCapture().timeout(Duration(seconds: 3), onTimeout: () {
      //       throw TimeoutException('Capture openClient timed out');
      //     });
      //   } catch (error) {
      //     _updateVals('Error initializing Capture Service', error.toString());
      //   }
      // });
      //_openCapture();
      //requestIOSPermissions();
      initializeCapture();
    } else {
      _updateVals('Permission Denied', 'Bluetooth permission denied on iOS');
    }
  }

  void requestIOSPermissions() async {
    // Request Bluetooth, Location, and Camera permissions for iOS
    var bluetoothStatus = await Permission.bluetooth.status;
    var locationStatus = await Permission.location.status;
    var cameraStatus = await Permission.camera.status;

    if (!bluetoothStatus.isGranted ||
        !locationStatus.isGranted ||
        !cameraStatus.isGranted) {
      var results = await [
        Permission.bluetooth,
        Permission.location,
        Permission.camera,
      ].request();

      if (results[Permission.bluetooth] == PermissionStatus.granted &&
          results[Permission.location] == PermissionStatus.granted &&
          results[Permission.camera] == PermissionStatus.granted) {
        await _openCapture();
      } else {
        // Handle permission denied case
        print("Bluetooth, Location, or Camera permission denied.");
      }
    } else {
      await _openCapture();
    }
  }

  Future<void> initializeCapture() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _openCapture();
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      print('Error initializing Capture SDK: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void requestNetworkPermission(BuildContext context) async {
    var status = await Permission.bluetoothConnect.status;
    if (!status.isGranted) {
      var result = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Permission Required"),
            content: Text(
                "This app requires Bluetooth access to function properly."),
            actions: <Widget>[
              TextButton(
                child: Text("CANCEL"),
                onPressed: () {
                  Navigator.of(context).pop(false); // Permission denied
                },
              ),
              TextButton(
                child: Text("ALLOW"),
                onPressed: () {
                  Navigator.of(context).pop(true); // Permission granted
                },
              ),
            ],
          );
        },
      );

      if (result == true) {
        // User granted permission, continue with initialization
        await Permission.bluetoothConnect.request();
        status = await Permission.bluetooth.status;
      } else {
        // User denied permission, handle accordingly (print to console)
        print("Network permission denied.");
      }
    }

    if (status.isGranted) {
      // Proceed with initialization
      await _initializeCaptureService();
    }
  }

  void requestLocationPermissions() async {
    var status = await Permission.location.status;
    if (!status.isGranted) {
      var result = await Permission.location.request();
      if (result.isGranted) {
        await _initializeCaptureService();
      } else {
        // Handle permission denied case
        print("Location permission denied.");
      }
    } else {
      await _initializeCaptureService();
    }
  }

  Future<void> _initializeCaptureService() async {
    try {
      // Wait for the completion of startCaptureService
      await CapturePlugin.startCaptureService();

      // Once startCaptureService completes, call _openCapture
      _openCapture();
    } catch (error) {
      // Handle errors here
      _updateVals('Error initializing Capture Service', error.toString());
    }
  }

  Future _openCapture() async {
    Capture capture = Capture(logger);

    setState(() {
      _capture = capture;
    });

    String stat = _status;
    String mess = _message;
    String? method;
    String? details;

    try {
      int? response = await capture.openClient(appInfo, _onCaptureEvent);
      stat = 'handle: $response';
      mess = 'capture open success';
      setState(() {
        _isOpen = true;
      });
    } on CaptureException catch (exception) {
      stat = exception.code.toString();
      mess = exception.message;
      method = exception.method;
      details = exception.details;
      if (Platform.isAndroid) {
        if (details != null) {
          details = details + " Is Socket Mobile Companion app installed?";
        } else {
          details = "Is Socket Mobile Companion app installed?";
        }
      }
    }
    _updateVals(stat, mess, method, details);
  }

  Future _openDeviceHelper(
      Capture deviceCapture, CaptureEvent e, bool isManager, int handle) async {
    // deviceArrival checks that a device is available
    // openDevice allows the device to be used (for decodedData)
    List<DeviceInfo> arr = _devices;

    DeviceInfo _deviceInfo = e.deviceInfo;

    logger.log('Device ${isManager ? 'Manager' : ''} Arrival =>',
        '${_deviceInfo.name} (${_deviceInfo.guid})');

    try {
      await deviceCapture.openDevice(_deviceInfo.guid, _capture);
      if (!isManager) {
        if (!arr.contains(_deviceInfo)) {
          if (SocketCamTypes.contains(_deviceInfo.type)) {
            if (!mounted) return;
            setState(() {
              _socketcamDevice = deviceCapture;
            });
          } else {
            if (!mounted) return;
            setState(() {
              _deviceCapture = deviceCapture;
            });
          }
          arr.add(_deviceInfo);
          if (!mounted) return;
          setState(() {
            _devices = arr;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _bleDeviceManagerCapture = deviceCapture;
        });
        _getFavorite(deviceCapture);
      }
      _updateVals('Device${isManager ? ' Manager' : ''} Opened',
          'Successfully added "${_deviceInfo.name}"');
    } on CaptureException catch (exception) {
      _updateVals(exception.code.toString(), exception.message,
          exception.method, exception.details);
    }
  }

  Future<void> _closeDeviceHelper(e, handle, bool isManager) async {
    String guid = e.value["guid"];
    String name = e.value["name"];
    logger.log(
        'Device ${isManager ? 'Manager' : ''} Removal =>', name + ' ($guid)');

    try {
      dynamic res = await _deviceCapture!.close();
      if (res == 0) {
        List<DeviceInfo> arr = _devices;
        arr.removeWhere((element) => element.guid == guid);
        if (!mounted) return;
        setState(() {
          _devices = arr;
          _deviceCapture = null;
          _isOpen = false;
        });
        if (_bleDeviceManagerCapture != null &&
            guid == _bleDeviceManagerCapture!.guid) {
          if (!mounted) return;
          setState(() {
            _bleDeviceManagerCapture = null;
          });
          (null);
        } else {
          if (!mounted) return;
          setState(() {
            _deviceCapture = null;
          });
        }
      }
      _updateVals('Device ${isManager ? 'Manager' : ''} Closed',
          'Successfully removed "$name"');
    } on CaptureException catch (exception) {
      _updateVals('${exception.code}', 'Unable to remove "$name"',
          exception.method, exception.details);
    }
  }

  _onCaptureEvent(e, handle) {
    if (e == null) {
      return;
    } else if (e.runtimeType == CaptureException) {
      _updateVals("${e.code}", e.message, e.method, e.details);
      return;
    }

    logger.log('onCaptureEvent from: ', '$handle');

    switch (e.id) {
      case CaptureEventIds.deviceArrival:
        Capture deviceCapture = Capture(logger);
        _openDeviceHelper(deviceCapture, e, false, handle);
        break;
      case CaptureEventIds.deviceRemoval:
        if (_deviceCapture != null) {
          _closeDeviceHelper(e, handle, false);
        }
        break;

      case CaptureEventIds.decodedData:
        setStatus('Decoded Data', 'Successfully decoded data!');
        List<DecodedData> _myList = [..._decodedDataList];
        Map<String, dynamic> jsonMap = e.value as Map<String, dynamic>;
        DecodedData decoded = DecodedData.fromJson(jsonMap);
        _myList.add(decoded);
        if (!mounted) return;
        setState(() {
          _decodedDataList = _myList;
          _handleDecodedData(e.value);
        });
        break;
      case CaptureEventIds.deviceManagerArrival:
        Capture bleDeviceManagerCapture = Capture(logger);
        _openDeviceHelper(bleDeviceManagerCapture, e, true, handle);
        break;
      case CaptureEventIds.deviceManagerRemoval:
        if (_deviceCapture != null) {
          _closeDeviceHelper(e, handle, true);
        }
        break;
    }
  }

  void _handleDecodedData(dynamic data) {
    try {
      Map<String, dynamic> jsonMap = data as Map<String, dynamic>;
      DecodedData decodedData = DecodedData.fromJson(jsonMap);

      if (!mounted) return;
      setState(() {
        _decodedDataList.add(decodedData); // Update local list
        context
            .read<ScannedDataCubit>()
            .addDecodedData(decodedData); // Update Cubit
      });
    } catch (error) {
      print("Error handling decoded data: $error");
    }
  }

  Future<void> _closeCapture() async {
    try {
      final res = await _capture!.close();
      setStatus("Success in closing Capture: $res");
      if (!mounted) return;
      setState(() {
        _isOpen = false;
        _devices = [];
        _useSocketCam = false;
      });
    } on CaptureException catch (exception) {
      int code = exception.code;
      String messge = exception.message;
      setStatus("failed to close capture: $code: $messge");
    }
  }

  void setStatus(String stat, [String? msg]) {
    if (!mounted) return;
    setState(() {
      _status = stat;
      _message = msg ?? _message;
    });
  }

  void _setUseSocketCam(bool val) {
    if (!mounted) return;
    setState(() {
      _useSocketCam = val;
    });
  }

  void _clearAllScans() {
    if (!mounted) return;
    setState(() {
      context.read<ScannedDataCubit>().clearAllData();

      _decodedDataList = [];
    });
  }

  Future<void> _getFavorite(Capture dev) async {
    CaptureProperty property = const CaptureProperty(
      id: CapturePropertyIds.favorite,
      type: CapturePropertyTypes.none,
      value: {},
    );

    String stat = "retrieving BLE Device Manager favorite...";
    setStatus(stat);
    try {
      var favorite = await dev.getProperty(property);
      logger.log(favorite.value, 'GET Favorite');
      if (favorite.value.length == 0) {
        setFavorite(dev);
      } else {
        stat = "Favorite found! Try using an NFC Reader.";
      }
    } on CaptureException catch (exception) {
      var code = exception.code.toString();
      var message = exception.message;
      logger.log(code, message);
      stat = 'failed to get favorite: $code : $message';
    }
    setStatus(stat);
  }

  Future<void> setFavorite(Capture dev) async {
    CaptureProperty property = const CaptureProperty(
      id: CapturePropertyIds.favorite,
      type: CapturePropertyTypes.string,
      value: '*',
    );

    String stat = 'successfully set favorite for BLE Device Manager';

    try {
      var data = await dev.setProperty(property);
      logger.log(data.value.toString(), 'SET Favorite');
    } on CaptureException catch (exception) {
      var code = exception.code.toString();
      var message = exception.message;
      logger.log(code, message);
      stat = 'failed to set favorite: $code : $message';
    }
    setStatus(stat);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[
              const Text('Status: '),
              Text(_status, style: Theme.of(context).textTheme.bodyLarge),
            ]),
            // Text(_currentscan != null
            //     ? 'Scan from ${_currentscan!.value.name}: ' +
            //         _currentscan!.value.data.toString()
            //     : 'No Data'),
            Row(children: <Widget>[
              const Text('Message: '),
              Flexible(
                child: Text(_message,
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
            ]),

            StreamBuilder<List<DecodedData>>(
              stream: context.read<ScannedDataCubit>().decodedDataStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    _isLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No scans yet.'));
                } else {
                  final decodedDataList = snapshot.data!;
                  return Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: ListView.builder(
                      itemCount: decodedDataList.length,
                      itemBuilder: (context, index) {
                        final items = decodedDataList[index];
                        final item = utf8.decode(items.data);
                        return ListTile(
                          title: Text(items.name),
                          subtitle: Text(item),
                        );
                        // return Text(
                        //     "- ${item.name.toUpperCase()} (${item.data.length}) ${item.data}");
                      },
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _capture?.close();
    _deviceCapture?.close();
    _bleDeviceManagerCapture?.close();
    _socketcamDevice?.close();
    super.dispose();
  }
}
