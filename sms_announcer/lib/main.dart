import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sms/sms.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:flutter/services.dart';
import 'package:sms/contact.dart';

void main() => runApp(SmsAnnouncer());

class SmsAnnouncer extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

enum TtsState { playing, stopped, paused, continued }

class _MyAppState extends State<SmsAnnouncer> {
  late FlutterTts flutterTts;
  String? language;
  String? engine;
  double volume = 1.0;
  double pitch = 1.0;
  double rate = 0.5;
  bool isCurrentLanguageInstalled = false;

  String? _newVoiceText;
  int _numberOfSms = 5;
  int _sleepBetweenMessages = 2;

  TtsState ttsState = TtsState.stopped;

  get isPlaying => ttsState == TtsState.playing;
  get isStopped => ttsState == TtsState.stopped;
  get isPaused => ttsState == TtsState.paused;
  get isContinued => ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWeb => kIsWeb;

  late TextEditingController _numberOfSmsController;

  SmsQuery query = new SmsQuery();
  List<SmsMessage>? allmessages;
  List<SmsThread>? allthreads;

  @override
  initState() {
    _numberOfSmsController =
        TextEditingController(text: _numberOfSms.toString());
    initTts();
    getAllMessages();
    super.initState();
  }

  void getAllMessages() {
    Future.delayed(Duration.zero, () async {
      List<SmsMessage> messages = await query.querySms(
        //querySms is from sms package
        kinds: [SmsQueryKind.Inbox],
        //filter Inbox, sent or draft messages
        count: _numberOfSms, //number of sms to read
      );
      setState(() {
        allmessages = messages;
      });
    });
  }

  initTts() {
    flutterTts = FlutterTts();
    flutterTts.setLanguage("nb-NO");
    flutterTts.setEngine("com.google.android.tts");

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
    }

    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
        ttsState = TtsState.stopped;
      });
    });

    if (isWeb || isIOS) {
      flutterTts.setPauseHandler(() {
        setState(() {
          print("Paused");
          ttsState = TtsState.paused;
        });
      });

      flutterTts.setContinueHandler(() {
        setState(() {
          print("Continued");
          ttsState = TtsState.continued;
        });
      });
    }

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });
  }

  Future _getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future _speak() async {
    getAllMessages();
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    flutterTts.speak("Leser opp de siste " +
        _numberOfSms.toString() +
        " mottatte meldinger");
    flutterTts.awaitSpeakCompletion(true);

    if (allmessages != null) {
      for (var sms in allmessages!) {
        if (sms.body.isNotEmpty) {
          String sender = sms.sender;
          ContactQuery contacts = ContactQuery();
          Contact contact = await contacts.queryContact(sms.address);

          if (contact != null) {
            if (contact.fullName != null && contact.fullName.isNotEmpty) {
              sender = contact.fullName;
            } else {
              sender = contact.address;
            }
          }
          print(sms.date);
          print(sender);
          print(contact.fullName);
          print(sms.body);
          await flutterTts.speak("Melding mottatt fra " + sender);
          await Future.delayed(Duration(seconds: 1));
          await flutterTts.speak(sms.body);
          flutterTts.awaitSpeakCompletion(true);
          await Future.delayed(Duration(seconds: _sleepBetweenMessages));
        }
      }
    }
  }

  Future _setAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future _pause() async {
    var result = await flutterTts.pause();
    if (result == 1) setState(() => ttsState = TtsState.paused);
  }

  @override
  void dispose() {
    super.dispose();
    flutterTts.stop();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('SMS Oppleser'),
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              _btnSection(),
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(""),
              ),
              _buildNumberColumn()
            ],
          ),
        ),
      ),
    );
  }

  Widget _btnSection() {
    if (isAndroid) {
      return Container(
          padding: EdgeInsets.only(top: 50.0),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildButtonColumn(Colors.blue, Colors.blueAccent, Icons.play_arrow,
                'Spill av siste SMSer', _speak),
            _buildButtonColumn(
                Colors.purple, Colors.purpleAccent, Icons.stop, 'Stopp', _stop),
          ]));
    } else {
      return Container(
          padding: EdgeInsets.only(top: 50.0),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildButtonColumn(Colors.blue, Colors.blueAccent, Icons.play_arrow,
                'PLAY', _speak),
            _buildButtonColumn(
                Colors.purple, Colors.purpleAccent, Icons.stop, 'STOP', _stop),
            _buildButtonColumn(
                Colors.blue, Colors.blueAccent, Icons.pause, 'PAUSE', _pause),
          ]));
    }
  }

  Column _buildNumberColumn() {
    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _numberOfSmsController,
            decoration:
                new InputDecoration(labelText: "Les opp antall meldinger:"),
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ],
            onChanged: (value) {
              if (value.isNotEmpty) {
                _numberOfSms = int.parse(value);
              }
            },
            style: TextStyle(fontSize: 30.0, height: 3.0, color: Colors.black),
            // Only numbers can be entered
          ),
        ]);
  }

  Column _buildButtonColumn(Color color, Color splashColor, IconData icon,
      String label, Function func) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              icon: Icon(icon),
              color: color,
              iconSize: 100,
              splashColor: splashColor,
              onPressed: () => func()),
          Container(
              margin: const EdgeInsets.only(top: 2.0),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.w400,
                      color: color)))
        ]);
  }
}
