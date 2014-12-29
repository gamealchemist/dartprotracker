library Mod;

import "dart:html";
import "dart:web_audio";
import "dart:typed_data";

import '../audiosetup/modaudionode.dart';
import 'modpartitionreader.dart';
import '../toolclasses/sample.dart';
import 'modinformations.dart';
import '../toolclasses/tables.dart';


typedef void ParamCallback([dynamic param]);

/// Mod : exposes properties and method allowing to load
///        and play an AMIGA Mod file on a webaudio context.
class Mod {

/// Builds a new mod, and loads it.
///   [srcOrBuffer] : if it's is a string, it is assumed to be an URL and to trigger a load.
///                         If it's a [ByteBuffer], it is assumed to be the binary content of a valid mod file.
///   if [willAutoStart], the mod starts playing right after the load.
///   [newOnload] is a callBack called after the load.
  Mod(srcOrBuffer, AudioContext this._context, [ AudioNode __destinationNode = null,
      bool willAutoStart = false, ParamCallback newOnload = null]) {
    _autostart = willAutoStart;
    _onLoad = newOnload;
    _contextSampleRateAdjuster = 44100 / _context.sampleRate;
    if (__destinationNode == null) __destinationNode = _context.destination;
    _destinationNode = __destinationNode;
    init_tables();
    if (srcOrBuffer is ByteBuffer) {
      _loadFromBuffer(srcOrBuffer);
    } else if (srcOrBuffer is String) {
      _src = srcOrBuffer;
      _load(_src);
    } else {
      throw ('srcOrBuffer must be either an url string or a ByteBuffer');
    }
  }

  bool get ready => _fileLoadedAndParsed;

  /// webaudio context used to play this mod.
  AudioContext get context => _context;

   /// webaudio destination node for this mod. (might be context.destination if no destination node provided in constructor.)
  AudioNode get destinationNode => _destinationNode;

  /// all informations available on this mod.
  ///   (use [getDescription] to have title + instrument names in a single string.)
  ModInformations get modInformations => _modPartitionReader.modInformations;

  /// number of Channels for this mod. 
  /// ( Most often 4, might be 8, 16 unseen/untested) )
  int get channelCount => modInformations.channelCount;

  /// all samples for this mod.
  ///   Only 31 samples mods are supported.
  List<Sample> get sampleTable => _modPartitionReader.sampleTable;

  /// url of this mod
  String get src => _src;

  /// called when mod is ready to play.
  ParamCallback _onLoad = null;

  String getDescription() {
    String res = '${modInformations.title} \n ---------------------- \n';
    for (int i = 0; i <
        31; i++) if (sampleTable[i].name.length >=
            2) res += 'instr. $i: ${sampleTable[i].name} \n';
    return res;
  }

  double get perTickTime => _modPartitionReader.perTickTime;

  double get perLineTime => _modPartitionReader.perLineTime;

  int get ticksPerLine__speed => _modPartitionReader.ticksPerLine__speed;

  /// releases all (memory and audio) resources of this object.
  void dispose() {
    _modAudioNode.dispose();
  }

  //*****************************************************
  // ****                       player
  //*****************************************************

  /// are we currently playing the mod ?
  ///   (true if we paused, false if we stopped)
  bool get playing => _modPartitionReader.playing;

  /// Rq1 : calling play on a paused song will resume it. Rq2 :  paused song uses very little resources.
  bool get paused => _modPartitionReader.paused;

  void play() {
    _modPartitionReader.play();
  }

  void pause() {
    _modPartitionReader.pause();
  }

  void resume() {
    _modPartitionReader.resume();
  }

/// stop playback and release webaudio node
  void stop(double when) {
    _modPartitionReader.stop(when);
  }

// load module from url into local buffer
  void _load(url) {
    HttpRequest request = new HttpRequest();
    request.open("GET", url);
    request.responseType = "arraybuffer";
    request.onLoad.listen((ProgressEvent e) {
      _loadFromBuffer(request.response);
    });
    request.send();
  }

  void _loadFromBuffer(ByteBuffer b) {
    _modPartitionReader =
        new ModPartitionReader(_context, new Uint8List.view(b));
    _modAudioNode = new ModAudioNode(this, _destinationNode, false);
    _modPartitionReader.modAudioNode = _modAudioNode;
    _fileLoadedAndParsed = true;
    if (_onLoad != null) _onLoad(this);
    if (_autostart) play();
  }
  
// -------------------------------------------------------------
  
  ModPartitionReader _modPartitionReader = null;

  final AudioContext _context;

  ModAudioNode _modAudioNode = null;

  AudioNode _destinationNode;

  num _contextSampleRateAdjuster = 1.0;

  String _src = null;
  bool _fileLoadedAndParsed = false;
  bool _playing = false;
  String _title = null;
  bool _autostart = false;

}
