library ModPartitionReaderLib;

import 'modinformations.dart';
import '../toolclasses/tables.dart';
import '../toolclasses/sample.dart';
import '../audiosetup/modaudionode.dart';
import 'channel.dart';

import 'dart:async';
import "dart:web_audio";
import "dart:typed_data";

/// parser and reader for a mod file.
///   Core logic of the Mod object. The webAudio rendering is done by the ModAudioNode.
class ModPartitionReader {

  ModPartitionReader(AudioContext this._context, Uint8List buffer) {
    _parse(buffer);
  }

  ModAudioNode modAudioNode = null;

  ModInformations get modInformations => _modInformations;

  void play() {
    if (_playing && !songEnded) {
      resume();
      return;
    }
    _playing = true;
    modAudioNode.connect();
    initializeforPlaying();
    _startTimer();
  }

// pause playback
  void pause() {
    if (!_paused) {
      _paused = true;
    } else {
      _paused = false;
    }
  }

  void resume() {
    if (!_playing) return;
    _paused = false;
  }

/// stop playback and release webaudio node
  void stop(double when) {
    _playing = false;
    modAudioNode.reset(when);
    _stopTimer();
  }

  /// are we currently playing the mod ?
  bool get playing => _playing;

  /// use play / pause / stop method.

      /// Rq1 : calling play on a paused song will resume it. Rq2 :  paused song uses very little resources.
  bool get paused => _paused;

  /// should we repeat this song ?

      /// (initialy set to the default song setting, might be changed by song during play)
  bool repeat = false;

  double get perTickTime => perLineTime / ticksPerLine__speed;

  bool _paused = false;
  double _volume = 1.0;
  /// timer that will call the partition reader every [timePeriod]
  Timer _playTimer = null;


      /// every [timerPeriod], ensure that we are [timerPeriod] + [timerSecurityTime] ahead
  Duration timerPeriod = new Duration(milliseconds: 250);


      /// every [timerPeriod], ensure that we are [timerPeriod] + [timerSecurityTime] ahead
  Duration timerSecurityTime = new Duration(milliseconds: 250);

  double aheadTime = 0.0;
  double lastContextTime_readCall = 0.0;
  double perLineTime = 0.0;

  void _startTimer() {
    if (_paused || !_playing) return;
    _playTimer = new Timer.periodic(timerPeriod, __readPartition);
    aheadTime = 0.0;
    //     lastReadPartitionCallTime = context.currentTime;
    _readPartition();
  }

  void _stopTimer() {
    if (_playTimer == null) return;
    _playTimer.cancel();
    _playTimer = null;
  }

  void __readPartition(Timer timer) {
    _readPartition();
  }

  /// speed : number of ticks per line
  int ticksPerLine__speed = 6;
  int currentBpm = 125;

  double tickDuration = 0.0;

  int currentPatternPartitionIndex = 0;

  int currentPatternIndex = 0;
  Uint32List currentPattern = null;

  int currentRow = 0;

  int offset = 0;
  int flags = 0;

  int breakrow = 0;

  int looprow = 0;

  int loopstart = 0;
  int loopEnd = 0;
  int loopcount = 0;

  int patternDelay = 0;
  int patternWait = 0;

  int _songEndJump = 0;
  int _channelCount = 4;
  int _songPatternCount = 1;
  int _maxPatternIndex = 1;

  Uint8List patternTable = null;
  List<Sample> sampleTable = null;
  /// first index is mod pattern index, second is [line*channelCount+ch]
  List<Uint32List> patternsData = null;

  bool songEnded = false;

