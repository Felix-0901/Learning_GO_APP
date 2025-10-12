// lib/services/onnx_service.dart
// 單例 ONNX 服務，提供：loadModel()、runImageToImage() 與 runClassifier()
// 依你的模型 I/O 規格調整 OnnxModelConfig（inputName、outputName、shape、正規化）

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show compute;

enum TensorLayout { nhwc, nchw }

class OnnxModelConfig {
  final String inputName;
  final String outputName;
  final int inputWidth;
  final int inputHeight;
  final TensorLayout layout;
  final List<double>? mean; // e.g. [0.485, 0.456, 0.406]
  final List<double>? std;  // e.g. [0.229, 0.224, 0.225]
  final bool inputRange255; // true: 0..255 先 /255；false: 已是 0..1

  const OnnxModelConfig({
    required this.inputName,
    required this.outputName,
    required this.inputWidth,
    required this.inputHeight,
    this.layout = TensorLayout.nhwc,
    this.mean,
    this.std,
    this.inputRange255 = true,
  });
}

class OnnxService {
  OnnxService._();
  static final OnnxService _i = OnnxService._();
  factory OnnxService() => _i;

  OrtSession? _session;
  OnnxModelConfig? _cfg;

  bool get ready => _session != null;

  Future<void> loadModel({
    required String assetPath,
    required OnnxModelConfig config,
  }) async {
    // 初始化環境（多次呼叫也安全）
    OrtEnv.instance.init();
    _cfg = config;

    final raw = await rootBundle.load(assetPath);
    final bytes = raw.buffer.asUint8List();

    // 可視需要調整 SessionOptions（如啟用 NNAPI/Metal）
    final opts = OrtSessionOptions();
    _session?.release();
    _session = OrtSession.fromBuffer(bytes, opts);

    opts.release();
  }

  /// 影像 → 影像 模型（例如增強/去噪/風格化）
  /// 輸出：處理後 JPG bytes（尺寸與模型輸出一致；常見為與輸入同尺寸）
  Future<Uint8List> runImageToImage(File inputFile) async {
    if (_session == null || _cfg == null) {
      throw StateError('ONNX session not loaded');
    }
    final cfg = _cfg!;
    final bytes = await inputFile.readAsBytes();

    img.Image? src = img.decodeImage(bytes);
    if (src == null) {
      throw StateError('Cannot decode input image');
    }

    // 1) 丟到背景 Isolate
    final floatData = await compute(_preprocessToFloat32, _PreprocessArgs(bytes, cfg));

    // 3) 建 tensor（依 NHWC/NCHW）
    final shape = (cfg.layout == TensorLayout.nhwc)
        ? [1, cfg.inputHeight, cfg.inputWidth, 3]
        : [1, 3, cfg.inputHeight, cfg.inputWidth];

    final inputTensor = OrtValueTensor.createTensorWithDataList(floatData, shape);
    final inputs = {cfg.inputName: inputTensor};

    // 4) 推論
    final runOpts = OrtRunOptions();
    final outputs = await _session!.runAsync(runOpts, inputs);
    runOpts.release();
    inputTensor.release();

    if (outputs == null || outputs.isEmpty || outputs.first == null) {
      // 清理
      for (final o in outputs ?? <OrtValue?>[]) { o?.release(); }
      throw StateError('ONNX returned empty output');
    }

    // 5) 解析輸出：假設輸出為與輸入等維度的影像張量（float 0..1）
    //    若模型輸出不同（如 logits / NHWC/NCHW 差異），請在此處調整
    final out = outputs.first!;
    final outValue = out.value;
    out.release();
    for (int i = 1; i < outputs.length; i++) { outputs[i]?.release(); }

    // 支援兩種常見格式：List<double> 或 Float32List
    late final Float32List outFloats;
    if (outValue is Float32List) {
      outFloats = outValue;
    } else if (outValue is List) {
      outFloats = Float32List.fromList(outValue.cast<double>());
    } else {
      throw StateError('Unexpected ONNX output type: ${outValue.runtimeType}');
    }

    // 6) 後處理：float->uint8 圖像
    final outImg = _fromFloat32ToImage(
      outFloats,
      width: cfg.inputWidth,
      height: cfg.inputHeight,
      layout: cfg.layout,
      mean: cfg.mean,
      std: cfg.std,
    );

    // 若需要回到原始尺寸，可再 resize 回 src.width/src.height
    // final outResized = img.copyResize(outImg, width: src.width, height: src.height);

    final jpg = img.encodeJpg(outImg, quality: 95);
    return Uint8List.fromList(jpg);
  }

