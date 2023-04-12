import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:irondash_engine_context/irondash_engine_context.dart';
import 'package:irondash_message_channel/irondash_message_channel.dart';
import 'package:rxdart/rxdart.dart';

import '../domain/setting.dart';
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
  bool rendering = false; // whether the video is being rendered
  bool cameraHealthCheck =
      true; // whether the camera is ok (connection, resource etc.)
  String currentAudioDevice = ''; // the current audio device name
  String currentCameraDevice = ''; // the current camera device name
  List<String> audioDevices = []; // the list of audio devices
  List<String> cameraDevices = []; // the list of camera devices

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

    await queryDevices();
  }

  void setChannelHandlers() {
    recordingChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'mark_writing_state':
          writingState = WritingState.fromName(call.arguments);
          if (writingState == WritingState.encoding &&
              !Setting().renderingWhileEncoding) {
            stopRendering();
            stopCameraStream();
          }
          notifyListeners();
          return null;

        case 'mark_recording_state':
          recording = call.arguments;
          notifyListeners();
          return null;
        default:
          debugPrint('Unknown method ${call.method} ');
          return null;
      }
    });

    renderingChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'mark_rendering_state':
          rendering = call.arguments;
          observeCameraHealth();
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
    // debugPrint(text);
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

  void _openAudioStream(String device) async {
    final res = await audioChannel.invokeMethod('open_audio_stream', {
      'device_name': device,
    });
    _showResult(res);
  }

  void _stopAudioStream() async {
    final res = await audioChannel.invokeMethod('stop_audio_stream', {});
    _showResult(res);
  }

  void startRendering() async {
    final res = await renderingChannel.invokeMethod('start_rendering', {});
    _showResult(res);
  }

  void stopRendering() async {
    final res = await renderingChannel.invokeMethod('stop_rendering', {});
    _showResult(res);
  }

  Future<bool> clearAudioBuffer() async {
    final res = await audioChannel.invokeMethod('clear_audio_buffer', {});

    return Future.value(res);
  }

  Future<void> _selectAudioDevice(String device) async {
    final res = await audioChannel.invokeMethod('select_audio_device', {
      'device_name': device,
    });
    _showResult(res);
    return;
  }

  Future<void> _selectCameraDevice(String device) async {
    final res = await cameraChannel.invokeMethod('select_camera_device', {
      'device_name': device,
    });
    _showResult(res);
    return;
  }

  Future<void> _currentAudioDevice() async {
    final res = await audioChannel.invokeMethod('current_audio_device', {});
    currentAudioDevice = res;
    notifyListeners();
    return;
  }

  Future<void> _currentCameraDevice() async {
    final res = await cameraChannel.invokeMethod('current_camera_device', {});
    currentCameraDevice = res;
    notifyListeners();
    return;
  }

  Future<void> _availableAudios() async {
    final res = await audioChannel.invokeMethod('available_audios', {});
    List<String> list_ = res.cast<String>();
    audioDevices = List<String>.from(list_);
    notifyListeners();
    return;
  }

  Future<void> _availableCameras() async {
    final res = await cameraChannel.invokeMethod('available_cameras', {});
    List<String> list_ = res.cast<String>();
    cameraDevices = List<String>.from(list_);
    notifyListeners();
    return;
  }

  Future<void> _cameraHealthCheck() async {
    final res = await cameraChannel.invokeMethod('camera_health_check', {});
    cameraHealthCheck = res;
    notifyListeners();
    return;
  }

  Future<void> queryDevices() async {
    await _availableAudios();
    await _availableCameras();
    // try to fill current devices if they are empty
    if (currentAudioDevice.isEmpty || currentCameraDevice.isEmpty) {
      _startWithDefualt();
    }
  }

  void _startWithDefualt() {
    if (audioDevices.isNotEmpty) {
      selectAudioDevice(audioDevices.first);
    }
    if (cameraDevices.isNotEmpty) {
      selectCameraDevice(cameraDevices.first);
    }
  }

  void startCamera() {
    stopCameraStream();
    openCameraStream();
    startRendering();
    openTextureStream();
  }

  void selectAudioDevice(String device) async {
    await _selectAudioDevice(device);
    _currentAudioDevice();
    _stopAudioStream();
    _openAudioStream(device);
  }

  void selectCameraDevice(String device) async {
    await _selectCameraDevice(device);
    _currentCameraDevice();
    startCamera();
  }

  void observeCameraHealth() async {
    while (true) {
      if (!rendering) break;
      await _cameraHealthCheck();
      if (!cameraHealthCheck) {
        stopRendering();
        stopCameraStream();
        queryDevices();
        break;
      }
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  void observeAudioBuffer(BehaviorSubject<bool> stream) async {
    while (true) {
      if (writingState == WritingState.idle) {
        bool hanAudio = await clearAudioBuffer();
        if (!stream.isClosed) {
          stream.add(hanAudio);
        } else {
          break;
        }
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}
