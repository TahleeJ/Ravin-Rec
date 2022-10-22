import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_fft/flutter_fft.dart';
import 'package:noise_meter/noise_meter.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_fft/flutter_fft.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Bessie FC Rave App",
      home: Application(),
    );
  }
}

class Application extends StatefulWidget {
  @override
  ApplicationState createState() => ApplicationState();
}

class ApplicationState extends State<Application> {
  double? frequency;
  String? note;
  int? octave;
  bool? isRecording;

  FlutterFft flutterFft = new FlutterFft();

  final double minMicDb = 45.0;
  final double maxMicDb = 95+.0;

  final int maxVibe = 255;
  int destVibe = 0;
  int currVibe = 0;

  double widthMin = 5.0;
  double widthMax = 300.0;
  double newWidth = 0.0;

  final double heightMin = 10.0;
  double heightMax = 300.0;
  double newHeight = 5.0;

  double minValue = 0.2;
  double maxValue = 1.0;
  double newValue = 0.0;

  HSVColor hsvColor = HSVColor.fromAHSV(1.0, 217.0, 1.0, 1.0);
  final double violetHue = 255.0;
  final double minRedHue = 0.0;
  final double magentaHue = 255.1;
  final double maxRedHue = 360.0;
  double newHue = 0.0;

  double minFreq = 155.0;
  double maxFreq = 4978.0;
  double freqScale = 1.0;
  double splitFreq = 0.0;

  double minDb = 1000.0;
  double maxDb = 0.0;
  double currDb = 0.0;

  double auxDb = 0.0;
  double auxDbScale = 0.0;

  _updateHeightAndWidthBasedOnVolume() async {
    newHeight = _newValueInMappedRange(currDb, minMicDb, maxMicDb, heightMin, heightMax);
    newWidth = _newValueInMappedRange(currDb, minMicDb, maxMicDb, widthMin, widthMax);
    newValue = _newValueInMappedRange(currDb, minMicDb, maxMicDb, minValue, maxValue);
    hsvColor = hsvColor.withValue(newValue);
  }

  double _newValueInMappedRange(double curr_range1, double min_range1, double max_range1, double min_range2, double max_range2)  {
    double curr_range2 = 0.0;
    curr_range1 >= max_range1 ? curr_range2 = max_range2 : curr_range2 = (curr_range1 - min_range1) * (max_range2 - min_range2)/(max_range1 - min_range1) + min_range2;
    curr_range1 <= min_range1 ? curr_range2 = min_range2 : curr_range2 = curr_range2;
    return curr_range2;
  }

  _initialize() async {
    start();
    maxDb = 0.0;
    minDb = 1000.0;

    print("Starting recorder...");
    // print("Before");
    // bool hasPermission = await flutterFft.checkPermission();
    // print("After: " + hasPermission.toString());

    // Keep asking for mic permission until accepted
    while (!(await flutterFft.checkPermission())) {
      flutterFft.requestPermission();
      // IF DENY QUIT PROGRAM
    }

    // await flutterFft.checkPermissions();
    await flutterFft.startRecorder();
    print("Recorder started...");
    setState(() => isRecording = flutterFft.getIsRecording);

    flutterFft.onRecorderStateChanged.listen(
            (data) => {
          setState(
                () => {
              frequency = data[1] as double,
            },
          ),
          // print(frequency.toString()),
          if (frequency! > maxFreq) {
            frequency = maxFreq,
          },
          if (frequency! < minFreq) {
            frequency = minFreq,
          },
          freqScale = violetHue / maxRedHue,
          splitFreq = ((maxFreq * freqScale) - minFreq + 1) + minFreq,
          // print("split is " + splitFreq.toString()),
          // print("at splitF, should be 360: " + (violetHue + maxRedHue - _newValueInMappedRange(splitFreq, splitFreq, maxFreq, magentaHue, maxRedHue)).toString()),
          // print("at maxF, should be 255: " + (violetHue + maxRedHue - _newValueInMappedRange(maxFreq +1, splitFreq, maxFreq, magentaHue, maxRedHue)).toString()),
          if (frequency! >= splitFreq) {
            newHue = violetHue + maxRedHue - _newValueInMappedRange(frequency!, splitFreq, maxFreq, magentaHue, maxRedHue),
          } else {
            newHue = violetHue - _newValueInMappedRange(frequency!, minFreq, splitFreq - .1, minRedHue, violetHue),
          },
          // newHue = violetHue - _newValueInMappedRange(frequency!, minFreq, maxFreq, minRedHue, violetHue),
          hsvColor = hsvColor.withHue(newHue),
          // print(newHue),
        },
        onError: (err) {
          print("Error: $err");
        },
        onDone: () => {print("Isdone")});
  }

  bool _isRecording = false;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  late NoiseMeter _noiseMeter;

  @override
  void initState() {
    _noiseMeter = new NoiseMeter(onError);
    isRecording = flutterFft.getIsRecording;
    frequency = flutterFft.getFrequency;
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    super.dispose();
  }

  void onData(NoiseReading noiseReading) {
    this.setState(() {
      if (!this._isRecording) {
        this._isRecording = true;
      }
    });

    currDb = noiseReading.meanDecibel;
  }

  void onError(Object error) {
    print(error.toString());
    _isRecording = false;
  }

  void start() async {
    try {
      _noiseSubscription = _noiseMeter.noiseStream.listen(onData);

      Timer.periodic(const Duration(seconds: 1), (timer) async {
          auxDb = currDb - minMicDb;
          auxDbScale = auxDb / (maxMicDb - minMicDb);
          _updateHeightAndWidthBasedOnVolume();
          destVibe = (maxVibe * auxDbScale).floor();

          Vibration.vibrate(pattern: [0, 200, 0, 200, 0, 200], intensities: [0, (destVibe / 4).floor(), 0, (destVibe / 2).floor(), 0, destVibe]);
      });
    } catch (err) {
      print(err);
    }
  }

  void stop() async {
    try {
      if (_noiseSubscription != null) {
        _noiseSubscription!.cancel();
        _noiseSubscription = null;
      }
      this.setState(() {
        this._isRecording = false;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  void _reset() {
    _initialize();
  }

  void buildSettings(BuildContext context) {
    Widget closeButton = TextButton(
      child: Text("Close", style: TextStyle(fontSize: 16)),
      onPressed: () {
        closePopup(context);
      },
    );

    AlertDialog settingsAlert = AlertDialog(
      title: const Text("Settings"),
      content: Container(
            height: MediaQuery.of(context).size.height * (1/3),
            width: MediaQuery.of(context).size.width * (2/3),
            child: Center(
              child: Column(
                children: [
                  Text("your settings here!", style: TextStyle(fontSize: 15))
                ],
              )
        )
      ),
      actions: [
        closeButton
      ],
    );

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return settingsAlert;
        }
    );
  }

  Future<void> closePopup(BuildContext context) async {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {

    widthMax = MediaQuery
        .of(context)
        .size
        .width;
    heightMax = MediaQuery
        .of(context)
        .size
        .height;
    
    return MaterialApp(
        title: "Simple flutter fft example",
        theme: ThemeData.dark(),
        color: Colors.blue,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onDoubleTap: () => buildSettings(context),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: newWidth,
                    height: newHeight,
                    decoration: BoxDecoration(
                      color: hsvColor.toColor(),
                      shape: BoxShape.rectangle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
    );
  }
  }