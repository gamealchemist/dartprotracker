library Sample;

import "dart:typed_data";
import "dart:convert";
import "dart:web_audio";
import "dart:math";

import "tables.dart";
import 'filters.dart';

/// !! magic parameter to reduce volume !!
const double mixAdjust = 0.4;

class Sample {

  String name = "";
  int length = 0;
  int loopStart = 0;
  int loopLength = 0;

  int signedFinetune = 0;
  int volume = 64;

  int currentPeriod = -1;
  int mimapLevel = -1;

  double get currentFreqMultiplier => _currentFreqMultiplier;

  bool get looping => loopLength > 0;

  int get loopEnd => loopStart + loopLength - 1;

  bool get silent => length == 0;

  List<AudioBuffer> audioBuffers = new List<AudioBuffer>();

  Float32List initialWaveBuffer = null;

  static final Map<int, int> mipMapLevelForPeriod = new Map<int, int>();

  double frequencyRatioForPeriod(num period) {
    // update mimap levels and frequency multiplier
    mimapLevel = mipMapLevelForPeriod[period.floor()];
    if (mimapLevel == null) {
      mimapLevel =
          (log(period / 320) / log(2)).floor(); //3 mipmaps : add + 1 to this formula
      mimapLevel = mimapLevel.clamp(0, 1); // mipMapLevel.clamp(0, 2);
      mipMapLevelForPeriod[period.floor()] = mimapLevel;
    }
    // mult : 2 / 0.5 / 1 for 3 mimaps
    //       0.5 / 1       for 2 mipmaps
    _currentFreqMultiplier = 1.0;
    if (mimapLevel == 1) _currentFreqMultiplier = 0.5;
    //    mult for 3 mipmaps:
    //     _currentFreqMultiplier =  0.5;
    //     if (mipMapLevel == 2) _currentFreqMultiplier=0.5;
    //     else if (mipMapLevel == 0) _currentFreqMultiplier=2.0;

    // compute frequency ratio, with double precision if possible.
    double _320 = 320.0;
    if (acurateFrequencyMap.containsKey(period)) {
      period = acurateFrequencyMap[period];
      _320 = acurate320;
    }

    double newFreqR = _currentFreqMultiplier * _320 / period;
    return newFreqR;
  }

  double getWebaudioVolumeFromChannelVolume(int channelVolume) {
    channelVolume.clamp(0, 64);
    if (channelVolume == 0) channelVolume = 0;
    return mixAdjust * volume / 64 * channelVolume / 64;
/* 
 some other attempts :

1. double ratio = channelVolume / 64;
    ratio=pow(ratio, 1/1.4);
    ratio = (ratio == 0.0) ? 0.0 : ( 0.4 + 0.6*ratio) ;
    return ratio;

2. return  normalizedVolume[channelVolume];   

3. double linGain =  /* ( volume / 64 ) * */ ( channelVolume / 64 ) ;

4. double gain = 1 -  log(E * (1 - linGain))  ;
*/

  }

  /// returns a new AudioBufferSourceNode for this sample
  ///     in case of sound mipMapping builds on top of nearest sample
  /// !! returns null for an empty sample.
  AudioBufferSourceNode buildAudioBufferSource(AudioContext context,
      int targetPeriod) {
    AudioBufferSourceNode res = context.createBufferSource();
    res.channelCountMode = 'explicit';
    res.channelCount = 1;
    if (audioBuffers == null) return null;
    currentPeriod = targetPeriod;
    frequencyRatioForPeriod(targetPeriod);
    res.buffer = audioBuffers[mimapLevel];
    if (looping) {
      res.loopStart = _currentFreqMultiplier * loopStart / 11025;
      int loopEnd = loopStart + loopLength;
      if (loopEnd > length) loopEnd = loopEnd - (length - loopEnd);
      res.loopEnd = _currentFreqMultiplier * (loopStart + loopLength) / 11025;
      res.loop = true;
    }
    return res;
  }

  Float32List buildFloat32Buffer(Uint8List buffer) {
    final int ilen = buffer.length;
    Float32List fbuffer = new Float32List(ilen);

    double posMin = 2.0,
        posMax = -1.0;
    double negMin = 2.0,
        negMax = 2.0;
    // convert the 8 bits pcm to float32 [-1.0;1.0]
    for (int i = 0; i < ilen; i++) {
      int shortValue = buffer[i];
      double value =
          (shortValue < 128) ? shortValue / 127 : (-(0xFF ^ shortValue) - 1) / 128;
      if (value > 0) {
        if (posMin > value) posMin =
            value; else if (posMax < value) posMax = value;
      } else {
        if (negMin > value) negMin =
            value; else if (negMax > value) negMax = value;
      }
      fbuffer[i] = 1.0 * value;
    }
    // filterloop(fbuffer);
    filterloop__11Ksamples_5200cutoff(fbuffer);

    if (fbuffer[ilen - 1] > 0.1 && ilen > 10) {
      for (int i = 0; i < 10; i++) fbuffer[ilen - 10 + i] *= (10 - i) / 10;
    }
    return fbuffer;
  }

