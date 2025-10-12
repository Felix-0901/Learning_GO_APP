// lib/pages/image_tool_page.dart
// All UI strings/identifiers in English; comments in 中文。

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/media_service.dart';
import '../services/app_state.dart';
import 'image_library_page.dart';
import '../services/onnx_service.dart'; // 只保留 ONNX
import 'dart:async'; // for TimeoutException

InputDecoration _decoration({
  String? hint,
  EdgeInsetsGeometry? contentPadding,
}) {
  final base = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey[400]!),
  );
  final focused = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey[500]!, width: 1.2),
  );
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey[100],
    isDense: true,
    contentPadding: contentPadding ?? const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    enabledBorder: base,
    focusedBorder: focused,
    border: base,
  );
}

Widget _denseDropdownWrapper({required Widget child}) {
  return SizedBox(height: 40, child: child);
}

class ImageToolPage extends StatefulWidget {
  const ImageToolPage({super.key});
  @override
  State<ImageToolPage> createState() => _ImageToolPageState();
}

class _ImageToolPageState extends State<ImageToolPage> {
  final media = MediaService();

  // 預設選第一個 ONNX；只保留 .onnx 選項
  String currentModel = 'assets/models/medium.onnx';
  String? _lastOnnxModel; // 記錄上一個已載入的 ONNX，避免切換不重載

  File? lastProcessed;
  bool processing = false;

  bool get _useOnnx => currentModel.toLowerCase().endsWith('.onnx');

  Future<void> _openLibrary() async {
    final app = context.read<AppState>();
    final result = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => const ImageLibraryPage()),
    );
    if (result != null) {
      app.setCurrentImage(result);   // ✅ 存到 AppState
      setState(() {                  // 僅維持 processed 標記邏輯
        lastProcessed = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final isProcessed = lastProcessed != null;

    final app = context.watch<AppState>();
    final current = app.currentImage; // 以 AppState 作為單一真相來源


    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Tool'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            onPressed: _openLibrary,
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Model', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: _decoration(contentPadding: EdgeInsets.zero),
              child: DropdownButtonHideUnderline(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: _denseDropdownWrapper(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      iconSize: 24,
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: Colors.white,
                      elevation: 3,
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      value: currentModel,
                      items: const [
                        DropdownMenuItem(
                          value: 'assets/models/medium.onnx',
                          child: Text('ONNX - medium'),
                        ),
                        DropdownMenuItem(
                          value: 'assets/models/sub-conservative.onnx',
                          child: Text('ONNX - sub-conservative'),
                        ),
                        DropdownMenuItem(
                          value: 'assets/models/conservative.onnx',
                          child: Text('ONNX - conservative'),
                        ),
                        DropdownMenuItem(
                          value: 'assets/models/radical.onnx',
                          child: Text('ONNX - radical'),
                        ),
                      ],
                      onChanged: (v) => setState(() => currentModel = v!),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: (current == null)
                    ? const Text('No image')
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(current!, fit: BoxFit.contain),
                            ),
                          ),
                          if (isProcessed)
                            Positioned(
                              top: 8,
                              right: 16,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _SmallCircleButton(
                                    icon: Icons.download_outlined,
                                    backgroundColor: const Color(0xFFD9ECFF),
                                    iconColor: const Color(0xFF007AFF),
                                    onTap: _downloadProcessed,
                                  ),
                                  const SizedBox(width: 6),
                                  _SmallCircleButton(
                                    icon: Icons.close_rounded,
                                    backgroundColor: const Color(0xFFFFEBEE),
                                    iconColor: Colors.red,
                                    onTap: _clearCurrentFromView,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: processing ? Colors.red : (isProcessed ? Colors.grey : Colors.green),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      child: Text(processing ? 'Processing...' : (isProcessed ? 'Already Enhanced' : 'Start Enhancement')),
                      onPressed: (current == null || processing || isProcessed)
                          ? null
                          : () async {
                              setState(() => processing = true);
                              try {
                                final app = context.read<AppState>();
                                final src = app.currentImage;   // ✅ 用 AppState 讀
                                if (src == null) return;

                                // 先把原圖存到 Original
                                await media.saveAsOriginal(src);

                                // （你目前是模擬處理：直接讀 bytes）
                                final outBytes = await src.readAsBytes();

                                // final onnx = OnnxService();
                                // final needReload = (_lastOnnxModel != currentModel) || !onnx.ready;
                                // if (needReload) {
                                //   await onnx.loadModel(
                                //     assetPath: currentModel,
                                //     // TODO: 這裡換成你的真實模型規格
                                //     config: const OnnxModelConfig(
                                //       inputName: 'input',     // ← 換成模型 input 名稱
                                //       outputName: 'output',   // ← 若需要指定輸出時才用
                                //       inputWidth: 224,        // ← 換成正確 W
                                //       inputHeight: 224,       // ← 換成正確 H
                                //       layout: TensorLayout.nhwc, // ← 若是 NCHW 改成 nchw
                                //       mean: [0.485, 0.456, 0.406],
                                //       std:  [0.229, 0.224, 0.225],
                                //       inputRange255: true,
                                //     ),
                                //   );
                                //   _lastOnnxModel = currentModel;
                                // }

                                // final outBytes = await OnnxService()
                                //     .runImageToImage(current!)
                                //     .timeout(const Duration(seconds: 20), onTimeout: () {
                                //   throw TimeoutException('ONNX inference timed out');
                                // }); // ⭐️ 移除耗時的 ONNX 推論和超時處理

                                // === 後續處理：將位元組資料存成處理後的檔案 ===
                                // 存成處理後檔案
                                final tmpDir = await Directory.systemTemp.createTemp('onnx_');
                                final tmpPath = '${tmpDir.path}/enh_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                final tmpFile = await File(tmpPath).writeAsBytes(outBytes);
                                final processedFile = await media.saveAsProcessed(tmpFile);

                                if (mounted) {
                                  app.setCurrentImage(processedFile); // ✅ 寫回 AppState
                                  setState(() {
                                    lastProcessed = processedFile;    // 本頁的處理標記仍在本地
                                  });
                                  context.read<AppState>().addImage(
                                    name: processedFile.uri.pathSegments.last,
                                    path: processedFile.path,
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Process failed: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => processing = false);
                              }

                            },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(const Color(0xFF007AFF)),
                    ),
                    onPressed: processing
                        ? null
                        : () async {
                            final app = context.read<AppState>();
                            final f = await media.captureFromCamera();
                            if (f != null) {
                              app.setCurrentImage(f);          // ✅ 存到 AppState
                              setState(() => lastProcessed = null);
                            }
                          },

                    icon: const Icon(Icons.photo_camera_outlined),
                    iconSize: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.white),
                      side: MaterialStateProperty.all(
                        const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                      ),
                    ),
                    onPressed: processing
                        ? null
                        : () async {
                            final app = context.read<AppState>();
                            final f = await media.pickFromGallery();
                            if (f != null) {
                                app.setCurrentImage(f);        // ✅ 存到 AppState
                                setState(() => lastProcessed = null);
                            }
                          },
                    icon: const Icon(Icons.perm_media),
                    iconSize: 20,
                    color: const Color(0xFF007AFF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearCurrentFromView() {
    context.read<AppState>().setCurrentImage(null); // ✅ 清 AppState
    setState(() => lastProcessed = null);
  }


  Future<void> _downloadProcessed() async {
    if (lastProcessed == null) return;
    final ok = await MediaService().saveProcessedToDevice(lastProcessed!, album: 'LearningGO');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Saved to Photos' : 'Save failed')),
    );
  }
}

class _SmallCircleButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _SmallCircleButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

