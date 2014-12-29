library Channel;

import 'mod.dart';
import "dart:typed_data";
import "dart:math";

import '../audiosetup/baseclass/simpleaudionode.dart';
import '../audiosetup/channelnode.dart';
import '../toolclasses/tables.dart';

const curveSampleCount = 24;

/// defines a mod file channel reader
///   associated with a webAudio [ChannelNode] node that will play it.
///   reading is made ahead of time, so all properties reflect sounds to be played in the future.
///   the instance of this class are handled by the ModPartitionReader.
class Channel {

   /// creates a new Channel, that will play targetMod, connect on [channelCollectionNode]
  /// [_channelIndex] is required to know the default stereo setting.
  Channel(Mod this._targetMod, SimpleAudioNode channelCollectionNode, int
      this._channelIndex) {
    __changeCurve = new Float32List(curveSampleCount);
    channelNode = new ChannelNode(channelCollectionNode, _channelIndex);
    sampleNumber = 1;
  }

  /// index of this channel. kept to know about stereo panning.
  int _channelIndex;
  /// webaudio node for this channel
  ChannelNode channelNode = null;
  
  /// current period of the sample. might be non-standard if an effect is ongoing.
  int get samplePeriod => _samplePeriod;
  void set samplePeriod(val) {
    if (val == 0) return;
    _samplePeriod = val;
    newNoteCame = true;
  }
  bool newNoteCame = false;

  /// current note. not used so far.
  int sampleNote = 0;

  /// sample number, in [1, 31] range.
  int get sampleNumber => _sampleNumber;
  void set sampleNumber(val) {
    if (val == 0) return;
    _sampleNumber = val;
    channelNode.setSample(_targetMod.sampleTable[_sampleNumber - 1]);
  }

  /// current effect for this note. -1 if no effect.
  int effectNumber = -1;
  /// effect of the previous line. -1 if no effect.
  int previousEffectNumber = -1;
  /// last effect seen effect on this line. >=0
  int lastEffectNumber = -1;
  /// arguments of the effect
  int argX, argY, argXY;

  bool get sameEffect => effectNumber == previousEffectNumber;

  // for 0x3 and 0x5
  int targetPeriod = 0;
  
  int channelVolume = 64;

  bool glissando = false;

  int sliderate = 0;

  int slidetoNote = 214;
  int slidetoNoteSpeed = 0;

  int arpegioCounter = -1;

  int semitone = 12;

  int currentFineTune = 0;
  int fineTuneOverRide = -1; // E5

  int volumeSlideVolume = -1;

  double vibratoAmp = 0.0;
  int vibratoArgX = -1;
  double vibratoFrequency = 0.0;
  int vibratoWaveForm = 0;

  double tremoloAmp = 0.0;
  int tremoloArgX = -1;
  double tremoloFrequency = 0.0;
  int tremoloWaveForm = 0;

  bool get requirePlayEffect => newNoteCame || effectNumber != -1 || previousEffectNumber == 0;

  int get tickCount => _targetMod.ticksPerLine__speed;

