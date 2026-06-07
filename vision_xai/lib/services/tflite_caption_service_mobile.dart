import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

class CaptionResult {
  final String caption;
  final List<String> words;
  final List<List<double>> attentionMaps;

  CaptionResult(this.caption, this.words, this.attentionMaps);
}

class TfliteCaptionService {
  Uint8List? _featureExtractorBytes;
  Uint8List? _decoderBytes;
  Map<int, String>? _indexToWord;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initializes vocabulary and loads model bytes into memory from the asset bundle on the main isolate
  Future<void> init() async {
    if (_isInitialized) return;

    // Load model bytes from asset bundle
    final feData = await rootBundle.load('assets/feature_extractor.tflite');
    _featureExtractorBytes = feData.buffer.asUint8List();

    final decData = await rootBundle.load('assets/decoder.tflite');
    _decoderBytes = decData.buffer.asUint8List();

    // Load vocabulary
    final vocabString = await rootBundle.loadString('assets/vocab.json');
    final Map<String, dynamic> vocabJson = json.decode(vocabString);
    
    _indexToWord = <int, String>{};
    vocabJson.forEach((key, value) {
      _indexToWord![value as int] = key;
    });

    _isInitialized = true;
  }

  /// Generates caption for a given image file path in a separate isolate using pre-loaded buffers
  Future<CaptionResult> generateCaption(String imagePath) async {
    if (!_isInitialized) {
      await init();
    }

    final indexToWordMap = _indexToWord!;
    final feBytes = _featureExtractorBytes!;
    final decBytes = _decoderBytes!;

    // Offload the heavy image processing and inference loop to a background Isolate
    return await Isolate.run(() async {
      // 1. Load and preprocess image
      final bytes = await File(imagePath).readAsBytes();
      final image = img_lib.decodeImage(bytes);
      if (image == null) {
        throw Exception("Failed to decode image.");
      }

      // Resize to 299x299 as required by InceptionV3
      final resizedImage = img_lib.copyResize(image, width: 299, height: 299);

      // Normalize pixel values to [-1.0, 1.0]
      final inputImage = List.generate(
        1,
        (_) => List.generate(
          299,
          (y) => List.generate(
            299,
            (x) {
              final pixel = resizedImage.getPixel(x, y);
              final r = (pixel.r.toDouble() / 127.5) - 1.0;
              final g = (pixel.g.toDouble() / 127.5) - 1.0;
              final b = (pixel.b.toDouble() / 127.5) - 1.0;
              return [r, g, b];
            },
          ),
        ),
      );

      // Load interpreters from the pre-loaded memory buffers
      final featureExtractor = Interpreter.fromBuffer(feBytes);
      final decoder = Interpreter.fromBuffer(decBytes);

      try {
        // 2. Run Feature Extractor
        var feOutput = List.generate(
          1,
          (_) => List.generate(
            8,
            (_) => List.generate(
              8,
              (_) => List.filled(2048, 0.0),
            ),
          ),
        );

        featureExtractor.run(inputImage, feOutput);

        // 3. Reshape features from [1, 8, 8, 2048] to [1, 64, 2048]
        var reshapedFeatures = List.generate(
          1,
          (_) => List.generate(
            64,
            (index) {
              final h = index ~/ 8;
              final w = index % 8;
              return feOutput[0][h][w];
            },
          ),
        );

        // 4. Map decoder input/output indices dynamically
        int decInputIndex = 0;
        int imageFeaturesIndex = 1;
        int hiddenIndex = 2;

        final inputTensors = decoder.getInputTensors();
        for (int i = 0; i < inputTensors.length; i++) {
          final name = inputTensors[i].name;
          if (name.contains('dec_input')) {
            decInputIndex = i;
          } else if (name.contains('image_features')) {
            imageFeaturesIndex = i;
          } else if (name.contains('hidden')) {
            hiddenIndex = i;
          }
        }

        int predictionsIndex = 0;
        int nextHiddenIndex = 1;
        int attentionWeightsIndex = 2;

        final outputTensors = decoder.getOutputTensors();
        for (int i = 0; i < outputTensors.length; i++) {
          final shape = outputTensors[i].shape;
          if (shape.contains(10001)) {
            predictionsIndex = i;
          } else if (shape.length == 2 && shape[0] == 1 && shape[1] == 512) {
            nextHiddenIndex = i;
          } else if (shape.length == 3 && shape[0] == 1 && shape[1] == 64 && shape[2] == 1) {
            attentionWeightsIndex = i;
          }
        }

        // 5. Decode loop
        int decInput = 2; // Token ID of <start>
        var hidden = List.generate(1, (_) => List.filled(512, 0.0));
        final List<String> resultWords = [];
        final List<List<double>> resultAttentionMaps = [];
        const int maxLength = 20;

        for (int step = 0; step < maxLength; step++) {
          var inputs = List<Object>.filled(inputTensors.length, Object());
          inputs[decInputIndex] = [[decInput]];
          inputs[imageFeaturesIndex] = reshapedFeatures;
          inputs[hiddenIndex] = hidden;

          var predictions = List.generate(1, (_) => List.filled(10001, 0.0));
          var nextHidden = List.generate(1, (_) => List.filled(512, 0.0));
          var attentionWeights = List.generate(1, (_) => List.generate(64, (_) => List.filled(1, 0.0)));

          var outputs = <int, Object>{
            predictionsIndex: predictions,
            nextHiddenIndex: nextHidden,
            attentionWeightsIndex: attentionWeights,
          };

          decoder.runForMultipleInputs(inputs, outputs);

          // Find argmax token of predictions[0]
          double maxVal = double.negativeInfinity;
          int predictedId = 0;
          for (int k = 0; k < predictions[0].length; k++) {
            if (predictions[0][k] > maxVal) {
              maxVal = predictions[0][k];
              predictedId = k;
            }
          }

          var word = indexToWordMap[predictedId] ?? '<unk>';
          if (word == '<end>') {
            break;
          }

          if (word != '<start>' && word != '<pad>' && word != '<unk>') {
            if (word.startsWith('<start>')) {
              word = word.replaceFirst('<start>', '');
            }
            if (word.isNotEmpty) {
              resultWords.add(word);
              // Save the 64 spatial attention weights for this word step
              final stepWeights = attentionWeights[0].map((e) => e[0]).toList();
              resultAttentionMaps.add(stepWeights);
            }
          }

          decInput = predictedId;
          hidden = nextHidden;
        }

        return CaptionResult(
          resultWords.join(' '),
          resultWords,
          resultAttentionMaps,
        );
      } finally {
        // Clean up interpreters within the isolate
        featureExtractor.close();
        decoder.close();
      }
    });
  }

  void dispose() {}
}
