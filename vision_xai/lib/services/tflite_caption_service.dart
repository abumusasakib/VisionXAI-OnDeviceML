import 'tflite_caption_service_mobile.dart'
    if (dart.library.html) 'tflite_caption_service_web.dart' as platform;

class CaptionResult {
  final String caption;
  final List<String> words;
  final List<List<double>> attentionMaps;

  CaptionResult(this.caption, this.words, this.attentionMaps);
}

abstract class TfliteCaptionService {
  bool get isInitialized;

  Future<void> init();

  Future<CaptionResult> generateCaption(String imagePath);

  void dispose();

  factory TfliteCaptionService() => platform.TfliteCaptionServiceImpl();
}
