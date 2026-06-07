class CaptionResult {
  final String caption;
  final List<String> words;
  final List<List<double>> attentionMaps;

  CaptionResult(this.caption, this.words, this.attentionMaps);
}

class TfliteCaptionService {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Web initialization stub
  Future<void> init() async {
    _isInitialized = true;
  }

  /// Web caption generator stub. Returns a fallback/mock caption and generic attention weights.
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

  void dispose() {}
}
