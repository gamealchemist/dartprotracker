library WavFile;
import 'dart:html';

import "dart:web_audio";
import "dart:typed_data";

typedef void voidFunc();

/// allows to load and play in webAudio a .wav file.
/// hook onload then set the src to use it.
class WaveFile {

  /// url of this mod
  String get src => _src;
  /// set the url to trigger a load.
  /// hook onload before setting the url if need be.
  void set src(String newUrl) {
    _src = newUrl;
    _load(_src);
  }


  AudioBuffer get audioBuffer => _audioBuffer;

  voidFunc onLoad = null;

  // load module from url into local buffer
  void _load(url) {
    HttpRequest request = new HttpRequest();
    request.open("GET", url);
    request.responseType = "arraybuffer";
    request.onLoad.listen((ProgressEvent e) {
      AudioContext context = new AudioContext();
      context.decodeAudioData(request.response).then((AudioBuffer wave) {
        _audioBuffer = wave;
        if (onLoad != null) onLoad();
      });
    });
    request.send();
  }

  String _src = null;
  AudioBuffer _audioBuffer = null;

}

/// builds a wav buffer out of the samples.
/// if samples are 8-bit, converts to 16 bits by just << 8 the values.
Uint8List buildWave(Uint8List samples, int bitDepth, [int frequency = 44100,
    int channelCount = 2, bool convert8To16 = false]) {
  int targetBitDepth = bitDepth;
  int targetSampleBufferSize = samples.lengthInBytes;

  if (convert8To16 && bitDepth == 8) {
    targetBitDepth = 16;
    targetSampleBufferSize *= 2;
  }
  int fileSize = 44 + targetSampleBufferSize;
  Uint8List res = new Uint8List(fileSize);



      // http://fr.wikipedia.org/wiki/WAVEform_audio_format  (more complete than english version)
  // ____ File declaration block
  // FileTypeBlocID  = "RIFF"
  write32_bigEndian(res, 0, 0x52494646);
  // ChunkSize  ( fileSize - 8 )
  int ChunkSize = fileSize - 8; // remaining size after this field.
  write32_littleEndian(res, 4, ChunkSize);
  // FileFormatID = "WAVE"
  write32_bigEndian(res, 8, 0x57415645);
  // ____ Audio format block
  // FormatBlocId = "fmt "  (with the " " )
  write32_bigEndian(res, 12, 0x666d7420);
  // BlocSize = 16
  write32_littleEndian(res, 16, 16);
  // AudioFormat = 1 = pcm format
  write16_littleEndian(res, 20, 1);
  // Canal Count = 2 = stereo
  write16_littleEndian(res, 22, channelCount);
  // Frequency
  write32_littleEndian(res, 24, frequency);
  int BitsPerSample = targetBitDepth;
  int BytePerBlock = (channelCount * BitsPerSample) >> 3; //  ( >> 3 == / 8 )
  int bytePerSec = frequency * BytePerBlock;
  // BytePerSec
  write32_littleEndian(res, 28, bytePerSec);
  // BytePerBlock
  write16_littleEndian(res, 32, BytePerBlock);
  // BitsPerSample
  write16_littleEndian(res, 34, BitsPerSample);
  // ____ Data Bloc
  // DataBlocID = "data"
  write32_bigEndian(res, 36, 0x64617461);
  // DataSize
  write32_littleEndian(res, 40, targetSampleBufferSize);
  print(' tg b s $targetSampleBufferSize ');
  print('length in by ${samples.lengthInBytes}');
  print(0x4B52);
  // __ copy actual samples
  if (convert8To16 && bitDepth == 8) for (int i =
      0; i < samples.lengthInBytes; i++) {
    int si = samples[i];
    res[44 + (i << 1)] = (si >= 128) ? 0xFF : 0;
    res[44 + (i << 1) + 1] = (si < 128) ? si : (256 - si);
  } else for (int i = 0; i < samples.lengthInBytes; i++) {
    int si = samples[i];
    res[44 + i] = (si < 128) ? 128 + si : (si - 128);
  }
//          res.setRange(44, 44 + targetSampleBufferSize , samples); // use Uint8Array.set on a res view in javascript.
  return res;
}

void write32_bigEndian(Uint8List buffer, int offset, int value) {
  buffer[offset] = (value & 0xFF000000) >> 24;
  buffer[offset + 1] = (value & 0x00FF0000) >> 16;
  buffer[offset + 2] = (value & 0xFF00) >> 8;
  buffer[offset + 3] = (value & 0xFF);
}


void write32_littleEndian(Uint8List buffer, int offset, int value) {
  buffer[offset] = (value & 0xFF);
  buffer[offset + 1] = (value & 0xFF00) >> 8;
  buffer[offset + 2] = (value & 0x00FF0000) >> 16;
  buffer[offset + 3] = (value & 0xFF000000) >> 24;
}

void write16_littleEndian(Uint8List buffer, int offset, int value) {
  buffer[offset] = (value & 0xFF);
  buffer[offset + 1] = (value & 0xFF00) >> 8;
}
