// THE ONE DOOR TO THE CLOUD MODEL. Everything that asks a cloud model for
// something (the conversation, grounded search, speech, the transcription
// fallback) goes through a [ModelPort], so tests can hand the modules a
// fake and nothing in a unit test touches the network. The request and
// reply types come from firebase_ai, which is only the wire format here.
import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

import 'server_model_port.dart';

/// One request: which model, what it is told, and the conversation.
class ModelRequest {
  const ModelRequest({
    required this.model,
    required this.contents,
    this.system,
    this.tools,
    this.toolConfig,
    this.generationConfig,
  });

  final String model;
  final List<Content> contents;

  /// The system instruction (none when null or empty).
  final String? system;
  final List<Tool>? tools;
  final ToolConfig? toolConfig;
  final GenerationConfig? generationConfig;
}

abstract interface class ModelPort {
  /// The reply as it is generated.
  Stream<GenerateContentResponse> stream(ModelRequest request);

  /// The whole reply at once (transcription).
  Future<GenerateContentResponse> generate(ModelRequest request);

  /// Gets the tokens and the connection ready, so the next request does
  /// not pay for them. Best effort.
  Future<void> warmUp();
}

/// THE PORT THE APP TALKS TO. Every cloud answer, every spoken sentence
/// and every recorded turn goes to our own server (server_model_port.dart),
/// which answers with OpenAI in the same wire shape.
class ModelPorts {
  ModelPorts._();
  static final ModelPort _server = ServerModelPort();

  static ModelPort cloud() => _server;
}
