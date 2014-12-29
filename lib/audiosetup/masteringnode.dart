library MasteringNode;

import "dart:web_audio";
import '../modplayer/mod.dart';
import '../toolclasses/webaudiohelper.dart';

typedef void callback();


/// Class in charge of general mastering.
/// Rq : this class is a singleton.
/// Use only context from this class if possible.
class MasteringNode {

  /// factory constructor returning the unic Protracker instance (singleton)
  factory MasteringNode() {
    return _masteringNodeInstance;
  }

  /// is music currently playing ?
  bool get playing => _activeMod != null;
  /// is music paused ?
  bool paused = false;
  /// will music repeat ?
  bool repeat = false;

  /// volume. within [ 0.0 ; 1.0 ] range.
  double get volume => _volume;
  /// volume. within [ 0.0 ; 1.0 ] range.
  /// Rq : volume is changed with a [volumeRampTime] seconds linear ramp.
  void set volume(double val) {
    if (_volume == val) return;
    val.clamp(0.0, 1.0);
    _volume = val;
    num currTime = context.currentTime;
    masterVolumeNode.gain.linearRampToValueAtTime(
        _volume,
        currTime + volumeRampTime);
  }
  double volumeRampTime = 0.4;

  /// plays [mod].
  /// does nothing if [mod] is already playing.
  /// if another mod is playing, stops it, and play [mod]
  void play(Mod mod) {
    print('should play');
    if (context == null) return;
    if (_activeMod == mod) return;
    //
    if (_activeMod !=
        null) _activeMod.stop(0.0); // signal to the oldMod it was stopped.
    _activeMod = mod; // now we deal with the new mod.
    if (onPlay != null) onPlay();
    _activeMod.play();
  }

  /// stop playing current mod.
  /// does nothing if no mod was playing.
  void stop() {
    if (context == null) return;
    if (_activeMod == null) return;
    _activeMod.stop(0.0);
    if (onStop != null) onStop();
  }

  callback onReady = null;

  /// this callback fires before the player starts playing.
  callback onPlay = null;
  /// this callback fires after the player stopped playing.
  callback onStop = null;

  /// current audio context.
  /// Rq : Use it to create nodes only, and connect channels to [firstNode].
  AudioContext context = null;

  /// Any node willing to output sound should connect to this node.
  AudioNode firstNode = null;

  Mod _activeMod = null;

  BiquadFilterNode lowpassNode = null;
  BiquadFilterNode cutOff = null;
  DynamicsCompressorNode compressorNode = null;
  GainNode masterVolumeNode = null;
  AnalyserNode analyserNode = null;
  BiquadFilterNode bassBooster = null;
  // BiquadFilterNode highBooster = null;
  // ConvolverNode convolver = null;

  double initialCutOffValue = 30.0;

  AudioNode destination = null;

  // create the webAudio context
  void _createContext() {
    context = new AudioContext();
    context.destination.channelCountMode = 'explicit';
    context.destination.channelCount = 2;
    // low pass filter
    lowpassNode = context.createBiquadFilter();
    lowpassNode.type = 'lowpass'; // 'BiquadFilterNode.ALLPASS';
    lowpassNode.frequency.value = 12000;
    // compressor for a bit of volume boost
    compressorNode = context.createDynamicsCompressor();
    compressorNode.attack.value = 0.2;
    compressorNode.release.value = 0.2;
    compressorNode.ratio.value = 2;
    compressorNode.threshold.value = -26;
    compressorNode.reduction.value = -20;
    // master gain control
    masterVolumeNode = context.createGain();
    masterVolumeNode.gain.value = 1.0;
    // bass booster
    bassBooster = context.createBiquadFilter();
    bassBooster.type = 'peaking';
    bassBooster.frequency.value = 140;
    bassBooster.Q.value = 2;
    // Cut Off
    cutOff = context.createBiquadFilter();
    cutOff.type = 'highpass';
    cutOff.frequency.value = initialCutOffValue;
    cutOff.Q.value = 4;
    // cutOff.gain.value = 6;

/*
     // high freq booster
     highBooster = context.createBiquadFilter();
     highBooster.type='peaking';
     highBooster.frequency.value = 400; 
     highBooster.Q.value = 1.4;
     //highBooster.gain.value = 3;
*/
    analyserNode = context.createAnalyser();
    analyserNode.smoothingTimeConstant = 0.1;
    analyserNode.minDecibels = -100;

    chainConnect([masterVolumeNode, analyserNode, context.destination]);


        //  chainConnect([lowpassNode , cutOff, compressorNode,  bassBooster,  masterVolumeNode, analyserNode, context.destination]);

    firstNode = masterVolumeNode;
    destination = firstNode;
  }

  // Protracker private constructor
  MasteringNode._internal() {
    _createContext();
    if (context != null && onReady != null) onReady();
  }

  // masyering node singleton
  static final MasteringNode _masteringNodeInstance =
      new MasteringNode._internal();

// Private backing fields
  double _volume = 1.0;
  bool _palClock = false;
  double _palClockRate = 7159090.5;

}
