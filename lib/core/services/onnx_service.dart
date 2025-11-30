import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import '../constants/app_constants.dart';

class OnnxService {
  static final OnnxService _instance = OnnxService._internal();
  factory OnnxService() => _instance;
  OnnxService._internal();

  OrtSession? _session;
  bool _initialized = false;
  String _currentModel = "";

  // 快取的輸入 buffer，避免每次重新分配
  static final Float32List _inputBuffer = Float32List(
    1 *
        AppConstants.onnxInputChannels *
        AppConstants.onnxInputSize *
        AppConstants.onnxInputSize,
  );

  /// 初始化 ONNX（加入模型名稱）
  Future<void> _init(String modelName) async {
    // 如果模型沒變，不重複載入
    if (_initialized && _currentModel == modelName) return;

    // 如果切換模型，先釋放舊的 session
    if (_session != null) {
      _session!.release();
      _session = null;
    }

    final raw = await rootBundle.load('assets/models/$modelName');
    final bytes = raw.buffer.asUint8List();

    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);

    _initialized = true;
    _currentModel = modelName;

    debugPrint("🔵 Loaded model: $modelName");
  }

  /// 釋放 ONNX 資源
  void dispose() {
    if (_session != null) {
      _session!.release();
      _session = null;
      _initialized = false;
      _currentModel = "";
      debugPrint("🔵 ONNX session released");
    }
  }

  /// 前處理：回傳模型需要的 224×224 & 原始尺寸
  /// 使用靜態 buffer 避免重複分配記憶體
  Map<String, dynamic> _preprocess(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes)!;

    final originalWidth = image.width;
    final originalHeight = image.height;

    const size = AppConstants.onnxInputSize;
    final resized = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );

    // 使用快取的 buffer
    int idx = 0;
    for (int c = 0; c < AppConstants.onnxInputChannels; c++) {
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final pixel = resized.getPixel(x, y);

          double v;
          if (c == 0) {
            v = pixel.r / 255.0;
          } else if (c == 1) {
            v = pixel.g / 255.0;
          } else {
            v = pixel.b / 255.0;
          }

          _inputBuffer[idx++] = v;
        }
      }
    }

    return {
      "input": _inputBuffer,
      "width": originalWidth,
      "height": originalHeight,
    };
  }

  /// 執行模型推論
  Future<Uint8List> run(Uint8List imageBytes, String modelName) async {
    await _init(modelName);

    if (_session == null) {
      throw Exception('ONNX session not initialized');
    }

    final prep = _preprocess(imageBytes);
    final inputFloats = prep["input"] as Float32List;
    final originalW = prep["width"] as int;
    final originalH = prep["height"] as int;

    const size = AppConstants.onnxInputSize;
    final inputTensor = OrtValueTensor.createTensorWithDataList(inputFloats, [
      1,
      AppConstants.onnxInputChannels,
      size,
      size,
    ]);

    final options = OrtRunOptions();
    final inputName = _session!.inputNames[0];

    final outputs = _session!.run(options, {inputName: inputTensor});
    final raw = outputs[0]!.value;

    inputTensor.release();
    options.release();

    // raw = [1][3][224][224]
    final batch = raw as List;
    final channels = batch[0] as List;
    final outR = channels[0] as List;
    final outG = channels[1] as List;
    final outB = channels[2] as List;

    const outSize = AppConstants.onnxInputSize;
    final img.Image out = img.Image(width: outSize, height: outSize);

    for (int y = 0; y < outSize; y++) {
      final rowR = outR[y] as List;
      final rowG = outG[y] as List;
      final rowB = outB[y] as List;

      for (int x = 0; x < outSize; x++) {
        final r = (rowR[x] * 255).clamp(0, 255).toInt();
        final g = (rowG[x] * 255).clamp(0, 255).toInt();
        final b = (rowB[x] * 255).clamp(0, 255).toInt();

        out.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    // 還原到原始圖片尺寸
    final img.Image restored = img.copyResize(
      out,
      width: originalW,
      height: originalH,
      interpolation: img.Interpolation.cubic,
    );

    return Uint8List.fromList(img.encodePng(restored));
  }
}
