import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

class AudioPlayerJust extends StatefulWidget {
  const AudioPlayerJust({
    Key? key,
    this.width,
    this.height,
    this.audioURL,
    this.backgroundColor,
    this.autoplay,
  }) : super(key: key);

  final double? width;
  final double? height;
  final String? audioURL;
  final Color? backgroundColor;
  final bool? autoplay;

  @override
  _AudioPlayerJustState createState() => _AudioPlayerJustState();
}

class _AudioPlayerJustState extends State<AudioPlayerJust> {
  final AudioPlayer _player = AudioPlayer();
  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays speech.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });
    // Try to load audio from a source and catch any errors.
    try {
      // AAC example: https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac

      await _player.setAsset("assets/music/Sailing - Telecasted.mp3");
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from.
      _player.stop();
    }
  }

  /// Collects the data useful for displaying in a seek bar, using a handy
  /// feature of rx_dart to combine the 3 streams of interest into one.
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            backgroundColor: Colors.deepPurple,
            body: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Center(
                child: Container(
                  height: 130,
                  width: 400,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: Column(
                    children: [
                      // Display seek bar. Using StreamBuilder, this widget rebuilds
                      // each time the position, buffered position or duration changes.
                      Expanded(
                        flex: 1,
                        child: StreamBuilder<PositionData>(
                          stream: _positionDataStream,
                          builder: (context, snapshot) {
                            final positionData = snapshot.data;
                            return (positionData != null)
                                ? SeekBar(
                                    player: _player,
                                    duration: positionData.duration,
                                    position: (positionData.position <=
                                            const Duration(seconds: 1))
                                        ? const Duration(seconds: 1)
                                        : positionData.position,
                                    bufferedPosition:
                                        positionData.bufferedPosition,
                                    onChangeEnd: _player.seek,
                                  )
                                : Container();
                          },
                        ),
                      ),
                      // Display play/pause button and volume/speed sliders.
                      Expanded(flex: 1, child: ControlButtons(_player)),
                    ],
                  ),
                ),
              ),
            )));
  }
}

/// Displays the play/pause button and volume/speed sliders.
class ControlButtons extends StatelessWidget {
  final AudioPlayer player;
  Duration position = Duration.zero;

  ControlButtons(this.player, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Opens volume slider dialog
        IconButton(
          icon: const Icon(
            Icons.volume_up,
            color: Colors.white,
          ),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              activeColor: const Color(0xFF9C27B0),
              inactiveColor: const Color(0xFFE1BEE7),
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),

        /// This StreamBuilder rebuilds whenever the player state changes, which
        /// includes the playing/paused state and also the
        /// loading/buffering/ready state. Depending on the state we show the
        /// appropriate button or loading indicator.
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFFFFF),
                    width: 2,
                  ),
                ),
                child: IconButton(
                  iconSize: 35,
                  icon: const Icon(
                    Icons.play_arrow,
                    color: const Color(0xFFFFFFFF),
                  ),
                  onPressed: player.play,
                ),
              );
            } else if (processingState != ProcessingState.completed) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFFFFF),
                    width: 2,
                  ),
                ),
                child: IconButton(
                  iconSize: 35,
                  icon: const Icon(
                    Icons.pause,
                    color: const Color(0xFFFFFFFF),
                  ),
                  onPressed: player.pause,
                ),
              );
            } else {
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFFFFF),
                    width: 2,
                  ),
                ),
                child: IconButton(
                  iconSize: 35,
                  icon: const Icon(
                    Icons.pause,
                    color: const Color(0xFFFFFFFF),
                  ),
                  onPressed: player.pause,
                ),
              );
              return IconButton(
                iconSize: 35,
                icon: const Icon(
                  Icons.replay,
                  color: const Color(0xFFFFFFFF),
                ),
                onPressed: () => player.seek(Duration.zero),
              );
            }
          },
        ),
        // Opens speed slider dialog
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            iconSize: 35,
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xffFFFFFF))),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                activeColor: const Color(0xFF9C27B0),
                inactiveColor: const Color(0xFFE1BEE7),
                value: player.speed,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        )
      ],
    );
  }
}

class SeekBar extends StatefulWidget {
  final AudioPlayer player;
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final ValueChanged<Duration>? onChanged;
  final ValueChanged<Duration>? onChangeEnd;

  const SeekBar({
    Key? key,
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    this.onChanged,
    this.onChangeEnd,
    required this.player,
  }) : super(key: key);

  @override
  SeekBarState createState() => SeekBarState();
}

class SeekBarState extends State<SeekBar> {
  double? _dragValue;
  late SliderThemeData _sliderThemeData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _sliderThemeData = SliderTheme.of(context).copyWith(
      trackHeight: 10.0,
    );
  }

  String formatTime(Duration value) {
    String twoDigist(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigist(value.inHours);
    final min = twoDigist(value.inMinutes.remainder(60));
    final sec = twoDigist(value.inSeconds.remainder(60));

    return [if (value.inHours > 0) hours, min, sec].join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SliderTheme(
          data: _sliderThemeData.copyWith(
            thumbShape: SliderComponentShape.noThumb,
            activeTrackColor: const Color(0xffEB5757),
            inactiveTrackColor: const Color(0xff590677),
          ),
          child: Slider(
            min: 0.0,
            max: widget.duration.inMilliseconds.toDouble(),
            value: min(_dragValue ?? widget.position.inMilliseconds.toDouble(),
                widget.duration.inMilliseconds.toDouble()),
            onChanged: (value) {
              setState(() {
                _dragValue = value;
              });
              if (widget.onChanged != null) {
                widget.onChanged!(Duration(milliseconds: value.round()));
              }
            },
            onChangeEnd: (value) {
              if (widget.onChangeEnd != null) {
                widget.onChangeEnd!(Duration(milliseconds: value.round()));
              }
              _dragValue = null;
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(formatTime(widget.position),
                style: const TextStyle(color: Color(0xffFFFFFF))),
            Text(formatTime(widget.duration),
                style: const TextStyle(color: Color(0xffFFFFFF))),
          ]),
        ),
      ],
    );
  }

  Duration get _remaining => widget.duration - widget.position;
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

void showSliderDialog({
  required BuildContext context,
  required String title,
  required int divisions,
  required double min,
  required double max,
  required Color inactiveColor,
  required Color activeColor,
  String valueSuffix = '',
  // TODO: Replace these two by ValueStream.
  required double value,
  required Stream<double> stream,
  required ValueChanged<double> onChanged,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: StreamBuilder<double>(
        stream: stream,
        builder: (context, snapshot) => SizedBox(
          height: 100.0,
          child: Column(
            children: [
              Text('${snapshot.data?.toStringAsFixed(1)}$valueSuffix',
                  style: const TextStyle(
                      fontFamily: 'Fixed',
                      fontWeight: FontWeight.bold,
                      fontSize: 24.0)),
              Slider(
                divisions: divisions,
                min: min,
                max: max,
                inactiveColor: inactiveColor,
                activeColor: activeColor,
                value: snapshot.data ?? value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

T? ambiguate<T>(T? value) => value;
