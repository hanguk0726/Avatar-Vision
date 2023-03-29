import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:irondash_engine_context/irondash_engine_context.dart';
import 'package:irondash_message_channel/irondash_message_channel.dart';

class Native {
  Native._privateConstructor();
  static final Native _instance = Native._privateConstructor();
  factory Native() {
    return _instance;
  }

  static const String rustLibraryName = 'rust';
  final dylib = defaultTargetPlatform == TargetPlatform.android
      ? DynamicLibrary.open("lib$rustLibraryName.so")
      : (defaultTargetPlatform == TargetPlatform.windows
          ? DynamicLibrary.open("$rustLibraryName.dll")
          : DynamicLibrary.process());

  late final MessageChannelContext nativeContext;
  late final NativeMethodChannel _textureChannel;
  late final NativeMethodChannel _renderingChannel;
  late final NativeMethodChannel _cameraChannel;
  late final NativeMethodChannel _recordingChannel;
  late final NativeMethodChannel _audioChannel;
  late final int textureId;

  Future<void> init() async {
    await _init();
    nativeContext = _nativeContext();
    _textureChannel = NativeMethodChannel('texture_channel_background_thread',
        context: nativeContext);
    _cameraChannel = NativeMethodChannel('camera_channel_background_thread',
        context: nativeContext);
    _recordingChannel = NativeMethodChannel(
        'recording_channel_background_thread',
        context: nativeContext);
    _audioChannel = NativeMethodChannel('audio_channel_background_thread',
        context: nativeContext);
    _renderingChannel = NativeMethodChannel(
        'rendering_channel_background_thread',
        context: nativeContext);
    openCameraStream();
    openTextureStream();
    openAudioStream();
    startRendering();
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
    const String rustLibraryInitOnMainThreadCallName = 'rust_init_on_main_thread';
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
    final res = await _textureChannel.invokeMethod('open_texture_stream', {});
    _showResult(res);
  }

  void startRecording() async {
    final res = await _recordingChannel.invokeMethod('start_recording', {});
    _showResult(res);
  }

  void stopRecording() async {
    final res = await _recordingChannel.invokeMethod('stop_recording', {});
    _showResult(res);
  }

  void openCameraStream() async {
    final res = await _cameraChannel.invokeMethod('open_camera_stream', {});
    _showResult(res);
  }

  void stopCameraStream() async {
    final res = await _cameraChannel.invokeMethod('stop_camera_stream', {});
    _showResult(res);
  }

  void openAudioStream() async {
    final res = await _audioChannel.invokeMethod('open_audio_stream', {});
    _showResult(res);
  }

  void stopAudioStream() async {
    final res = await _audioChannel.invokeMethod('stop_audio_stream', {});
    _showResult(res);
  }

  void startRendering() async {
    final res = await _renderingChannel.invokeMethod('start_rendering', {});
    _showResult(res);
  }

  void reset() async {
    stopCameraStream();
    stopAudioStream();
    openCameraStream();
    openTextureStream();
    openAudioStream();
  }
}
