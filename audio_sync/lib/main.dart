import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_fft/flutter_fft.dart';
import 'package:noise_meter/noise_meter.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_fft/flutter_fft.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

final double minMicDb = 45.0;
final double maxMicDb = 95.0;
final double systemMinFreq = 155.0;
final double systemMaxFreq = 4978.0;
bool firstPass = false;

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
  // Frequency readings
  FlutterFft flutterFft = FlutterFft();
  double? frequency;
  bool? isRecording;

  // Volume readings
  bool _isRecording = false;
  late NoiseMeter _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  // App foreground/background readings
  late StreamSubscription<FGBGType> subscription;

  // Vibrations toggle value
  bool _vibrationsActive = true;

  // Min/max accepted decibel reading
  double rangeMinDb = minMicDb;
  double rangeMaxDb = maxMicDb;

  // Current volume reading
  double currDb = 0.0;

  // Read volume shifted towards 0 using the minimum accepted decibel reading
  double acceptedDb = 0.0;

  // Read volume shifted on a 0.0-1.0 scale using the min/max accepted decibel readings
  double acceptedDbScale = 0.0;

  // Max accepted vibration intensity
  final int maxVibe = 255;

  // Target vibration intensity
  int destVibe = 0;

  // Min/max accepted mic frequency
  double userMinFreq = 155.0;
  double userMaxFreq = 4978.0;
  double freqScale = 1.0;

  // The frequency at which high/low color tones are set
  double splitFreq = 0.0;

  // Shape's width resizing
  final double widthMin = 5.0;
  double widthMax = 300.0;
  double newWidth = 0.0;

  // Shape's height resizing
  final double heightMin = 10.0;
  double heightMax = 300.0;
  double newHeight = 5.0;

  // Shape's HSVColor value
  double minValue = 0.2;
  double maxValue = 1.0;
  double newValue = 0.0;

  // Shape's HSV target
  HSVColor hsvColor = HSVColor.fromAHSV(1.0, 217.0, 1.0, 1.0);

  // Shape's HSV hue
  final double violetHue = 255.0;
  final double minRedHue = 0.0;
  final double magentaHue = 255.1;
  final double maxRedHue = 360.0;
  double newHue = 0.0;

  bool _appInFocus = true;
  late SwitchWidget vibrationsSwitch;
  late RangeSliderWidget volumeSlider;
  late RangeSliderWidget frequencyDoubleSlider;

  _updateBasedOnVolume() async {
    newHeight = _newValueInMappedRange(currDb, rangeMinDb, rangeMaxDb, heightMin, heightMax);
    newWidth = _newValueInMappedRange(currDb, rangeMinDb, rangeMaxDb, widthMin, widthMax);
    newValue = _newValueInMappedRange(currDb, rangeMinDb, rangeMaxDb, minValue, maxValue);
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

    // Keep asking for mic permission until accepted
    while (!(await flutterFft.checkPermission())) {
      flutterFft.requestPermission();
      // IF DENY QUIT PROGRAM
    }

    await flutterFft.startRecorder();
    setState(() => isRecording = flutterFft.getIsRecording);

    flutterFft.onRecorderStateChanged.listen(
            (data) => {
          setState(
                () => {
              frequency = data[1] as double,
            },
          ),
          // print(frequency.toString()),
          if (frequency! > userMaxFreq) {
            frequency = userMaxFreq,
          },
          if (frequency! < userMinFreq) {
            frequency = userMinFreq,
          },
          freqScale = violetHue / maxRedHue,
          splitFreq = ((userMaxFreq * freqScale) - userMinFreq + 1) + userMinFreq,
          if (frequency! >= splitFreq) {
            newHue = violetHue + maxRedHue - _newValueInMappedRange(frequency!, splitFreq, userMaxFreq, magentaHue, maxRedHue),
          } else {
            newHue = violetHue - _newValueInMappedRange(frequency!, userMinFreq, splitFreq - .1, minRedHue, violetHue),
          },
          // newHue = violetHue - _newValueInMappedRange(frequency!, userMinFreq, userMaxFreq, minRedHue, violetHue),
          hsvColor = hsvColor.withHue(newHue),
          // print(newHue),
        },
        onError: (err) {
          print("Error: $err");
        },
        onDone: () => {print("Done")});
  }

  @override
  void initState() {
    _noiseMeter = new NoiseMeter(onError);
    isRecording = flutterFft.getIsRecording;
    frequency = flutterFft.getFrequency;
    subscription = FGBGEvents.stream.listen((event) {
      _appInFocus = event == FGBGType.foreground;
    });

    vibrationsSwitch = SwitchWidget();
    if (firstPass) {
        volumeSlider = RangeSliderWidget(minMicDb, maxMicDb, minMicDb, maxMicDb, 0.0, 0.0, (maxMicDb - minMicDb - 1).floor() as int, firstPass);
        frequencyDoubleSlider = RangeSliderWidget(220.0, 880.0, systemMinFreq, systemMaxFreq, 0.0, 0.0, (systemMaxFreq - systemMinFreq - 1).floor() as int, firstPass);
        firstPass = !firstPass;
    } else {
      volumeSlider = RangeSliderWidget(minMicDb, maxMicDb, minMicDb, maxMicDb, rangeMinDb, rangeMaxDb, (maxMicDb - minMicDb - 1).floor() as int, firstPass);
      frequencyDoubleSlider = RangeSliderWidget(220.0, 880.0, systemMinFreq, systemMaxFreq, userMinFreq, userMaxFreq, (systemMaxFreq - systemMinFreq - 1).floor() as int, firstPass);
    }

    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _noiseSubscription?.cancel();
    subscription.cancel();
    super.dispose();
  }

  void onData(NoiseReading noiseReading) {
    setState(() {
      if (!_isRecording) {
        _isRecording = true;
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
          acceptedDb = currDb - rangeMinDb;
          acceptedDbScale = acceptedDb / (rangeMaxDb - rangeMinDb);
          _updateBasedOnVolume();
          destVibe = (maxVibe * acceptedDbScale).floor();

          if (_appInFocus && _vibrationsActive) {
            Vibration.vibrate(pattern: [0, 200, 0, 200, 0, 200], intensities: [0, (destVibe / 4).floor(), 0, (destVibe / 2).floor(), 0, destVibe]);
          }
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
      setState(() {
        _isRecording = false;
      });
    } catch (err) {
      print('stop recorder error: $err');
    }
  }

  void buildSettings(BuildContext context) {
    Widget closeButton = TextButton(
      child: const Text("Close", style: TextStyle(fontSize: 16)),
      onPressed: () {
        closePopup(context);
      },
    );

    AlertDialog settingsAlert = AlertDialog(
      title: const Text("Settings"),
      content: SizedBox(
        height: MediaQuery.of(context).size.height * (1/3),
        width: MediaQuery.of(context).size.width * (2/3),
        child: Center(
          child: Column(
            children: [
              Row(
                children: [
                  const Text("Toggle Vibrations"),
                  const Spacer(),
                  vibrationsSwitch
                ],
              ),
              Column(
                children: [
                  const Text("Adjust your volume range"),
                  volumeSlider
                ],
              ),
              Column(
                children: [
                  const Text("Adjust your frequency/pitch range"),
                  frequencyDoubleSlider,
                ],
              )
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

    _vibrationsActive = vibrationsSwitch.isActive;
    rangeMinDb = volumeSlider.setMin;
    rangeMaxDb = volumeSlider.setMax;
    userMinFreq = frequencyDoubleSlider.absMin;
    userMaxFreq = frequencyDoubleSlider.absMax;


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

class SwitchWidget extends StatefulWidget {
  bool isActive = true;

  SwitchWidget({super.key});

  @override
  State<SwitchWidget> createState() => _SwitchWidgetState();
}

class _SwitchWidgetState extends State<SwitchWidget> {
  @override
  Widget build(BuildContext context) {
    return Switch(
      // This bool value toggles the switch.
      value: widget.isActive,
      activeColor: Colors.red,
      onChanged: (bool value) {
        // This is called when the user toggles the switch.
        setState(() {
          widget.isActive = value;
        });
      },
    );
  }
}

class RangeSliderWidget extends StatefulWidget {
  // int rangeMin = 45;
  // final int rangeMax = 90;
  double initMin;
  double initMax;
  double absMin;
  double absMax;
  double setMin;
  double setMax;
  int divisions;
  bool firstPass;

  RangeSliderWidget(
      this.initMin,
      this.initMax,
      this.absMin,
      this.absMax,
      this.setMin,
      this.setMax,
      this.divisions,
      this.firstPass,
      {super.key}
      );

  @override
  State<RangeSliderWidget> createState() => _RangeSliderWidgetState();
}

class _RangeSliderWidgetState extends State<RangeSliderWidget> {
  @override
  Widget build(BuildContext context) {
    RangeValues _currentRangeValues;
    if (firstPass) {
      _currentRangeValues = RangeValues(widget.absMin, widget.absMax);
    } else {
      _currentRangeValues = RangeValues(widget.setMin, widget.setMax);
    }

    return RangeSlider(
      values: _currentRangeValues,
      min: widget.absMin,
      max: widget.absMax,
      divisions: widget.divisions,
      labels: RangeLabels(
        _currentRangeValues.start.round().toString(),
        _currentRangeValues.end.round().toString(),
      ),
      onChanged: (RangeValues values) {
        setState(() {
          _currentRangeValues = values;
          widget.setMin = values.start;
          widget.setMax = values.end;
        });
      },
    );
  }
}
