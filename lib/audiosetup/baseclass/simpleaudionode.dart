library SimpleAudioNode;

import "dart:web_audio";
import '../../toolclasses/webaudiohelper.dart';

/// Abstract class defining the common functions of a simple audio node that is part of an audio graph.
///  buildNode build the actual webAudio nodes of this node, then buildAncestorNode must build the ancestor,
///     which will get connected either in the constructor or when connect() is called.
///     call dispose() on the root node to ensure all allocated resources up the audio graph are disposed.
///   Inheriting classes : ChannelCollectionNode, ChannelNode,ModAudioNode, MasteringNode
abstract class SimpleAudioNode {

  /// Constructor for a node that will connect to targetNode.


      /// Connexion is either performed now, if [connectNow], or later by calling [connect].
  /// After this node is built, builds the ancestor node
  SimpleAudioNode(String this.nodeName, dynamic this.targetNode,
      [bool connectNow = false]) {
    if (targetNode == null) throw ('target cannot be null');
    buildThisNode();
    ancestorNode = buildAncestorNode();
    if (connectNow) connect();
  }

  /// mustOverride. Should be a protected method.
  /// buildNode should :


      ///    • build and store the actual webAudio nodes used by this SimpleAudioNode.
  ///    • set destination (=the target of the previous node),
  ///    • set lastNode (the node that we connect to the next node)
  ///    • *not* connect anything.
  ///    called in constructor.
  void buildThisNode();

  /// mustOverride. Should be a protected method.
  /// buildAncestorNode should
  ///    • build and return the ancestor node.
  ///    • *not* connect anything
  ///  called in constructor.
  SimpleAudioNode buildAncestorNode();

  /// mustOverride . Should be a protected method.
  /// resets this node into the same state as when freshly built.
  /// see [reset]
  void resetThisNode(double when);

  /// mustOverride . Should be a protected method.
  /// dispose this node so it does not use any more resources.
  /// see [dispose]
  void disposeThisNode();



      /// Connects this node to its target, and its ancestor(s) to this node up the tree.
  void connect() {
    if (ancestorNode != null) ancestorNode.connect();
    if (connectedBackingField) return;
    connectedBackingField = false;
    AudioNode targetAudioNode =
        (targetNode is AudioDestinationNode || targetNode is GainNode) ?
            targetNode :
            targetNode.destination;
    lastNode.connectNode(targetAudioNode);
    connectedBackingField = true;
  }

  /// resets this node and its ancestor(s) node up the tree.
  void reset(double when) {
    if (ancestorNode != null) ancestorNode.reset(when);
    resetThisNode(when);
  }



      /// disconnects this node from its target, and its disconnect its ancestor(s) up the tree.
  void disconnect() {
    if (ancestorNode != null) ancestorNode.disconnect();
    if (!connectedBackingField) return;
    lastNode.disconnect(0);
    connectedBackingField = false;
  }

  /// dispose this node and its ancestor(s) node up the tree.
  void dispose() {
    if (_disposed) return;
    disconnect();
    if (ancestorNode != null) ancestorNode.dispose();
    disposeThisNode();
    ancestorNode = null;
    destination = null;
    lastNode = null;
    targetNode = null;
    _disposed = true;
  }


  // ------------------------------------------------
  // **** Nodes properties

  /// ancestor of this node in the audio chain.
  /// nullable (null for root nodes).
  /// Should be protected.
  SimpleAudioNode ancestorNode = null;

  /// this node is where we the ancestor should connect.
  /// Should be protected.
  AudioNode destination = null;

  /// last audio node of this object. will connect to its targetNode.
  /// != null
  /// Should be protected.
  AudioNode lastNode;



      /// Audio node to  which this node should connect. type can be AudioNode or SimpleAudioNode
  /// non nullable
  /// Should be protected.
  dynamic targetNode;

  // ------------------------------------------------

  // ------------------------------------------------
  // **** Helper properties

  /// name of this node, for debugging purposes only.
  /// set in constuctor.
  final String nodeName;

  /// helper to get the root AudioContext for any SimpleAudioNode.
  AudioContext get context => targetNode.context;

  /// are we connected an output Node ?
  bool get connected => connectedBackingField;

  /// did we dispose of this node ?
  bool get disposed => _disposed;

  // ------------------------------------------------

  bool connectedBackingField = false;
  bool _disposed = false;
}