  void _readPartition() {

    if (songEnded || !_playing || _paused) return;
    // 1 recompute time 2 update pattern
    int commandFlags = 0;
    double readStartTime = _context.currentTime;
    // keepAliveBuffer.clearOutdated(readStartTime);
    double timeElapsed = readStartTime - lastContextTime_readCall;
    // typically == timerPeriod +- small delta ( < 14 ms typ. )
    aheadTime -= timeElapsed;
    if (aheadTime <
        0.0) { // if we just started, paused or switched position, buffer is like empty.
      aheadTime = 0.0;
      lastContextTime_readCall = readStartTime;
      timeElapsed = 0.0;
    }
    double baseTime = lastContextTime_readCall + timeElapsed;
    // compute target time
    double currentAheadTime = aheadTime;
    double targetAheadTime =
        1e-3 *
        (timerPeriod.inMilliseconds + timerSecurityTime.inMilliseconds);

    //
    perLineTime = (48 / 44) * ticksPerLine__speed / (0.4 * currentBpm);

    //
    int offsetWithinPattern = currentRow * _channelCount;
    int positionJump = -1;
    int linePosAfterPatternBreak = -1;
    int setSpeedBpm = -1;
    int setSpeedTick = -1;
    int patternDelay = -1;
    bool effectIsModCommand;
    bool oneEveryTwo = true;
    List<Channel> channels = modAudioNode.channelCollection.channels;

    do {
      // process current line
      bool oneChannelNeedsUpdate = false;
      for (int ch = 0; ch < _channelCount; ch++) {
        int thisFullNote = currentPattern[offsetWithinPattern + ch];
        if (thisFullNote == 0) continue;

        int effect = ((thisFullNote & 0x000F0000) >> 16);
        int arg_x = ((thisFullNote & 0xF0000000) >> 28);
        int arg_y = ((thisFullNote & 0x0F000000) >> 24);
        int arg_x_y = ((thisFullNote & 0xFF000000) >> 24);

        effectIsModCommand = (effect != 0); // can be command only if non null

        if (effectIsModCommand) {
          switch (effect) {
            case ModCommand.positionJump:
              positionJump = (arg_x_y >= _songPatternCount) ? 0 : arg_x_y;
              break;
            case ModCommand.patternBreak:
              linePosAfterPatternBreak = 10 * arg_y + arg_x;
              break;
            case ModCommand.setSpeed:
              if (arg_x_y & 0xFE00 == 0) setSpeedTick =
                  arg_x_y; else setSpeedBpm = arg_x_y;
              break;
            case ModCommand.loopPattern:
              if (arg_y == 0) loopstart =
                  currentRow; else if (loopcount == -1) {
                loopEnd = currentRow;
                if (loopstart == -1) loopstart = 0;
                loopcount = arg_y;
              }
              break;
            case ModCommand.patternDelay:
              patternDelay = arg_y;
              break;
            default:
              effectIsModCommand = false;
              break;
          }
        }

        Channel thisChannel = channels[ch];
        Sample thisSample = null;

        int sample_period = getSamplePeriod(thisFullNote);
        if (sample_period != 0) {
          // Is it an immediate or a delayed period change ?
          if (effect == 0x3 || effect == 0x5) // delayed
          thisChannel.targetPeriod = sample_period; else // immediate
          thisChannel.samplePeriod = sample_period;
        }

        int sample_number = getSampleNumber(thisFullNote);

        if (sample_number != 0) thisChannel.sampleNumber = sample_number;


            // It is not an effect if it is a command or if effect + effect args are null.
        if (effectIsModCommand || (effect == 0 && arg_x_y == 0)) thisChannel.effectNumber =
            -1; else // otherwise it is an effect
        thisChannel
            ..effectNumber = effect
            ..argX = arg_x
            ..argY = arg_y
            ..argXY = arg_x_y;
        oneChannelNeedsUpdate =
            oneChannelNeedsUpdate || thisChannel.requirePlayEffect;
      } // end of loop on channels

      // update the speed if there was a change in speed
      if (setSpeedTick != -1 || setSpeedBpm != -1) {
        if (setSpeedTick == 0) { // new speed is null => stop song
          stop(baseTime + currentAheadTime);
          return;
        }
        if (setSpeedTick != -1) ticksPerLine__speed = setSpeedTick;
        if (setSpeedBpm != -1) currentBpm = setSpeedBpm;
        perLineTime = /* ( 48/44 ) */ ticksPerLine__speed / (0.4 * currentBpm);
        setSpeedTick = -1;
        setSpeedBpm = -1;
      }
      currentRow++;
      offsetWithinPattern += _channelCount;

      // make channels play effect
      if (oneChannelNeedsUpdate) {
        for (Channel thisChannel in channels) {
          if (thisChannel.requirePlayEffect) thisChannel.playEffect(
              baseTime + currentAheadTime);
        }
      }

      // update position
      bool prepareForNewPattern = false;

      // handle B : position jump
      if (positionJump != -1) {
        currentPatternPartitionIndex = positionJump;
        if (currentPatternPartitionIndex >= _songPatternCount) songEnded = true;
        prepareForNewPattern = true;
        positionJump = -1;
        currentRow = 0;
      }

      // 0xD = pattern break  ( or last row )
      // handle end of current pattern / jump to no<here
      if (currentRow == 64 || linePosAfterPatternBreak != -1) {
        currentPatternPartitionIndex++;
        if (currentPatternPartitionIndex >= _songPatternCount) {
          if (_songEndJump != -1) { // loop if need be
            if (_songEndJump >= _songPatternCount) songEnded = true;
            currentPatternPartitionIndex = _songEndJump;
          }
          songEnded = true;
        }
        prepareForNewPattern = true;
      }

      if (currentPatternPartitionIndex >= patternTable.length) {
        songEnded = true;
      }

      if (!songEnded && prepareForNewPattern) {
        currentPatternIndex = patternTable[currentPatternPartitionIndex];
        currentPattern = patternsData[currentPatternIndex];
        currentRow =
            (linePosAfterPatternBreak == -1) ? 0 : linePosAfterPatternBreak;
        offsetWithinPattern =
            (currentRow == 0) ? 0 : currentRow * _channelCount;
        linePosAfterPatternBreak = -1;
      }
      // advance time
      if (patternDelay != -1) {
        currentAheadTime += perLineTime * patternDelay;
        patternDelay = -1;
      } else currentAheadTime += perLineTime;

    } while (!songEnded &&
        currentAheadTime <
            targetAheadTime); // keep on reading until we're enough ahead of target time

    if (songEnded) {
      stop(baseTime + currentAheadTime + perLineTime);
    }
    aheadTime = currentAheadTime - (_context.currentTime - readStartTime);
    lastContextTime_readCall = readStartTime;
  }

