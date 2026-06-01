import 'package:image_picker/image_picker.dart';

class HomeState {
  final XFile? imageFile;
  final bool isLoading;
  final bool isFetching;
  final bool isSpeaking;
  final String testOutput;
  final String? errorMessage; // Nullable error message
  final String? infoMessage; // Nullable info message
  final List<String> words;
  final List<List<double>> attentionMaps;
  final int? selectedWordIndex;

  HomeState({
    this.imageFile,
    required this.isLoading,
    required this.isFetching,
    required this.isSpeaking,
    required this.testOutput,
    this.errorMessage,
    this.infoMessage,
    required this.words,
    required this.attentionMaps,
    this.selectedWordIndex,
  });

  factory HomeState.initial() => HomeState(
        imageFile: null,
        isLoading: false,
        isFetching: false,
        isSpeaking: false,
        testOutput: '',
        errorMessage: null,
        infoMessage: null,
        words: const [],
        attentionMaps: const [],
        selectedWordIndex: null,
      );

  HomeState copyWith({
    XFile? imageFile,
    bool? isLoading,
    bool? isFetching,
    bool? isSpeaking,
    String? testOutput,
    String? errorMessage,
    String? infoMessage,
    List<String>? words,
    List<List<double>>? attentionMaps,
    int? selectedWordIndex,
    bool clearSelectedWord = false,
  }) {
    return HomeState(
      imageFile: imageFile ?? this.imageFile,
      isLoading: isLoading ?? this.isLoading,
      isFetching: isFetching ?? this.isFetching,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      testOutput: testOutput ?? this.testOutput,
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      words: words ?? this.words,
      attentionMaps: attentionMaps ?? this.attentionMaps,
      selectedWordIndex: clearSelectedWord ? null : (selectedWordIndex ?? this.selectedWordIndex),
    );
  }
}