  /// play current stored effect on this channel
  void playEffect(double when) {
    // used for warming
    if (when < 0) return;

//if (_channelIndex!= 0) return;

    // handle arpegio end : there was an arpegio and no longer is
    if (previousEffectNumber == 0 &&
        effectNumber != 0) channelNode.setDetune(0, when);

    // if current effect is Arpeggio
    // do not retrigger, just reset arpegio counter.
    // the arpegio effect will take care of retriggering.
    if (effectNumber == 0) {
      newNoteCame = false;
    }

    // if a cut note effect is set with a 0 argument = cut note now
    // do not retrigger, just note off
    if (newNoteCame && effectNumber == 0xEC && argY == 0) {
      channelNode.noteMeOff(when);
      newNoteCame = false;
    }

    bool weJustSetVolume = false;
    // C set volume
    if (effectNumber == 0x0C) {
      weJustSetVolume = true;
      int vol = argXY;
      if (channelVolume != vol) {
        if (vol > 64) vol = 64;
        // a set volume to 0 is in fact a note off
        if (vol != 0) channelVolume = vol;
        if (!newNoteCame) {
          if (vol !=
              0) channelNode.setGain(channelVolume, when); else channelNode.noteMeOff(when);
        }
      }
    }

    // retrigger once for no effect, period
    //  set sample offset 09 and retrigger E9 or delay sample ED
    if (newNoteCame ||
        effectNumber == 0x09 ||
        effectNumber == 0xE9 ||
        effectNumber == 0xED) {
      if (!weJustSetVolume) channelVolume = 64;
      if (!weJustSetVolume && channelVolume <= 0) channelVolume = 64;
      // is it just for this time or for the rest of the song ?
      int offset = 0;
      if (effectNumber == 0x09) {
        int newStart = argXY << 8;
        num currentSampleLength = channelNode.getSampleLength();
        if (currentSampleLength != 0) {
          if (newStart < currentSampleLength) offset = newStart;
        }
      }
      double delay = 0.0;
      if (effectNumber == 0xED) {
        delay = argY * _targetMod.perTickTime;
      }
      channelNode.noteMeOn(when + delay, samplePeriod, channelVolume, offset);


          //  else _currentAudioBufferSource.noteGrainOn(when, sample.sampleStart, sample.length - sample.sampleStart) ;
      // retrigger a second time for E9
      if (effectNumber == 0xE9) {
        double tgtTime = when + argY * _targetMod.perTickTime;
        channelNode.noteMeOn(tgtTime, samplePeriod, channelVolume);
      }
    }

    // 0 arpegio ongoing (reminder : no effect is coded with effectNumber = -1 )
    // triggers. persistent effect.
    if (effectNumber == 0) {
      // if we were not arpegiating or we changed note, reset counter
      if (!sameEffect || samplePeriod != _previousSamplePeriod) {
        arpegioCounter = 0;
        channelVolume = 64;
      }
      // trigger the sounds for this line
      for (int tick = 0; tick < tickCount; tick++) {
        num mod3 = arpegioCounter % 3;
        num shift = 0;
        if (mod3 == 1) shift = argX; else if (mod3 == 2) shift = argY;
        channelNode.noteMeOn(
            when + tick * _targetMod.perTickTime,
            samplePeriod,
            channelVolume);
        channelNode.setDetune(shift, when + tick * _targetMod.perTickTime);
        arpegioCounter++;
      }
      // reseting the detune is done at the start
    }

    // 1 2 slide up / down == portamento up / down
    if (effectNumber == 0x01 || effectNumber == 0x02) {
      int increase = argXY;
      if (effectNumber == 0x02) increase = -increase;
      // increase/decrease for every ticks in the line
      for (int tick = 0; tick < tickCount; tick++) {
        if (!newNoteCame ||
            (newNoteCame &&
                tick !=
                    0)) channelNode.setPeriod(
                        samplePeriod,
                        when + tick * _targetMod.perLineTime / tickCount);
        // increase only we do not get out of bounds.
        int newPeriod = samplePeriod + increase;
        if (newPeriod >
            856) samplePeriod = 856; else if (newPeriod <
                113) samplePeriod = 113; else samplePeriod = newPeriod;
      }
    }

    // 3 : slide to note or 5 : slide to note + volume slide
    // seems to be done only once per note, besides what the spec says
    if (effectNumber == 0x03 || effectNumber == 0x05) {
      if (effectNumber == 0x03 && argXY != 0) slidetoNoteSpeed = argXY;
      if (samplePeriod > targetPeriod) {
        samplePeriod -= slidetoNoteSpeed;
        if (samplePeriod < targetPeriod) samplePeriod = targetPeriod;
      } else {
        samplePeriod += slidetoNoteSpeed;
        if (samplePeriod > targetPeriod) samplePeriod = targetPeriod;
      }
      int tr = 0; // 1 tick ahead or not ??
      channelNode.setPeriod(samplePeriod, when + tr * _targetMod.perTickTime);
    }

    // 4 Vibrato or 6 continue Vibrato (== vibrato + volume slide)
    if (effectNumber == 4 || effectNumber == 6) {
      double timePerCurvePart = _targetMod.perLineTime / curveSampleCount;
      // for a pure Vibrato, argX, argY might be arguments
      if (effectNumber == 4) {
        if (argY != 0) vibratoAmp = argY * 1.0;
        if (argX != vibratoArgX) {
          vibratoArgX = argX;
          double newVibratoFrequency =
              (2 * argX) /
              (64 * _targetMod.perLineTime);
          // update the phase in case we were allready in a vibrato
          if (previousEffectNumber == 4 ||
              previousEffectNumber ==
                  6) updateOscPhase(
                      when,
                      when + timePerCurvePart,
                      vibratoFrequency,
                      newVibratoFrequency);
          vibratoFrequency = newVibratoFrequency;
        }
        // start oscillator if need be
        if (previousEffectNumber != 4 &&
            previousEffectNumber != 6) startOscillator(when, vibratoFrequency);
      }
      // handle the case when partition 'continues' a vibrato when didn't start
      // ==> start the oscillator
      // ??? test/set def values if none set ???
      if (effectNumber == 6 &&
          !(previousEffectNumber == 4 ||
              previousEffectNumber == 6)) startOscillator(when, vibratoFrequency);
      // breach of responsability here
      // start frequency is samplePeriod.
      // !!! need to oscillate on period, not frequency
      double startValue = channelNode.getFrequencyRatioForPeriod(samplePeriod);
      double endValue =
          channelNode.getFrequencyRatioForPeriod(samplePeriod + vibratoAmp);

      double timeShift = 0.0;
      for (int i =
          0; i < curveSampleCount; i++, timeShift += timePerCurvePart) {
        __changeCurve[i] =
            startValue + (endValue - startValue) * getOscValue(when + timeShift);
           // TODO
           //    if (currentAudioBufferSource != null)
          //      currentAudioBufferSource.playbackRate.linearRampToValueAtTime(val , when );
      }
      channelNode.setPlaybackRateCurve(
          __changeCurve,
          when,
          _targetMod.perLineTime);
    }

    // 5 and 6 are also a volume slide => see 0x0A case

    // 7 tremollo
    // NON persistent effect
    if (effectNumber == 7) {
      double timePerCurvePart = _targetMod.perLineTime / curveSampleCount;
      if (argY != 0) tremoloAmp = 1.0 * argY * (tickCount - 1);
      if (argX != tremoloArgX) {
        tremoloArgX = argX;
        double newTremolloFrequency =
            (2 * argX) /
            (64 * _targetMod.perLineTime);
        if (sameEffect) updateOscPhase(
            when,
            when + timePerCurvePart,
            newTremolloFrequency,
            newTremolloFrequency);
        tremoloFrequency = newTremolloFrequency;
      }
      if (!sameEffect) startOscillator(when, tremoloFrequency);
      // breach of responsability here
      double startValue = 1.0 * channelVolume;
      double endValue = startValue + tremoloAmp;
      if (endValue > 64) endValue = 64.0;
      /// !!! need to oscillate on channel volume, not webaudio volume
      for (int i = 0; i < curveSampleCount; i++, when += timePerCurvePart) {
        double val =
            /* __changeCurve[i]  = */ startValue +
            tremoloAmp * getOscValue(when);
        channelNode.setPlaybackRateValue(val, when);
      }
      // TODO
     // if (currentAudioBufferSource != null) // defensive
     //          currentAudioBufferSource.playbackRate.setValueCurveAtTime(__changeCurve, when, _targetMod.perLineTime);
    }

    // 8 fine panning
    if (effectNumber == 0x08) {
      //  argXY == 0  full left  == 255 full right
    }

    // 9 is handled before

        // 0x0A /  5  / 6  :   Volume slide  ( alone / with tone portamento / with vibrato )
    if (effectNumber == 0x0A || effectNumber == 5 || effectNumber == 6) {
      if (effectNumber == 6) {
        var totot = 89;
      }
      int increase = (argX != 0) ? argX : -argY;
      int firstTick =
          (previousEffectNumber == 5 ||
              previousEffectNumber == 5 ||
              previousEffectNumber == 0xA) ?
              0 :
              1;
      for (int tick =
          firstTick; tick < tickCount; tick++) { // remark : starts at 1 the first time
        int newChannelVolume = channelVolume + increase;
        if (newChannelVolume > 64) {
          newChannelVolume = 64;
          break;
        }
        if (newChannelVolume < 0) {
          newChannelVolume = 0;
          break;
        }
        if (channelVolume != newChannelVolume) {
          channelVolume = newChannelVolume;
          channelNode.setGain(
              channelVolume,
              when + tick * _targetMod.perLineTime / tickCount);
        } else break;
      }
    }

    // E4 tremollo waveform
    if (effectNumber == 0xE4) vibratoWaveForm = argY % 4;

    // E5 fine-tune : not handled
    if (effectNumber == 0xE5) fineTuneOverRide = argY;

    // E6 : command (loop pattern)

    // E7 tremollo waveform
    if (effectNumber == 0xE7) tremoloWaveForm = argY % 4;

    // E8 : rough panning. not handled.
    if (effectNumber == 0xE8) {}

    // E9 : retrigger, handled before

    // EA/EB: Fine volume slide up/down
    // doesn't matter if we retriggered or not.
    if (effectNumber == 0xEA || effectNumber == 0xEB) {
      int change = effectNumber == 0xEA ? argY : -argY;
      channelVolume += change;
      channelVolume.clamp(0, 64);
      channelNode.setGain(
          channelVolume,
          when + _targetMod.perLineTime / tickCount);
    }

    // EC cut sample
    if (effectNumber == 0xEC) {
      channelNode.noteMeOff(when + argY * _targetMod.perLineTime / tickCount);
    }

    // ED delay sample, handled before

    // EF not supported (reverse sample)

    // 0xE : not documented, but seems to be used for a note off in some mod.
    // or not ?
    if (effectNumber == 0xE) {
      //   channelNode.noteMeOff(when);
    }

    previousEffectNumber = effectNumber;
    if (effectNumber != -1) lastEffectNumber = effectNumber;
    newNoteCame = false;
    _previousSamplePeriod = samplePeriod;
  }



