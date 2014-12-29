library WebaudioHelper;

import "dart:web_audio";
import 'dart:typed_data';
import "dart:math";
import 'dart:html';
import 'dart:async';


void chainConnect(List<AudioNode> nodes) {
  for (int i = 0; i <= nodes.length - 2; i++) {
    nodes[i].connectNode(nodes[i + 1]);
  }
}

void disconnectAll(List<AudioNode> nodes) {
  for (AudioNode an in nodes) if (an != null) an.disconnect(0);
}


AudioBuffer buildWhiteNoise(AudioContext context, int length_ms, [double amp =
    0.2]) {
  AudioBuffer res = context.createBuffer(
      2,
      (context.sampleRate * length_ms * 1e-3).floor(),
      context.sampleRate);
  Float32List left = res.getChannelData(0);
  Float32List right = res.getChannelData(1);
  var rnd = new Random();

  for (int i = 0; i < left.length; i++) {
    left[i] = 2 * (rnd.nextDouble() - 0.5) * amp;
    right[i] = 2 * (rnd.nextDouble() - 0.5) * amp;
  }
  return res;
}

bool _awoken = false;


void wakeUpSafari() {
  if (_awoken) return;

  StreamSubscription<TouchEvent> _tS, _tM, _tE;
  StreamSubscription<MouseEvent> _mU, _mM;
  StreamSubscription<KeyEvent> _kD;

  void _stopMousevsTouchRace() {
  }

  void end(e) {
    _tS.cancel();
    _tM.cancel();
    _tE.cancel();

    _mU.cancel();
    _mM.cancel();
    _kD.cancel();

  }

  _tS = window.onTouchStart.listen(end);
  _tM = window.onTouchMove.listen(end);
  _tE = window.onTouchEnd.listen(end);

  _mU = window.onMouseUp.listen(end);
  _mM = window.onMouseMove.listen(end);

  _kD = window.onKeyDown.listen(end);

}
/*
function equalPowerCrossfade(percent) {
  // Use an equal-power crossfading curve:
  var gain1 = Math.cos(percent * 0.5*Math.PI);
  var gain2 = Math.cos((1.0 - percent) * 0.5*Math.PI);
  this.ctl1.gainNode.gain.value = gain1;
  this.ctl2.gainNode.gain.value = gain2;
}
*/
