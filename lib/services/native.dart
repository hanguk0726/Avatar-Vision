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
  late final NativeMethodChannel _captureChannel;
  late final NativeMethodChannel _encodingChannel;
  late final int textureId;

  Future<void> init() async {
    await _initTextureId();
    nativeContext = _initNativeContext();
    _textureChannel = NativeMethodChannel('texture_channel_background_thread',
        context: nativeContext);
    _captureChannel = NativeMethodChannel('captrue_channel_background_thread',
        context: nativeContext);
    _encodingChannel = NativeMethodChannel('encoding_channel_background_thread',
        context: nativeContext);
  }

  MessageChannelContext _initNativeContext() {
    const String rustLibraryInitChannelCallName =
        'rust_init_message_channel_context';

    final function =
        dylib.lookup<NativeFunction<MessageChannelContextInitFunction>>(
            rustLibraryInitChannelCallName);
    return MessageChannelContext.forInitFunction(function);
  }

  Future<void> _initTextureId() async {
    const String rustLibraryInitTextureCallName = 'rust_init_texture';
    final function = dylib
        .lookup<NativeFunction<Int64 Function(Int64)>>(
            rustLibraryInitTextureCallName)
        .asFunction<int Function(int)>();
    final handle = await EngineContext.instance.getEngineHandle();
    textureId = function(handle);
  }

  static void _showResult(Object res) {
    const encoder = JsonEncoder.withIndent('  ');
    final text = encoder.convert(res);
    debugPrint(text);
  }

  void renderTexture() async {
    final res = await _textureChannel.invokeMethod('render_texture', {});
    _showResult(res);
  }

  void startEncoding() async {
    final res = await _encodingChannel.invokeMethod('start_encoding', {});
    _showResult(res);
  }

  void openCameraStream() async {
    final res = await _captureChannel.invokeMethod('open_camera_stream', {});
    _showResult(res);
  }

  void stopCameraStream() async {
    final res = await _captureChannel.invokeMethod('stop_camera_stream', {});
    _showResult(res);
  }
}
