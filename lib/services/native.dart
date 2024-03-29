import 'dart:ffi';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:irondash_engine_context/irondash_engine_context.dart';
import 'package:irondash_message_channel/irondash_message_channel.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/services/database.dart';
import 'package:wakelock/wakelock.dart';

import '../domain/writing_state.dart';
import 'setting.dart';

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
  String cameraHealthCheckErrorMessage =
      ''; // the error message of the camera health check

  String currentAudioDevice = ''; // the current audio device name
  String currentCameraDevice = ''; // the current camera device name

  List<String> audioDevices = []; // the list of audio devices
  List<String> cameraDevices = []; // the list of camera devices

  List<String> resolutions = []; // the list of resolutions
  String currentResolution = ''; // the current resolution
  double currentResolutionWidth = 0; // the width of the current resolution
  double currentResolutionHeight = 0; // the height of the current resolution

  bool recordingHealthCheck =
      true; // whether the recording is ok (os permission for writing file etc.)

  static const String rustLibraryName = 'rust';

  final dylib = DynamicLibrary.open("$rustLibraryName.dll");
  // final dylib = defaultTargetPlatform == TargetPlatform.android
  //     ? DynamicLibrary.open("lib$rustLibraryName.so")
  //     : (defaultTargetPlatform == TargetPlatform.windows
  //         ? DynamicLibrary.open("$rustLibraryName.dll")
  //         : DynamicLibrary.process());

  late final int textureId;

  late final MessageChannelContext nativeContext;

  late final NativeMethodChannel textureChannel;
  late final NativeMethodChannel renderingChannel;
  late final NativeMethodChannel cameraChannel;
  late final NativeMethodChannel recordingChannel;
  late final NativeMethodChannel audioChannel;

  String filePathPrefix = '';
  String fileName = '';
  List<String> files = [];

  Future<void> deleteFile(int timestamp) async {
    final fileName = osFileName(timestamp);
    File file = File('$filePathPrefix\\$fileName.mp4');
    file.deleteSync();
    File thumbnailFile = File('$filePathPrefix\\thumbnails\\$fileName.png');
    thumbnailFile.deleteSync();
    var db = DatabaseService();
    await db.sync();
    // The db record will be deleted by the db function 'clearOutdatedRecords'
  }

  Future<void> sendFileToDesktop(int timestamp) async {
    final fileName = osFileName(timestamp);
    final filePath = '$filePathPrefix\\$fileName.mp4';
    File file = File(filePath);
    if (file.existsSync()) {
      String desktopDir = '${Platform.environment['USERPROFILE']}\\Desktop';
      file.copySync('$desktopDir\\${file.path.split('\\').last}');
    } else {
      debugPrint('File does not exist.');
    }
  }

  // check essential files and directories are available
  // and set the file path prefix and the list of files already recorded
  Future<void> checkFileDirectoryAndSetFiles() async {
    // On Windows, get or create the appdata folder
    if (Platform.isWindows) {
      final appDataDir = Directory.current;
      final targetDirectory = Directory('${appDataDir.path}\\data');
      filePathPrefix = targetDirectory.path;
      if (await targetDirectory.exists()) {
        // debugPrint('Directory already exists');
      } else {
        await targetDirectory.create(recursive: true);
        // debugPrint('Directory created at: ${targetDirectory.path}');
      }
      final thumbnailDirectory =
          Directory('${appDataDir.path}\\data\\thumbnails');
      if (await thumbnailDirectory.exists()) {
        // debugPrint('Directory already exists');
      } else {
        await thumbnailDirectory.create(recursive: true);
        // debugPrint('Directory created at: ${thumbnailDirectory.path}');
      }
      if (targetDirectory.existsSync()) {
        var result = targetDirectory.statSync();
        var isWritable = result.mode & 0x92 != 0; // 0x92 = 10010010 in binary
        List<FileSystemEntity> files_ = targetDirectory.listSync();
        files.clear();
        for (FileSystemEntity file in files_) {
          if (file is File) {
            if (!file.path.endsWith('.mp4')) continue;
            // remove the file extension and the path
            String fileName = file.path.split('\\').last.split('.mp4').first;
            files.add(fileName);
          }
        }
        if (isWritable) {
          // debugPrint('$targetDirectory is writable.');
        } else {
          debugPrint('$targetDirectory is not writable.');
          recordingHealthCheck = false;
          notifyListeners();
        }
      } else {
        debugPrint('$targetDirectory does not exist.');
      }
    } else {
      debugPrint('This function is only implemented for Windows');
    }
  }

  Widget getThumbnail(int timestamp) {
    final fileName = osFileName(timestamp);
    final thumbnailPath = '$filePathPrefix\\thumbnails\\$fileName.png';
    return Image(
      image: FileImage(File(thumbnailPath)),
      fit: BoxFit.fitWidth,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const Opacity(
          opacity: 0.7,
          child: Image(
            image: AssetImage('assets/placeholder.png'),
          ),
        );
      },
    );
  }

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
    await checkFileDirectoryAndSetFiles();
    await queryDevices();
    listenUiEventDispatcher();
  }

