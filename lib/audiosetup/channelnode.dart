library ChannelNode;

import 'dart:math';
import "dart:web_audio";

import 'baseclass/simpleaudionode.dart';
import '../toolclasses/sample.dart';
import '../toolclasses/webaudiohelper.dart';
import '../toolclasses/tables.dart';

/// Class In charge of the audio setup for one Channel.
class ChannelNode extends SimpleAudioNode {

  /// channelIndex is required to know the default stereo setting.
  ChannelNode(SimpleAudioNode channelTargetNode, int this._channelIndex)
      : super('channel', channelTargetNode, false) {
  }

  @override
  void buildThisNode() {
    //
    _bandpassNode = context.createBiquadFilter();
    _bandpassNode.type = 'bandpass';
    _bandpassNode.channelCountMode = 'explicit';
    _bandpassNode.channelCount = 1;
    //
    _gainNode = context.createGain();
    _gainNode.gain.value = _initialGain;
    _bandpassNode.connectNode(_gainNode);
    //
    destination = _bandpassNode;
    lastNode = _gainNode; // bandpassNode;
  }

  /// a Channel has no ancestor
  @override
  SimpleAudioNode buildAncestorNode() {
    return null;
  }

  @override
  void resetThisNode(when) {
    if (_currentAudioBufferSource != null) {
      _currentAudioBufferSource.stop(when);
    }
    _currentAudioBufferSource = null;
    // TODO: finish resetNode
    // stereo reset
  }

  @override
  void disposeThisNode() {
    disconnectAll([_currentAudioBufferSource, _bandpassNode, _gainNode]);
    _currentAudioBufferSource = null;
    _bandpassNode = null;
    _gainNode = null;
  }


      /// a channel is handled by a ChannelCollection in charge of connecting the Channels.
  @override
  void connect() {
    int channelIndexMod4 = _channelIndex & 0x3;
    if (channelIndexMod4 == 0 || channelIndexMod4 == 3) {
      // left channel
      lastNode.connectNode(targetNode.leftGainNode);
    } else {
      // right channel
      lastNode.connectNode(targetNode.rightGainNode);
    }
  }

  void setPlaybackRateCurve(curve, when, period) {
    if (_currentAudioBufferSource != null) return; // defensive
    _currentAudioBufferSource.playbackRate.setValueCurveAtTime(
        curve,
        when,
        period);
  }

  void setPlaybackRateValue(val, when) {
    if (_currentAudioBufferSource != null) // defensive
    _currentAudioBufferSource.playbackRate.linearRampToValueAtTime(val, when);
  }

  num getSampleLength() {
    return (_sample == null) ? 0 : _sample.length;
  }

  Sample _sample = null;
  int _channelIndex = -1;

  AudioBufferSourceNode _currentAudioBufferSource = null;

  GainNode _gainNode = null;
  double _initialGain = 0.8;

  BiquadFilterNode _bandpassNode = null;

  // parameter
  double _BPlowFrequency = 50.0;
  // parameter
  double _BPlowFrequencyMin = 30.0;

  // parameter
  double _BPhighFrequency = 4600.0;
  //parameter
  double _BPhighFrequencyMin = 3000.0;
  double _BPHighFrequencyMax = 8000.0;


  void setSample(Sample newSample) {
    _sample = newSample;
  }

  void _buildAudioSource(int initialPeriod, channelVolume) {
    _currentAudioBufferSource =
        _sample.buildAudioBufferSource(context, initialPeriod);
    if (_currentAudioBufferSource == null) return;
    double newFrequRatio = _sample.frequencyRatioForPeriod(initialPeriod);
    if (initialPeriod != -1) _currentAudioBufferSource.playbackRate.value =
        newFrequRatio;
    _connectAudioBufferSource();
  }

  void _connectAudioBufferSource() {
    if (_currentAudioBufferSource == null) return;
    _currentAudioBufferSource.connectNode(destination);
    return;
  }

  void _setupBandpass(double newFrequRatio, [double when = 0.0]) {
    // compute low/high freq for the bandPass.
    double lowFreq = newFrequRatio * _BPlowFrequency;
    double highFreq = newFrequRatio * _BPhighFrequency;
    // adjust frequency with mip-mapping parameters.
    if (_sample != null && _sample.currentFreqMultiplier != 1.0) {
      lowFreq /= _sample.currentFreqMultiplier;
      highFreq /= _sample.currentFreqMultiplier;
    }
    // bound checking
    if (lowFreq < _BPlowFrequencyMin) lowFreq = _BPlowFrequencyMin;
    highFreq = highFreq.clamp(_BPhighFrequencyMin, _BPHighFrequencyMax);
    //
    double centerFreq = sqrt(lowFreq * highFreq);
    double Q = centerFreq / (highFreq - lowFreq);
    if (when <= 0) {
      _bandpassNode.frequency.value = centerFreq;
      _bandpassNode.Q.value = Q;
    } else {
      _bandpassNode.frequency.setValueAtTime(centerFreq, when);
      _bandpassNode.Q.setValueAtTime(Q, when);
    }
  }

  num getFrequencyRatioForPeriod(num period) {
    return _sample.frequencyRatioForPeriod(period);
  }


  void noteMeOn(double when, int samplePeriod, int channelVolume, [int offset =
      0]) {
    if (_currentAudioBufferSource != null) {
      _currentAudioBufferSource.stop(when);
      _currentAudioBufferSource = null;
    }
    _buildAudioSource(samplePeriod, channelVolume);
    if (_currentAudioBufferSource == null) return;
    setDetune(0, when);
    setGain(channelVolume, when);

    double newFrequRatio = _sample.frequencyRatioForPeriod(samplePeriod);

    _setupBandpass(newFrequRatio, when);

    if (offset == 0) {
      _currentAudioBufferSource.start(when);
    } else {
      _currentAudioBufferSource.start(when);
      // TODO : ! !! MUST FIX !!! offset not handled

          // should be : currentAudioBufferSource.  start (  when,  ????  offset/11025 , ???? );
    }
  }

  void noteMeOff(double when) {
    if (_currentAudioBufferSource == null) return;
    _currentAudioBufferSource.stop(when);
    _currentAudioBufferSource = null;
  }

  /// will detune the note being played [when] by [shift] 8th's of half-tones
  void setDetune(num newShift, double when) {
    newShift += _sample.signedFinetune;
    if (_currentShift == newShift) return; else _currentShift = newShift;
    newShift *= 100 / 8;
    _currentShift = newShift;
  }
  num _currentShift = 0;

  void setPeriodNow(int samplePeriod) {
    if (_currentAudioBufferSource == null) return;
    _currentAudioBufferSource.playbackRate.value =
        _sample.frequencyRatioForPeriod(samplePeriod);
  }

  void setPeriod(int samplePeriod, double when) {
    if (_currentAudioBufferSource == null) return;
    // linearRampToValueAtTime ?
    _currentAudioBufferSource.playbackRate.setValueAtTime(
        _sample.frequencyRatioForPeriod(samplePeriod),
        when);
  }

  void setGain(int channelVolume, double when) {
    if (_currentAudioBufferSource == null) return;
    _gainNode.gain.setValueAtTime(normalizedVolume[channelVolume], when);
//       gainNode.setValueAtTime(sample.getWebaudioVolumeFromChannelVolume(channelVolume), when);
  }

}
