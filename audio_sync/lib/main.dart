import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_fft/flutter_fft.dart';
import 'package:noise_meter/noise_meter.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_fft/flutter_fft.dart';

void main() => runApp(Application());

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
  final double maxMicDb = 90.0;
  final int maxVibe = 255;

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

    // if ((await Vibration.hasVibrator())!) {}

    // if ((await Vibration.hasAmplitudeControl())!) {
    //   while (true) {
    //     int i = 1;
    //     for (; i < 26; i++) {
    //       print(i*10);
    //       Vibration.vibrate(duration: 2000, amplitude: i*10);
    //       await Future.delayed(const Duration(seconds: 2));
    //     }
    //   }
    // }

    // double dbScale = dbVal / 150;
    // double vibeVal = 255 * dbScale;

    flutterFft.onRecorderStateChanged.listen(
            (data) => {
          // print("Changed state, received: $data"),
          setState(
                () => {
              // frequency = data[1] as double,
              note = data[2] as String,
              octave = data[5] as int,
            },
          ),
          // flutterFft.setNote = note!,
          // flutterFft.setFrequency = frequency!,
          // flutterFft.setOctave = octave!,
          // print(frequency.toString())
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
    super.initState();
    _noiseMeter = new NoiseMeter(onError);
    isRecording = flutterFft.getIsRecording;
    frequency = flutterFft.getFrequency;
    note = flutterFft.getNote;
    octave = flutterFft.getOctave;
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
    // frequency = noiseReading.meanDecibel;
    maxDb = max(maxDb, noiseReading.maxDecibel);
    minDb = min(minDb, noiseReading.meanDecibel);
    meanDb = noiseReading.meanDecibel;
    currDb = noiseReading.meanDecibel;
    // print(currDb);
    //
    // auxDb = meanDb - minMicDb;
    // auxDbScale = auxDb / (maxDb - minMicDb);
    // print(meanDb.toString() + "," + (meanDb - minMicDb).toString() + ", " + auxDbScale.toString() + ", " + (maxVibe * auxDbScale).floor().toString());
    //
    // destVibe = (maxVibe * auxDbScale).floor();
    //
    // Vibration.vibrate(pattern: [0, 120], intensities: [currVibe, destVibe]);

    // print(noiseReading.toString());
  }

  void onError(Object error) {
    print(error.toString());
    _isRecording = false;
  }

  void start() async {
    try {
      _noiseSubscription = _noiseMeter.noiseStream.listen(onData);

      Timer.periodic(const Duration(seconds: 3), (timer) async {
        print("enter");
        // if (this._isRecording) {
        // print(currDb);
          auxDb = currDb - minMicDb;
          auxDbScale = auxDb / (maxMicDb - minMicDb);
          // print(meanDb.toString() + "," + (meanDb - minMicDb).toString() + ", " + auxDbScale.toString() + ", " + (maxVibe * auxDbScale).floor().toString());

          destVibe = (maxVibe * auxDbScale).floor();
          // print(destVibe);

          // Vibration.vibrate(pattern: [0, 1000, 0, 1000, 0, 1000], intensities: [destVibe, (destVibe / 2).floor(), (destVibe / 4).floor()]);
        print("first vibe");
          Vibration.vibrate(duration: 1000, amplitude: destVibe);
          await Future.delayed(Duration(milliseconds: 1000));
          print("second vibe");
          Vibration.vibrate(duration: 1000, amplitude: (destVibe / 2).floor());
          await Future.delayed(Duration(milliseconds: 1000));
        print("third vibe");
          Vibration.vibrate(duration: 1000, amplitude: (destVibe / 4).floor());
          await Future.delayed(Duration(milliseconds: 1000));
        // }
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
    // dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: "Simple flutter fft example",
        theme: ThemeData.dark(),
        color: Colors.blue,
        home: Scaffold(
          backgroundColor: Colors.purple,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isRecording!
                    ? Text("Max: ${maxDb!.toString()}",
                    style: TextStyle(fontSize: 30))
                    : Text("Not Recording", style: TextStyle(fontSize: 35)),
                isRecording!
                    ? Text("Min: ${note!},${minDb!.toString()}",
                    style: TextStyle(fontSize: 30))
                    : Text("Not Recording", style: TextStyle(fontSize: 35)),
                isRecording!
                    ? Text(
                    "Mean: ${meanDb.toString()}",
                    style: TextStyle(fontSize: 30))
                    : Text("Not Recording", style: TextStyle(fontSize: 35)),
                IconButton(
                  iconSize: 96.0,
                  icon: Icon(Icons.mic),
                  onPressed: _reset,
                ),
              ],
            ),
          ),
        ));
  }
}