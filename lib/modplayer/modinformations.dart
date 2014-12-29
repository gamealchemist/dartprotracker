library ModInformations;

import "dart:convert";
import "dart:typed_data";

import '../toolclasses/tables.dart';

/// container and parser for informations about an Amiga .mod file
class ModInformations {

  ModInformations(Uint8List buffer) {
    _parseInformations(buffer);
  }

  /// Song title. 20 characters max.
  String get title => _title;
  /// File sub-type. Describes the number of channels.
  ///      see Tables / formatTable for details.
  String get signature => _signature;
  /// Number of patterns index in the pattern partition.
  int get songPatternCount => _songPatternCount;
  /// Number of patterns in the pattern bank.
  int modPatternCount;
  /// Number of channels for this mod.
  ///    Might be 4, 8, 16, 24, depending on [signature].
  int get channelCount => _channelCount;
  /// initial bpm for a song. Always 125.
  int get initialBpm => 125;
  // -- repeat pos --
  int get songEndJump => _songEndJump;

  // parse the module from local buffer
  void _parseInformations(Uint8List buffer) {
    if (buffer == null) return;
    // Check if file is compiled (not supported).
    for (int i = 0; i < 4; i++) _powerPackerArray[i] = buffer[i];
    String first4Bytes = _asciiDecoder.convert(_powerPackerArray);
    if (first4Bytes == "PP20") {
      throw ('PowerPack compiled mod files are not supported.');
    }
    // ----  retrieve signature  ----
    for (int i = 0; i < 4; i++) _signatureArray[i] = buffer[1080 + i];
    _signature = _asciiDecoder.convert(_signatureArray);
    // -- how many channels for this signature ?
    //    silent fail : assume 4 channels if signature unknown.
    if (formatTable.containsKey(signature) == false) _channelCount =
        4; else _channelCount = formatTable[signature];
    // ----  retrieve title  ----
    int i = 0;
    while (buffer[i] != 0 && i < 20) {
      _titleArray[i] = buffer[i];
      i++;
    }
    while (i < 20) _titleArray[i++] = 0;
    _title = _asciiDecoder.convert(_titleArray);
    // -- song length --
    _songPatternCount = buffer[950];

    if (buffer[951] < 127) _songEndJump = buffer[951];

  }

  String _title = null;
  String _signature = null;
  int _songPatternCount = 1;
  int _channelCount = 4;
  int _songEndJump = -1;

}

final AsciiDecoder _asciiDecoder = new AsciiDecoder();
final Uint8List _signatureArray = new Uint8List(4);
final Uint8List _titleArray = new Uint8List(20);
final Uint8List _powerPackerArray = new Uint8List(4);

