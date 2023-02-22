import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:irondash_engine_context/irondash_engine_context.dart';
import 'package:irondash_message_channel/irondash_message_channel.dart';
import 'package:video_diary/services/video_process.dart';

class Native {
  Native._privateConstructor();
  static final Native _instance = Native._privateConstructor();
  factory Native() {
    return _instance;
  }
  static const String rustLibraryName = 'rust';
  static final dylib = defaultTargetPlatform == TargetPlatform.android
      ? DynamicLibrary.open("lib$rustLibraryName.so")
      : (defaultTargetPlatform == TargetPlatform.windows
          ? DynamicLibrary.open("$rustLibraryName.dll")
          : DynamicLibrary.process());

  /// initialize context for Native library.
  static MessageChannelContext _initNativeContext() {
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

  static Future<int> initTextureId() async {
    const String rustLibraryInitTextureCallName = 'rust_init_texture';
    final function = dylib
        .lookup<NativeFunction<Int64 Function(Int64)>>(
            rustLibraryInitTextureCallName)
        .asFunction<int Function(int)>();
    final handle = await EngineContext.instance.getEngineHandle();
    return function(handle);
  }

  static final nativeContext = _initNativeContext();

  void _showResult(Object res) {
    const encoder = JsonEncoder.withIndent('  ');
    final text = encoder.convert(res);
    debugPrint(text);
  }

  final _channel =
      NativeMethodChannel('addition_channel', context: nativeContext);

  final _channelBackgroundThread = NativeMethodChannel(
      'addition_channel_background_thread',
      context: nativeContext);

  final _slowChannel =
      NativeMethodChannel('slow_channel', context: nativeContext);

  final _httpClientChannel =
      NativeMethodChannel('http_client_channel', context: nativeContext);

  void _callRustOnPlatformThread() async {
    final res = await _channel.invokeMethod('add', {'a': 10.0, 'b': 20.0});
    _showResult(res);
  }

  void _callRustOnBackgroundThread() async {
    final res = await _channelBackgroundThread
        .invokeMethod('add', {'a': 15.0, 'b': 5.0});
    _showResult(res);
  }

  void _callSlowMethod() async {
    final res = await _slowChannel.invokeMethod('getMeaningOfUniverse', {});
    _showResult(res);
  }

  void _loadPage() async {
    final res = await _httpClientChannel.invokeMethod('load', {
      'url': 'https://flutter.dev',
    });
    _showResult(res);
  }
}
