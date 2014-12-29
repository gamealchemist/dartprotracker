/// library that provides noteOn, noteOff, noteGrainOn function that also keep alive the played AudioBufferSource
/// (keeping alive == preventing from garbage collection by keeping the item in a List (until it's finished playing)
library AliveNoteOn;

import 'keepalivebuffer.dart';
import "dart:web_audio";

typedef void noteSetter(AudioBufferSourceNode which, double when);
typedef void noteGrainSetter(AudioBufferSourceNode which, double when,
    double offset);

/// Performs a noteOn on the provided AudioBufferSourceNode, and keeps it alive.
noteSetter noteOn = null;

/// Performs a noteOff on the provided AudioBufferSourceNode.
noteSetter noteOff = null;

/// Performs a noteOn on the provided AudioBufferSourceNode, and keeps it alive.
noteGrainSetter noteGrainOn = null;

bool _polyfilled = false;

void polyFillContext(AudioContext context) {
  if (_polyfilled) return;
  AudioBufferSourceNode abs = context.createBufferSource();

  noteOn = (AudioBufferSourceNode which, double when) {
    which.start(when);
    //  which.noteOn(when);
    keepAliveBuffer.add(which, when);
  };
  noteOff = (AudioBufferSourceNode which, double when) {
    which.stop(when);
  };
  noteGrainOn = (AudioBufferSourceNode which, double when, double offset) {
    which.start(when, offset, (which.buffer.duration - offset));
    keepAliveBuffer.add(which, when);
  };
}