// Channel from Rust to Flutter
  void setChannelHandlers() {
    recordingChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'mark_writing_state':
          writingState = WritingState.fromName(call.arguments);
          if (writingState == WritingState.saving) {
            stopRendering();
            await stopCameraStream();
          }
          notifyListeners();
          debugPrint('writingState: $writingState');
          if (writingState == WritingState.idle) {
            if (!rendering) {
              DatabaseService().sync();
              await startCamera();
            }
          }
          return null;

        case 'mark_recording_state':
          recording = call.arguments;
          notifyListeners();
          debugPrint('recording: $recording');
          return null;
        default:
          debugPrint('Unknown method ${call.method} ');
          return null;
      }
    });

    renderingChannel.setMethodCallHandler((call) {
      switch (call.method) {
        case 'mark_rendering_state':
          rendering = call.arguments;
          notifyListeners();
          rendering ? Wakelock.enable() : Wakelock.disable();

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

  void _showResult(Object res) {
    // const encoder = JsonEncoder.withIndent('  ');
    // final text = encoder.convert(res);
    // debugPrint(text);
  }

  Future<void> openTextureStream() async {
    final res = await textureChannel.invokeMethod('open_texture_stream', {
      'resolution': currentResolution,
    });
    _showResult(res);
  }

  void startRecording() async {
    _stopAudioStream();
    _openAudioStream(currentAudioDevice);
    final res = await recordingChannel.invokeMethod('start_recording', {});
    _showResult(res);
    _startEncoding();
  }

  void _startEncoding() async {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;

    final fileName = osFileName(timestamp);

    DatabaseService().insert(timestamp);
    final res = await recordingChannel.invokeMethod('start_encording', {
      'file_path_prefix': filePathPrefix,
      'file_name': fileName,
      'resolution': currentResolution,
    });
    _showResult(res);
  }

  void stopRecording() async {
    final res = await recordingChannel.invokeMethod('stop_recording', {});
    _showResult(res);
  }

  // for rust to communicate each other(rust)
  void listenUiEventDispatcher() async {
    final res =
        await recordingChannel.invokeMethod('listen_ui_event_dispatcher', {});
    _showResult(res);
  }

  Future<void> openCameraStream() async {
    final lastPreferredResolution = Setting().lastPreferredResolution;
    String requestedResolution = currentResolution;
    if (lastPreferredResolution.isNotEmpty && currentResolution.isEmpty) {
      requestedResolution = lastPreferredResolution;
    }

    final res = await cameraChannel.invokeMethod('open_camera_stream', {
      'resolution': requestedResolution,
    });
    _showResult(res);
  }

  Future<void> stopCameraStream() async {
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

  Future<void> startRendering() async {
    final res = await renderingChannel.invokeMethod('start_rendering', {});
    _showResult(res);
  }

  void stopRendering() async {
    final res = await renderingChannel.invokeMethod('stop_rendering', {});
    _showResult(res);
  }

  void availableResolution() async {
    final res = await cameraChannel.invokeMethod('available_resolution', {});
    var buffer = res.cast<String>();
    var buffer2 = buffer.where((element) {
      var resolution = element.split('x');
      int width = int.parse(resolution[0]);
      return width >= 1280;
    });

    buffer2 = buffer2.toList();
    buffer2.sort((a, b) {
      List<String> aResolution = a.split('x');
      List<String> bResolution = b.split('x');

      int aWidth = int.parse(aResolution[0]);
      int aHeight = int.parse(aResolution[1]);
      int bWidth = int.parse(bResolution[0]);
      int bHeight = int.parse(bResolution[1]);

      if (aWidth == bWidth) {
        return bHeight.compareTo(aHeight);
      } else {
        return bWidth.compareTo(aWidth);
      }
    });
    resolutions = buffer2.toList();

    notifyListeners();
  }

  Future<bool> getAudioBuffer() async {
    final res = await audioChannel.invokeMethod('get_audio_buffer', {});

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
    cameraHealthCheck = res == "ok";
    cameraHealthCheckErrorMessage = res;

    notifyListeners();
    return;
  }

  Future<void> _currentResolution() async {
    final res = await cameraChannel.invokeMethod('current_resolution', {});
    currentResolution = res;
    final resolution = currentResolution.split('x');
    currentResolutionWidth = double.parse(resolution[0]);
    currentResolutionHeight = double.parse(resolution[1]);
    Setting().setLastPreferredResolution(currentResolution);
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

  Future<void> startCamera() async {
    await openCameraStream();
    availableResolution();
    await _currentResolution();
    openTextureStream();
    await startRendering();
    _cameraHealthCheck();
  }

  void selectAudioDevice(String device) async {
    await _selectAudioDevice(device);
    _currentAudioDevice();
    _stopAudioStream();
    _openAudioStream(device);
  }

  void selectCameraDevice(String device) async {
    await _selectCameraDevice(device);
    await _currentCameraDevice();
    await startCamera();
  }

  void observeAudioBuffer(BehaviorSubject<bool> stream) async {
    // To save resource, keep clearing audio buffer when is not recording
    while (true) {
      if (writingState == WritingState.idle) {
        bool hanActiveAudio = await getAudioBuffer();
        if (!stream.isClosed) {
          stream.add(hanActiveAudio);
        } else {
          break;
        }
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void selectResolution(String resolution) async {
    currentResolution = resolution;
    stopRendering();
    await stopCameraStream();
    await startCamera();
  }
}
