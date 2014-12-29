library ChannelCollectionNode;

import '../modplayer/mod.dart';
import '../modplayer/channel.dart';
import "dart:web_audio";

import 'baseclass/simpleaudionode.dart';

/// SimpleAudioNode handling a collection of ChannelNode.
///   this node has no ancestors.
class ChannelCollectionNode extends SimpleAudioNode {

  ChannelCollectionNode(Mod this._targetMod, SimpleAudioNode channelTargetNode,
      [bool connectNow = false])
      : super('channel collection', channelTargetNode, connectNow);

  int get channelCount => (channels == null) ? 0 : channels.length;

  @override
  void buildThisNode() {
    int _channelCount = _targetMod.channelCount;
    leftGainNode = context.createGain();
    rightGainNode = context.createGain();
    _chanelMergerNode = context.createChannelMerger(2);
    leftGainNode.channelCountMode = 'explicit';
    leftGainNode.channelCount = 1;
    rightGainNode.channelCountMode = 'explicit';
    rightGainNode.channelCount = 1;
    leftGainNode.connectNode(_chanelMergerNode, 0, 0);
    rightGainNode.connectNode(_chanelMergerNode, 0, 1);
    destination = null;
    lastNode = _chanelMergerNode;
    for (int i = channels.length; i < _channelCount; i++) {
      channels.add(new Channel(_targetMod, this, i));
    }
  }

  @override
  SimpleAudioNode buildAncestorNode() {
    return null;
  }

  @override
  void resetThisNode(when) {
    channels.forEach((ch) => ch.channelNode.reset(when));
  }

  @override
  void disposeThisNode() {
    channels.forEach((ch) => ch.channelNode.dispose());
  }

  @override
  void connect() {
    channels.forEach((ch) => ch.channelNode.connect());
    connectedBackingField = false;
    AudioNode targetAudioNode =
        (targetNode is AudioNode || targetNode is GainNode) ?
            targetNode :
            targetNode.destination;
    lastNode.connectNode(targetAudioNode);
    connectedBackingField = true;
  }

  @override
  void disconnect() {
    channels.forEach((ch) => ch.channelNode.disconnect());
  }


  ChannelMergerNode _chanelMergerNode = null;
  GainNode leftGainNode = null;
  GainNode rightGainNode = null;

  final Mod _targetMod;

  final List<Channel> channels = new List<Channel>();

}

