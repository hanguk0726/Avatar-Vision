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
  late final NativeMethodChannel _textureHandlerChannel;
  late final NativeMethodChannel _captureChannel;
  late final int textureId;
  void init() {
    _initTextureId();
    nativeContext = _initNativeContext();
    _textureHandlerChannel = NativeMethodChannel(
        'texture_handler_channel_background_thread',
        context: nativeContext);
    _captureChannel = NativeMethodChannel('captrue_channel_background_thread',
        context: nativeContext);
  }

  /// initialize context for Native library.
  MessageChannelContext _initNativeContext() {
    const String rustLibraryInitChannelCallName =
        'rust_init_message_channel_context';

    // This function will be called by MessageChannel with opaque FFI
    // initialization data. From it you should call
    // `irondash_init_message_channel_context` and do any other initialization,
    // i.e. register rust method channel handlers.
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

  void callTextureHandler() async {
    final res = await _textureHandlerChannel.invokeMethod('render_texture', {});
    _showResult(res);
  }

  void callCaptureHandler() async {
    final res = await _captureChannel.invokeMethod('open_camera_stream', {});
    _showResult(res);
  }
}
