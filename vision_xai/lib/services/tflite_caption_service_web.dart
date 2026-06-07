import 'tflite_caption_service.dart';

class TfliteCaptionServiceImpl implements TfliteCaptionService {
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> init() async {
    _isInitialized = true;
  }

  @override
  Future<CaptionResult> generateCaption(String imagePath) async {
    const mockCaption = "অন-ডিভাইস ক্যাপশন ওয়েবে সমর্থিত নয় (On-device captioning is not supported on Web)";
    const mockWords = ["অন-ডিভাইস", "ক্যাপশন", "ওয়েবে", "সমর্থিত", "নয়"];
    
    // Create generic flat 8x8 (64 elements) attention maps for each word
    final mockAttentionMaps = List.generate(
      mockWords.length, 
      (_) => List.filled(64, 0.2)
    );

    return CaptionResult(
      mockCaption,
      mockWords,
      mockAttentionMaps,
    );
  }

  @override
  void dispose() {}
}