  void playSample(AudioContext context) {
    if (_lastAbs != null) {
      _lastAbs.stop(0);
      _lastAbs = null;
    }
    Sample s = this;
    if (s.audioBuffers == null) return;
    AudioBufferSourceNode toto = context.createBufferSource();
    if (s.looping) {
      toto.loopStart = s.loopStart / 11025;
      toto.loopEnd = (s.loopStart + s.loopLength) / 11025;
      toto.loop = true;
    }
    _lastAbs = toto;
    toto.buffer = s.audioBuffers[0];
    toto.playbackRate.value = 0.75;
    toto.connectNode(context.destination);
    toto.start(0);
  }
  AudioBufferSourceNode _lastAbs = null;


  void parseInformations(Uint8List buffer) {
    // -- name --
    int j = 0,
        letter = 0;
    while ((letter = buffer[j]) != 0 && j < 22) {
      _nameArray[j] = (letter > 0x1f && letter < 0x7f) ? letter : 32;
      j++;
    }
    while (j < 22) _nameArray[j++] = 32;
    name = _asciiDecoder.convert(_nameArray);
    name = name.replaceAll(' ', '');
    // -- other properties --
    length = (buffer[22] * 256 + buffer[23]) * 2;
    int finetune = buffer[24];
    signedFinetune = (finetune < 8) ? finetune : -16 + finetune;
    if (finetune > 7) finetune = finetune - 16;
    volume = buffer[25];
    loopStart = 2 * (buffer[26] * 256 + buffer[27]);
    loopLength = 2 * (buffer[28] * 256 + buffer[29]);
    if (loopLength == 2) loopLength = 0;
    if (loopStart + loopLength > length) {
      loopStart = 0;
      loopLength = length - loopStart;
    }
    if (loopStart > length || loopLength <= 0) {
      loopStart = 0;
      loopLength = 0;
    }
  }

  void parseData(AudioContext context, Uint8List buffer) {
    initialWaveBuffer = buildFloat32Buffer(buffer);
    if (buffer.length >= 2) {
      buffer[0] = 0;
      buffer[1] = 0;
    }

        //  AudioBuffer audioBuffer_0=  buildAudioBuffer(context, initialWaveBuffer, 22100, 4);
    AudioBuffer audioBuffer_1 =
        buildAudioBuffer(context, initialWaveBuffer, 22100, 2, false, true);
    AudioBuffer audioBuffer_2 =
        buildAudioBuffer(context, initialWaveBuffer, 22100, 1);
    audioBuffers.add(audioBuffer_1);
    audioBuffers.add(audioBuffer_2);
  }

  AudioBuffer buildAudioBuffer(AudioContext context, Float32List fbuffer,
      int sampleRate, int overSampleRatio, [bool stereo = false, bool useHermite =
      false]) {

    final initialBufferLength = fbuffer.length;

    AudioBuffer res =
        context.createBuffer(2, fbuffer.length * overSampleRatio, sampleRate);
    Float32List left = res.getChannelData(0);
    Float32List right = null;
    if (stereo) right = res.getChannelData(1);

    if (overSampleRatio == 1) {
      for (int i = 0; i < initialBufferLength; i++) {
        left[i] = fbuffer[i];
        if (stereo) right[i] = fbuffer[i];
      }
    } else if (overSampleRatio == 2) {
      if (!useHermite) {
        for (int i = 0; i < initialBufferLength; i++) {
          left[i * 2] = left[i * 2 + 1] = fbuffer[i];
          if (stereo) right[i * 2] = right[i * 2 + 1] = fbuffer[i];
        }
      } else {
        for (int i = 0; i < initialBufferLength; i++) {
          if (i >= 2 && i < initialBufferLength - 3) {
            interpolateHermite_2X(fbuffer, left, i);
          } else {
            left[2 * i] = fbuffer[i];
            left[2 * i + 1] = fbuffer[i];
          }
        }
        if (stereo) for (int i =
            0; i < 2 * initialBufferLength; i++) right[i] = left[i];
      }
    } else {
      throw
          ('[sample.buildAudioBuffer] only 1X and 2X oversample ratio supported.');
    }
    return res;

    /*   temp[0] = temp[1] = temp[2] = buffer[0];
    temp[3] = buffer[1];
    temp[4] = buffer[2];
    temp[5] = buffer[3];  */

    /*
  AudioBuffer res =context.createBuffer(2, buffer.length * 4, 44100);
   Float32List left = res.getChannelData(0);
   Float32List right = res.getChannelData(1);
   int lastIndex = buffer.length - 1, ti=0;
   for (int i=0; i<= ilen - 2; i++) {
        double value = fbuffer[i];
        double nextValue = fbuffer[i+1];
        left[ti]=right[ti]=value;
        ti++;
        left[ti]=right[ti]=value;
                ti++;
                left[ti]=right[ti]=value;
                        ti++;
                        left[ti]=right[ti]=value;
                                ti++;                 
   }
   for (int i=0; i< ilen ; i++) {
       if (i>=2 && i<ilen-3) interpolateHermite(fbuffer, left, i);
   } */

  }

  double _currentFreqMultiplier = 1.0;

}


final AsciiDecoder _asciiDecoder = new AsciiDecoder();
final Uint8List _nameArray = new Uint8List(22);

/*
    // code to reduce high frequ. energy
    double previousValue = fbuffer[0];
    for (int i=0; i<ilen; i++)   { 
       double value = fbuffer[i];
       fbuffer[i] = value - 0.96*(previousValue);
       previousValue = value;       
    }         
  */


