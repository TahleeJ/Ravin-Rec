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
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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

final double minMicDb = 45.0;
final double maxMicDb = 95.0;

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
  bool _appInFocus = true;

  // Toggles in settings
  late SwitchWidget vibrationsSwitch;
  late SwitchWidget multiColorSwitch;
  late SwitchWidget resizingSwitch;

  // Toggle values in settings
  bool _vibrationsActive = true;
  bool _multiColorActive = true;
  bool _resizingActive = true;

  // Sliders in settings
  late RangeSliderWidget volumeSlider;

  late BlockPickerWidget blockPicker;

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
  double minFreq = 155.0;
  double maxFreq = 4978.0;
  double freqScale = 1.0;

  // The frequency at which high/low color tones are set
  double splitFreq = 0.0;

  // Shape's width resizing
  final double widthMin = 5.0;
  double widthMax = 300.0;
  double newWidth = 5.0;

  // Shape's height resizing
  final double heightMin = 10.0;
  double heightMax = 300.0;
  double newHeight = 5.0;

  // Shape's HSV value
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

  _updateHeightAndWidthBasedOnVolume() async {
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

              if (_multiColorActive) {
                hsvColor = hsvColor.withHue(newHue)
              } else {
                hsvColor = HSVColor.fromColor(currentColor)
              }

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

    vibrationsSwitch = SwitchWidget(isActive: _vibrationsActive);
    multiColorSwitch = SwitchWidget(isActive: _multiColorActive);
    resizingSwitch = SwitchWidget(isActive: _resizingActive);
    volumeSlider = RangeSliderWidget();
    blockPicker = BlockPickerWidget(pickerColor: pickerColor, currentColor: currentColor);

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

      Timer.periodic(const Duration(seconds: 1), (timer) {
          acceptedDb = currDb - rangeMinDb;
          acceptedDbScale = acceptedDb / (rangeMaxDb - rangeMinDb);

          destVibe = (maxVibe * acceptedDbScale).floor();

          if (_appInFocus && _vibrationsActive) {
            Vibration.vibrate(pattern: [0, 200, 0, 200, 0, 200], intensities: [0, (destVibe / 4).floor(), 0, (destVibe / 2).floor(), 0, destVibe]);
          }
      });

      Timer.periodic(const Duration(milliseconds: 5), (timer) {
        if (_resizingActive) {
          _updateHeightAndWidthBasedOnVolume();
        } else {
          newWidth = widthMax;
          newHeight = heightMax;
        }
      });

      if (_resizingActive) {
        _updateHeightAndWidthBasedOnVolume();
      } else {
        newWidth = widthMax;
        newHeight = heightMax;
      }
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

  // create some values
  Color pickerColor = Color(0xff443a49);
  Color currentColor = Color(0xff443a49);

// ValueChanged<Color> callback
//   void changeColor(Color color) {
//     setState(() => pickerColor = color);
//   }

  Widget buildToggle(SwitchWidget toggle, String subject) {
    return Row(
      children: [
        Text("Toggle $subject"),
        const Spacer(),
        toggle
      ],
    );
  }

  void buildSettings(BuildContext context) {
    Widget closeButton = TextButton(
      child: const Text("Close", style: TextStyle(fontSize: 16)),
      onPressed: () {
        closePopup(context);
      },
    );

    AlertDialog settingsAlert = AlertDialog(
      title: const Text("Settings", style: TextStyle(fontSize: 24)),
      content: SizedBox(
        height: MediaQuery.of(context).size.height * (1/2),
        width: MediaQuery.of(context).size.width,
        child: Center(
          child: Scrollbar(
            thumbVisibility: true,
           thickness: 7.5,
           radius: Radius.circular(5.0),
           interactive: true,

           child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(right: 15.0),
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildToggle(vibrationsSwitch, "vibrations"),
              buildToggle(multiColorSwitch, "multi-color"),
              buildToggle(resizingSwitch, "resizing"),
              const Padding(
                padding: EdgeInsets.only(top: 10.0, bottom: 10.0, right: 30.0),
                child: Divider(
                    height: 2.0,
                    thickness: 3.5,
                    indent: 25.0
                )
              ),
              Column(
                children: [
                  const Text("Adjust your volume range"),
                  Row(
                    children: [
                      const Text("45", style: TextStyle(fontSize: 18)),
                      const Spacer(),
                      volumeSlider,
                      const Spacer(),
                      const Text("90", style: TextStyle(fontSize: 18))
                    ]
                  )
                ],
              ),
              const Padding(
                  padding: EdgeInsets.only(top: 10.0, bottom: 10.0, right: 30.0),
                  child: Divider(
                      height: 2.0,
                      thickness: 3.5,
                      indent: 25.0
                  )
              ),
              // SingleChildScrollView(
                blockPicker,
            ],
          ),
        ),
           ),
        ),
        ),
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

  // HSVColor currentHSV = HSVColor.fromAHSV(1.0, 275, 1.0, 1.0);

  Future<void> closePopup(BuildContext context) async {
    Navigator.of(context).pop();
  }

  // Color pickedColor = currentColor;

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
    _multiColorActive = multiColorSwitch.isActive;
    _resizingActive = resizingSwitch.isActive;
    rangeMinDb = volumeSlider.min;
    rangeMaxDb = volumeSlider.max;
    currentColor = blockPicker.currentColor;
    pickerColor = blockPicker.pickerColor;

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
  bool isActive;

  SwitchWidget({super.key, required this.isActive });

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

class BlockPickerWidget extends StatefulWidget {
  Color pickerColor;
  Color currentColor;

  BlockPickerWidget({super.key, required this.pickerColor, required this.currentColor });

  @override
  State<BlockPickerWidget> createState() => _BlockPickerWidgetState();
}

class _BlockPickerWidgetState extends State<BlockPickerWidget> {
  @override
  Widget build(BuildContext context) {
    return BlockPicker(
        pickerColor: widget.pickerColor,
        onColorChanged: (color) {
          widget.currentColor = color;
          widget.pickerColor = color;
          print(color);
        }
    );
  }
}

class RangeSliderWidget extends StatefulWidget {
  double min = 45.0;
  double max = 95.0;

  RangeSliderWidget({super.key});

  @override
  State<RangeSliderWidget> createState() => _RangeSliderWidgetState();
}

class _RangeSliderWidgetState extends State<RangeSliderWidget> {
  @override
  Widget build(BuildContext context) {
    // RangeValues _currentRangeValues = const RangeValues(widget.min, widget.max);

    return RangeSlider(
      values: RangeValues(widget.min, widget.max),
      min: 45,
      max: 95,
      divisions: 10,
      labels: RangeLabels(
        RangeValues(widget.min, widget.max).start.round().toString(),
        RangeValues(widget.min, widget.max).end.round().toString(),
      ),
      onChanged: (RangeValues values) {
        setState(() {
          widget.min = values.start;
          widget.max = values.end;
        });
      },
    );
  }
}
