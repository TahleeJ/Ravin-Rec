import 'dart:math';

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
  final double maxMicDb = 75.0;
  final int maxVibe = 255;
  final double widthMin = 5.0;
  double widthMax = 300.0;
  double newWidth = 5.0;
  final double heightMin = 10.0;
  double heightMax = 300.0;
  double newHeight = 5.0;
  double newValue = 0.0;
  double newHue = 0;
  double minValue = 0.2;
  double maxValue = 1.0;
  HSVColor hsvColor = HSVColor.fromAHSV(1.0, 217.0, 1.0, 1.0);


  final int redFreq = 750;
  final int yellowFreq = 1400;
  final int greenFreq = 2050;
  final int cyanFreq = 2700;
  final int blueFreq = 3350;
  final int magentaFreq = 4000;
  int r = 255;
  int g = 255;
  int b = 255;
  double hue = 0.0;

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
              note = data[2] as String,
              octave = data[5] as int,
            },
          ),
              if (frequency! < redFreq) {
                // r = ((frequency! / redFreq) * 255).floor(),
                // g = b = 0,
                hue = (frequency! / redFreq) * 60,
                // print(((frequency! / redFreq) * 255).floor().toString() + " (" + r.toString() + ", " + g.toString() + ", " + b.toString()
                print("red")
              } else if (frequency! < yellowFreq) {
                // r = 255,
                // g =  ((frequency! / yellowFreq) * 255).floor(),
                // b = 0,
                hue = (frequency! / yellowFreq) * 60 + 61,
                print("yellow")
              } else if (frequency! < greenFreq) {
                // r = 0,
                // g =  ((frequency! / greenFreq) * 255).floor(),
                // b = 0,
                hue = (frequency! / greenFreq) * 60 + 121,
                print("green")
              } else if (frequency! < cyanFreq) {
                // r = 0,
                // g = 255,
                // b = ((frequency! / cyanFreq) * 255).floor(),
                hue = (frequency! / cyanFreq) * 60 + 181,
                print("cyan")
              } else if (frequency! < blueFreq) {
                // r = g = 0,
                // b = ((frequency! / blueFreq) * 255).floor(),
                hue = (frequency! / blueFreq) * 60 + 241,
                print("blue")
              } else {
                // r = 255,
                // g = 0,
                // b = ((frequency! / magentaFreq) * 255).floor(),
                hue = (frequency! / magentaFreq) * 60 + 301,
                print("magenta")
              },
              // print(frequency.toString()),
              hsvColor = hsvColor.withHue(hue),
              print(hue)
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
    note = flutterFft.getNote;
    octave = flutterFft.getOctave;
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    super.dispose();
  }

  double currDb = 0.0;
  double maxDb = 0.0;
  double minDb = 1000.0;
  double meanDb = 0.0;
  double auxDb = 0.0;
  double auxDbScale = 0.0;
  int currVibe = 0;
  int destVibe = 0;

  void onData(NoiseReading noiseReading) {
    this.setState(() {
      if (!this._isRecording) {
        this._isRecording = true;
      }
    });

    // maxDb = max(maxDb, noiseReading.maxDecibel);
    // minDb = min(minDb, noiseReading.meanDecibel);
    meanDb = noiseReading.meanDecibel;
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
          // print(meanDb.toString() + "," + (meanDb - minMicDb).toString() + ", " + auxDbScale.toString() + ", " + (maxVibe * auxDbScale).floor().toString());
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

  @override
  Widget build(BuildContext context) {
    widthMax = MediaQuery.of(context).size.width;
    heightMax = MediaQuery.of(context).size.height;
    return MaterialApp(
        title: "Simple flutter fft example",
        theme: ThemeData.dark(),
        color: Colors.blue,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: newWidth,
                  height: newHeight,
                  decoration: new BoxDecoration(
                    color: hsvColor.toColor(),
                    shape: BoxShape.rectangle,
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}