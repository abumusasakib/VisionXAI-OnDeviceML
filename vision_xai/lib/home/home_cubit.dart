import 'dart:developer';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vision_xai/home/home_state.dart';
import 'package:vision_xai/l10n/localization_extension.dart';
import 'package:vision_xai/services/tflite_caption_service.dart';

class HomeCubit extends Cubit<HomeState> {
  final ImagePicker _picker = ImagePicker();
  bool _isCaptionGenerationInProgress =
      false; // Track if caption generation is in progress
  bool _shouldStopGeneration = false; // Flag for user stop action

  final FlutterTts _flutterTts = FlutterTts();
  final TfliteCaptionService _tfliteCaptionService = TfliteCaptionService();

  HomeCubit() : super(HomeState.initial()) {
    _configureTts();
    _tfliteCaptionService.init();
  }

  void _configureTts() async {
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage("bn-BD"); // Bengali (Bangladesh)
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      emit(state.copyWith(isSpeaking: true));
    });

    _flutterTts.setCompletionHandler(() {
      emit(state.copyWith(isSpeaking: false));
    });

    _flutterTts.setCancelHandler(() {
      emit(state.copyWith(isSpeaking: false));
    });

    _flutterTts.setErrorHandler((msg) {
      emit(state.copyWith(isSpeaking: false));
    });

    if (Platform.isIOS) {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.ambient,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
  }

  Future<void> speakCaption(String text, BuildContext context) async {
    try {
      await _flutterTts.stop(); // Stop any previous speech
      emit(state.copyWith(isSpeaking: true));
      await _flutterTts.speak(text);
      emit(state.copyWith(isSpeaking: false));
    } catch (e, stackTrace) {
      emit(state.copyWith(isSpeaking: false));
      if (context.mounted) {
        emit(state.copyWith(
            errorMessage: context.tr.failedToSpeak, isSpeaking: false));
      }
      log('Exception in speakCaption: $e',
          stackTrace: stackTrace, name: 'HomeCubit');
    }
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    emit(state.copyWith(isSpeaking: false));
  }

  @override
  Future<void> close() {
    _flutterTts.stop();
    _tfliteCaptionService.dispose();
    return super.close();
  }

  Future<void> selectImage(XFile file) async {
    emit(state.copyWith(
      imageFile: file,
      testOutput: '',
      words: const [],
      attentionMaps: const [],
      clearSelectedWord: true,
    ));
  }

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      selectImage(pickedFile);
    }
  }

  /// Handles local caption generation for the selected image
  Future<void> uploadAndGenerateCaption(BuildContext context) async {
    if (state.imageFile == null) {
      emit(state.copyWith(errorMessage: context.tr.noImageSelected));
      return;
    }

    _shouldStopGeneration = false; // 🔁 Reset stop flag
    _isCaptionGenerationInProgress = true;

    emit(state.copyWith(
      isLoading: true,
      errorMessage: null,
      words: const [],
      attentionMaps: const [],
      clearSelectedWord: true,
    ));

    try {
      final captionResult = await _tfliteCaptionService.generateCaption(state.imageFile!.path);

      if (_shouldStopGeneration) {
        if (context.mounted) {
          emit(state.copyWith(
              infoMessage: context.tr.captionStopped, isLoading: false));
        }
        return;
      }

      if (captionResult.caption.isEmpty) {
        if (context.mounted) {
          emit(state.copyWith(
            errorMessage: context.tr.captionMissing,
            isLoading: false,
          ));
        }
      } else {
        emit(state.copyWith(
          testOutput: captionResult.caption,
          words: captionResult.words,
          attentionMaps: captionResult.attentionMaps,
          isLoading: false,
        ));
      }
    } catch (e, stackTrace) {
      log('Exception in uploadAndGenerateCaption: $e',
          stackTrace: stackTrace, name: 'HomeCubit');
      if (context.mounted) {
        emit(state.copyWith(
          errorMessage: context.tr.unknownError,
          isLoading: false,
        ));
      }
    } finally {
      _isCaptionGenerationInProgress = false;
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Updates the currently selected word index for XAI attention visualization overlay
  void selectWord(int? index) {
    if (state.selectedWordIndex == index) {
      emit(state.copyWith(clearSelectedWord: true));
    } else {
      emit(state.copyWith(selectedWordIndex: index));
    }
  }

  /// Stops the caption generation process
  void stopCaptionGeneration(BuildContext context) {
    if (!_isCaptionGenerationInProgress) {
      emit(state.copyWith(errorMessage: context.tr.noCaptionInProgress));
      return;
    }

    // Set the flag to stop the process
    _shouldStopGeneration = true;
    emit(state.copyWith(
      infoMessage: context.tr.captionStoppedShort,
      isLoading: false,
    ));
  }

  /// Clears the info message from the state
  void clearInfoMessage() {
    emit(state.copyWith(infoMessage: null));
  }

  /// Resets the state of the HomeCubit
  void reset() {
    _isCaptionGenerationInProgress = false;
    _shouldStopGeneration = false;
    emit(HomeState.initial());
    emit(state.copyWith(errorMessage: null));
  }
}
