library KeepAliveBuffer;

import "dart:web_audio";

final DelayedDisposalHandler keepAliveBuffer = new DelayedDisposalHandler();

/// This class is here to avoid a bug that would recollect
/// too early the webaudio objects ( some AudioBufferSource)
/// So we just keep a reference to them until they finished playing.
class DelayedDisposalHandler {

  // ordered list of things to dispose
  List<_DisposeMeLater> toBeDisposed = new List<_DisposeMeLater>();

  /// signal that this ABS will have to be disposed
  void add(AudioBufferSourceNode what, double when) {
    _DisposeMeLater dml = new _DisposeMeLater(what, when);
    int ind = toBeDisposed.length;
    if (ind == 0) toBeDisposed.add(dml); else {
      // sorted insert
      while (ind > 0 && when < toBeDisposed[ind - 1].when) ind--;
      toBeDisposed.insert(ind, dml);
    }
  }

  /// clear the no-longer in use ABS. use the real context time.
  void clearOutdated(double now) {
    now -= 2.0;
    int lastOutdatedIndex = -1;
    int i = 0;
    while (i < toBeDisposed.length) {
      _DisposeMeLater thisOne = toBeDisposed[i];
      if (now <= thisOne.when) break;
      thisOne.what = null;
      i++;
    }
    if (i != 0) toBeDisposed.removeRange(0, i);
  }
}

class _DisposeMeLater {
  _DisposeMeLater(this.what, this.when);
  AudioBufferSourceNode what;
  double when;
}