  /// 影像 → 分類（回傳機率/分數），若你的模型是分類類型可用這個
  Future<List<double>> runClassifier(File inputFile) async {
    if (_session == null || _cfg == null) {
      throw StateError('ONNX session not loaded');
    }
    final cfg = _cfg!;
    final bytes = await inputFile.readAsBytes();
    img.Image? src = img.decodeImage(bytes);
    if (src == null) throw StateError('Cannot decode input image');

    final resized = img.copyResize(src, width: cfg.inputWidth, height: cfg.inputHeight);
    final floatData = _toFloat32(resized, cfg);

    final shape = (cfg.layout == TensorLayout.nhwc)
        ? [1, cfg.inputHeight, cfg.inputWidth, 3]
        : [1, 3, cfg.inputHeight, cfg.inputWidth];

    final inputTensor = OrtValueTensor.createTensorWithDataList(floatData, shape);
    final inputs = {cfg.inputName: inputTensor};

    final runOpts = OrtRunOptions();
    final outputs = await _session!.runAsync(runOpts, inputs);
    runOpts.release();
    inputTensor.release();

    if (outputs == null || outputs.isEmpty || outputs.first == null) {
      for (final o in outputs ?? <OrtValue?>[]) { o?.release(); }
      throw StateError('ONNX returned empty output');
    }

    final out = outputs.first!;
    final outVal = out.value;
    out.release();
    for (int i = 1; i < outputs.length; i++) { outputs[i]?.release(); }

    if (outVal is Float32List) return outVal.toList();
    if (outVal is List) return outVal.cast<double>();
    throw StateError('Unexpected output type: ${outVal.runtimeType}');
  }

  void dispose() {
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }

  // ===== Helpers =====

  // 影像 -> Float32，依 cfg.layout 輸出 NHWC/NCHW；同時套用 mean/std
  static Float32List _toFloat32(img.Image im, OnnxModelConfig cfg) {
    final w = im.width, h = im.height;
    final n = w * h * 3;
    final out = Float32List(n);

    // 抽通道
    int idx = 0;
    if (cfg.layout == TensorLayout.nhwc) {
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final p = im.getPixel(x, y);
          double r = p.r.toDouble();
          double g = p.g.toDouble();
          double b = p.b.toDouble();


          if (cfg.inputRange255) {
            r /= 255.0; g /= 255.0; b /= 255.0;
          }
          if (cfg.mean != null && cfg.std != null) {
            r = (r - cfg.mean![0]) / cfg.std![0];
            g = (g - cfg.mean![1]) / cfg.std![1];
            b = (b - cfg.mean![2]) / cfg.std![2];
          }

          out[idx++] = r;
          out[idx++] = g;
          out[idx++] = b;
        }
      }
    } else {
      // NCHW：R plane -> G plane -> B plane
      final plane = w * h;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final p = im.getPixel(x, y);
          double r = p.r.toDouble();
          double g = p.g.toDouble();
          double b = p.b.toDouble();
          if (cfg.inputRange255) { r /= 255.0; g /= 255.0; b /= 255.0; }
          if (cfg.mean != null && cfg.std != null) {
            r = (r - cfg.mean![0]) / cfg.std![0];
            g = (g - cfg.mean![1]) / cfg.std![1];
            b = (b - cfg.mean![2]) / cfg.std![2];
          }
          final xy = y * w + x;
          out[xy] = r;
          out[plane + xy] = g;
          out[2 * plane + xy] = b;
        }
      }
    }
    return out;
  }

  // Float32 -> 圖像（反標準化）；假設輸出範圍為 0..1 或 (x*std+mean)
  static img.Image _fromFloat32ToImage(
    Float32List f,
    {required int width, required int height, required TensorLayout layout,
     List<double>? mean, List<double>? std}
  ) {
    final out = img.Image(width: width, height: height);
    if (layout == TensorLayout.nhwc) {
      int idx = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          double r = f[idx++], g = f[idx++], b = f[idx++];
          if (mean != null && std != null) {
            r = r * std[0] + mean[0];
            g = g * std[1] + mean[1];
            b = b * std[2] + mean[2];
          }
          int ri = (r * 255.0).clamp(0, 255).toInt();
          int gi = (g * 255.0).clamp(0, 255).toInt();
          int bi = (b * 255.0).clamp(0, 255).toInt();
          out.setPixelRgb(x, y, ri, gi, bi);
        }
      }
    } else {
      final plane = width * height;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final xy = y * width + x;
          double r = f[xy], g = f[plane + xy], b = f[2 * plane + xy];
          if (mean != null && std != null) {
            r = r * std[0] + mean[0];
            g = g * std[1] + mean[1];
            b = b * std[2] + mean[2];
          }
          int ri = (r * 255.0).clamp(0, 255).toInt();
          int gi = (g * 255.0).clamp(0, 255).toInt();
          int bi = (b * 255.0).clamp(0, 255).toInt();
          out.setPixelRgb(x, y, ri, gi, bi);
        }
      }
    }
    return out;
  }
}

class _PreprocessArgs {
  final Uint8List bytes;
  final OnnxModelConfig cfg;
  _PreprocessArgs(this.bytes, this.cfg);
}

// 背景 Isolate 的前處理函式（純函式）
Float32List _preprocessToFloat32(_PreprocessArgs args) {
  final cfg = args.cfg;
  final src = img.decodeImage(args.bytes);
  if (src == null) {
    throw StateError('Cannot decode input image');
  }
  final resized = img.copyResize(
    src,
    width: cfg.inputWidth,
    height: cfg.inputHeight,
    interpolation: img.Interpolation.average,
  );
  return OnnxService._toFloat32(resized, cfg);
}

