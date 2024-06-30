import 'dart:io';

import 'package:captur/CapturedSdkWidget.dart';
import 'package:captur/ScannedDataCubit.dart';
import 'package:flutter/material.dart';
import 'package:capturesdk_flutter/capturesdk.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

AppInfo appInfo = AppInfo(
  appIdAndroid: '',
  appKeyAndroid: '',
  appIdIos: 'ios:net.captainchef.pos',
  appKeyIos: 'MCwCFCCrwQgbDjJX65wuat7YB6JdB5lSAhQYnEpoP4H+ntutV9oJkwmLe5spdQ==',
  developerId: '6f9387c0-440d-ef11-9f89-0022480bffec',
);

class AppInitializer {
  static Future init() async {
    WidgetsFlutterBinding.ensureInitialized();

    await EasyLocalization.ensureInitialized();
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppInitializer.init();
  if (Platform.isIOS) {
    await _requestPermissions();
  }
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'EG')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: MultiProvider(
        providers: [
          Provider<AppInfo>.value(value: appInfo),
          Provider(create: (_) => ScannedDataCubit()),
        ],
        child: MyApp(),
      ),
    ),
  );
}

Future<void> _requestPermissions() async {
  // Request Bluetooth permissions
  PermissionStatus bluetoothStatus = await Permission.bluetooth.request();
  if (bluetoothStatus.isDenied) {
    print(
        "Bluetooth permission denied. The app requires Bluetooth access to function properly. Please enable it in settings.");
  } else if (bluetoothStatus.isPermanentlyDenied) {
    print(
        "Bluetooth permission is permanently denied. Please enable it manually in the settings.");
    openAppSettings();
  }

  // Request location permissions
  PermissionStatus locationStatus = await Permission.location.request();
  if (locationStatus.isDenied) {
    print(
        "Location permission denied. The app requires location access to function properly. Please enable it in settings.");
  } else if (locationStatus.isPermanentlyDenied) {
    print(
        "Location permission is permanently denied. Please enable it manually in the settings.");
    openAppSettings();
  }

  // Request camera permissions
  PermissionStatus cameraStatus = await Permission.camera.request();
  if (cameraStatus.isDenied) {
    print(
        "Camera permission denied. The app requires camera access to function properly. Please enable it in settings.");
  } else if (cameraStatus.isPermanentlyDenied) {
    print(
        "Camera permission is permanently denied. Please enable it manually in the settings.");
    openAppSettings();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Capture SDK Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CapturedSdkWidget(title: 'Flutter Capture SDK Demo Homepage'),
    );
  }
}

//
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
