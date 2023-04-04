import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:irondash_engine_context/irondash_engine_context.dart';
import 'package:irondash_message_channel/irondash_message_channel.dart';

import '../domain/writing_state.dart';

class Native with ChangeNotifier, DiagnosticableTreeMixin {
  Native._privateConstructor();
  static final Native _instance = Native._privateConstructor();
  factory Native() {
    return _instance;
  }

  WritingState writingState = WritingState
      .idle; // whether the recorded video data is being written to the file
  bool recording = false; // whether the video is being recorded

  static const String rustLibraryName = 'rust';

  final dylib = defaultTargetPlatform == TargetPlatform.android
      ? DynamicLibrary.open("lib$rustLibraryName.so")
      : (defaultTargetPlatform == TargetPlatform.windows
          ? DynamicLibrary.open("$rustLibraryName.dll")
          : DynamicLibrary.process());

  late final int textureId;

  late final MessageChannelContext nativeContext;

  late final NativeMethodChannel textureChannel;
  late final NativeMethodChannel renderingChannel;
  late final NativeMethodChannel cameraChannel;
  late final NativeMethodChannel recordingChannel;
  late final NativeMethodChannel audioChannel;

  Future<void> init() async {
    await _init();
    nativeContext = _nativeContext();
    textureChannel = NativeMethodChannel('texture_channel_background_thread',
        context: nativeContext);
    cameraChannel = NativeMethodChannel('camera_channel_background_thread',
        context: nativeContext);
    recordingChannel = NativeMethodChannel(
        'recording_channel_background_thread',
        context: nativeContext);
    audioChannel = NativeMethodChannel('audio_channel_background_thread',
        context: nativeContext);
    renderingChannel = NativeMethodChannel(
        'rendering_channel_background_thread',
        context: nativeContext);
    setChannelHandlers();
    start();
    debugPrint('audio ${await available_audios()}');
  }

  void setChannelHandlers() {
    recordingChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'mark_writing_state':
          debugPrint('mark_writing_state');
          writingState = WritingState.fromName(call.arguments);
          notifyListeners();
          return null;

        case 'mark_recording_state':
          debugPrint('mark_recording_state');
          recording = call.arguments;
          notifyListeners();
          return null;
        default:
          debugPrint('Unknown method ${call.method} ');
          return null;
      }
    });
  }

  MessageChannelContext _nativeContext() {
    const String rustLibraryInitMessageChannelCallName =
        'rust_init_message_channel_context';

    final function =
        dylib.lookup<NativeFunction<MessageChannelContextInitFunction>>(
            rustLibraryInitMessageChannelCallName);
    return MessageChannelContext.forInitFunction(function);
  }

  Future<void> _init() async {
    const String rustLibraryInitOnMainThreadCallName =
        'rust_init_on_main_thread';
    final function = dylib
        .lookup<NativeFunction<Int64 Function(Int64)>>(
            rustLibraryInitOnMainThreadCallName)
        .asFunction<int Function(int)>();
    final handle = await EngineContext.instance.getEngineHandle();
    textureId = function(handle);
  }

  static void _showResult(Object res) {
    const encoder = JsonEncoder.withIndent('  ');
    final text = encoder.convert(res);
    debugPrint(text);
  }

  void openTextureStream() async {
    final res = await textureChannel.invokeMethod('open_texture_stream', {});
    _showResult(res);
  }

  void startRecording() async {
    final res = await recordingChannel.invokeMethod('start_recording', {});
    _showResult(res);
  }

  void stopRecording() async {
    final res = await recordingChannel.invokeMethod('stop_recording', {});
    _showResult(res);
  }

  void openCameraStream() async {
    final res = await cameraChannel.invokeMethod('open_camera_stream', {});
    _showResult(res);
  }

  void stopCameraStream() async {
    final res = await cameraChannel.invokeMethod('stop_camera_stream', {});
    _showResult(res);
  }

  void openAudioStream() async {
    final res = await audioChannel.invokeMethod('open_audio_stream', {});
    _showResult(res);
  }

  void stopAudioStream() async {
    final res = await audioChannel.invokeMethod('stop_audio_stream', {});
    _showResult(res);
  }

  void startRendering() async {
    final res = await renderingChannel.invokeMethod('start_rendering', {});
    _showResult(res);
  }

  void clearAudioBuffer() async {
    final res = await audioChannel.invokeMethod('clear_audio_buffer', {});
    _showResult(res);
  }

  Future<List<String>> available_audios() async {
    final res = await audioChannel.invokeMethod('available_audios', {});
    List<String> list_ = res.cast<String>();
    return List<String>.from(list_);
  }

  void start() {
    openCameraStream();
    openTextureStream();
    openAudioStream();
    startRendering();
  }

  void reset() {
    stopCameraStream();
    openCameraStream();
    openTextureStream();
  }

  void observeAudioBuffer() async {
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      if (writingState == WritingState.idle) {
        clearAudioBuffer();
      }
    }
  }
}