  void startOscillator(double when, double freq) {
    _oscFreq = freq;
    _oscStartTime = when;
    _oscPhase = -PI / 2; // so that sin oscillator starts at 0
  }

  // between 0.0 and 1.0
  double getOscValue(double when) {
    return 0.5 *
        (1 + sin(2 * PI * _oscFreq * (when - _oscStartTime) - _oscPhase));
  }

  void updateOscPhase(double when, double nextWhen, double oldFreq,
      double newFreq) {
    double oldPhase = 2 * PI * oldFreq * (when - _oscStartTime) - _oscPhase;
    double newPhase = 2 * PI * newFreq * (when - _oscStartTime) - _oscPhase;
    _oscPhase += newPhase - oldPhase;
  }

  double _oscStartTime = 0.0;
  double _oscFreq = 0.0;
  double _oscPhase = 0.0;


  int computeShiftedFrequency(int shift) {
    if (!periodToNoteTable.containsKey(samplePeriod)) {
      return (samplePeriod + shift * 20);
    }
    int note = periodToNoteTable[samplePeriod];
    return periodTable[note + shift];
  }

  // ---------------

  Mod _targetMod;
  int _previousSamplePeriod = -1;
  int _samplePeriod = -1;
  Float32List __changeCurve = null;
  int _sampleNumber = -1;
}