  // resets before playing
  void initializeforPlaying() {
    songEnded = false;
    currentBpm = _modInformations.initialBpm;
    ticksPerLine__speed = 6;
    currentPatternPartitionIndex = 0;
    currentPatternIndex = patternTable[currentPatternPartitionIndex];
    currentPattern = patternsData[currentPatternIndex];
    currentRow = 0;
    loopcount = 0;
    offset = 0;
    flags = 0;
    breakrow = 0;
    _channelCount = _modInformations.channelCount;
  }


// parse the module from local buffer
  bool _parse(Uint8List buffer) {
    _modInformations = new ModInformations(buffer);
    _songPatternCount = _modInformations.songPatternCount;
    _channelCount = _modInformations.channelCount;
    _songEndJump = _modInformations.songEndJump;

    int channelCount = _modInformations.channelCount;

    // ----  retrieve samples information ----
    sampleTable = new List<Sample>(sampleCount);
    int sampleTotalLength = 0;
    for (int i = 0; i < sampleCount; i++) {
      var st = 20 + i * 30;
      var thisSample = new Sample();
      thisSample.parseInformations(new Uint8List.view(buffer.buffer, st, 30));
      sampleTotalLength += thisSample.length;
      sampleTable[i] = thisSample;
    }

    // -- pattern table (== pattern partition)--
    patternTable = new Uint8List(_songPatternCount);
    Set<int> usedPattern = new Set<int>();
    for (int i = 0; i < _songPatternCount; i++) {
      patternTable[i] = buffer[952 + i];
      if (patternTable[i] > _maxPatternIndex) _maxPatternIndex =
          patternTable[i];
      usedPattern.add(patternTable[i]);
    }
    _modInformations.modPatternCount = _maxPatternIndex + 1;

    int patlen = 4 * 64 * channelCount;
    // -- patterns --
    patternsData = new List<Uint32List>(_maxPatternIndex + 2);
    Uint32List bufferView32 = new Uint32List.view(
        buffer.buffer,
        1084,
        ((_maxPatternIndex + 2) * patlen) >> 2);
    for (int pat = 0; pat <= _maxPatternIndex; pat++) {
      if (usedPattern.contains(pat)) {
        Uint32List thisPattern = new Uint32List(patlen);
        thisPattern.setRange(0, patlen >> 2, bufferView32, (pat * patlen) >> 2);
        patternsData[pat] = thisPattern;
      }
    }

    int sst = buffer.lengthInBytes - sampleTotalLength;
    // 1084+ ( _maxPatternIndex +1)*patlen;
    int lsum = 0;
    for (Sample thisSample in sampleTable) {

      int clampedLength = thisSample.length;
      lsum += clampedLength;
      if (sst + thisSample.length >= buffer.length) {
        clampedLength = buffer.length - sst;
      }
      if (thisSample.length != 0) thisSample.parseData(_context, new Uint8List.view(buffer.buffer, sst, clampedLength)); else thisSample.audioBuffers =
          null;
      sst += clampedLength;
    }
  }

  // *** playback properties

  ModInformations _modInformations = null;

  bool _playing = false;

  final AudioContext _context;

}

const int sampleCount = 31;
