library ModAudioNode;

import "dart:web_audio";

import '../modplayer/mod.dart';
import 'channelcollectionnode.dart';
import 'baseclass/simpleaudionode.dart';
import '../toolclasses/webaudiohelper.dart';

class ModAudioNode extends SimpleAudioNode {

  ModAudioNode(Mod targetMod, AudioNode destinationNode, [bool connectNow =
      false])
      : _targetMod = targetMod,
        super('mod', destinationNode, connectNow) {
  }

  @override
  void buildThisNode() {
    if (context == null) return;
    // build low pass  filter
    _lowPassNode = context.createBiquadFilter();
    _lowPassNode.type = 'allpass';
    _lowPassNode.frequency.value = 28867;
    // build gain node
    _modGainNode = context.createGain();
    // connect
    chainConnect([_lowPassNode, _modGainNode]);
    //
    destination = _lowPassNode;
    lastNode = _modGainNode;
  }

  @override
  SimpleAudioNode buildAncestorNode() {
    channelCollection = new ChannelCollectionNode(_targetMod, this);
    return channelCollection;
  }

  @override
  void resetThisNode(double when) {
    // TODO: implement resetNode
    // == reset the gain / lowpass nodes.
  }

  @override
  void disposeThisNode() {
    disconnectAll([_modGainNode, _lowPassNode]);
    _modGainNode = null;
    _lowPassNode = null;
  }

  final Mod _targetMod;

  ChannelCollectionNode channelCollection = null;

  /// low pass filter for this nod.
  /// Notice the filter is an allpass by default.
  BiquadFilterNode _lowPassNode = null;

  /// gain node to handle volume for this mod.
  GainNode _modGainNode = null;
}
