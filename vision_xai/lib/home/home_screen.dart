import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Import for kIsWeb

import 'package:vision_xai/home/home_cubit.dart';
import 'package:vision_xai/home/home_state.dart';
import 'package:vision_xai/l10n/localization_extension.dart';
import 'package:vision_xai/routes/app_routes.dart';
import 'package:vision_xai/settings/settings_cubit.dart';
import 'package:vision_xai/settings/settings_state.dart';
import 'package:vision_xai/widgets/attention_painter.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr.appTitle),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              // Navigate to the settings page
              context.push(AppRoutes.settings);
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<SettingsCubit, SettingsState>(
            listener: (context, state) {
              debugPrint(
                  'BlocListener detected state change: ${state.currentLocale.languageCode}');
            },
          ),
          BlocListener<HomeCubit, HomeState>(
            listener: (context, state) {
              if (state.errorMessage != null) {
                // Show error dialog
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(context.tr.errorTitle),
                      content: Text(state.errorMessage!),
                      actions: [
                        TextButton(
                          onPressed: () {
                            context.read<HomeCubit>().reset();
                            Navigator.of(context).pop();
                          },
                          child: Text(context.tr.ok),
                        ),
                      ],
                    );
                  },
                );
              }
            },
          ),
          BlocListener<HomeCubit, HomeState>(
            listenWhen: (previous, current) =>
                current.infoMessage != null &&
                current.infoMessage != previous.infoMessage,
            listener: (context, state) {
              if (state.infoMessage != null) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(state.infoMessage!),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 2500),
                  ),
                );
                context.read<HomeCubit>().clearInfoMessage();
              }
            },
          ),
        ],
        child: BlocConsumer<HomeCubit, HomeState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              // Handle errors
              debugPrint('Error: ${state.errorMessage}');
            }
          },
          builder: (context, state) {
            final cubit = context.read<HomeCubit>();
            final picker = ImagePicker();

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth > 600;

                return SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: isWideScreen
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildImageDisplay(context, state),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildControls(
                                      context, cubit, state, picker),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize
                                  .min, // Ensuring Column doesn't expand indefinitely
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildImageDisplay(context, state),
                                const SizedBox(height: 16),
                                _buildControls(context, cubit, state, picker),
                              ],
                            ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<Size> _getImageSize(XFile imageFile) async {
    final Completer<Size> completer = Completer();
    final ImageProvider provider = kIsWeb
        ? NetworkImage(imageFile.path)
        : FileImage(File(imageFile.path)) as ImageProvider;
    provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!completer.isCompleted) {
            completer.complete(Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ));
          }
        },
        onError: (exception, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(exception, stackTrace);
          }
        },
      ),
    );
    return completer.future;
  }

  Widget _buildImageDisplay(BuildContext context, HomeState state) {
    if (state.imageFile != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () => _showPreviewDialog(context, state.imageFile!, state),
            onLongPress: () => _showPreviewDialog(context, state.imageFile!, state),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: kIsWeb
                  ? Image.network(
                      state.imageFile!.path,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(state.imageFile!.path),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          if (state.selectedWordIndex != null &&
              state.selectedWordIndex! < state.attentionMaps.length)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: AttentionPainter(
                      state.attentionMaps[state.selectedWordIndex!],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // Fallback placeholder
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54, width: 2),
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(context.tr.noImageSelected),
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, XFile imageFile, HomeState state) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.8,
              maxWidth: screenWidth * 0.9,
            ),
            child: FutureBuilder<Size>(
              future: _getImageSize(imageFile),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text('Failed to load image'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final size = snapshot.data!;
                final imageAspectRatio = size.width / size.height;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ClipRRect(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                        child: AspectRatio(
                          aspectRatio: imageAspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              kIsWeb
                                  ? Image.network(
                                      imageFile.path,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(imageFile.path),
                                      fit: BoxFit.cover,
                                    ),
                              if (state.selectedWordIndex != null &&
                                  state.selectedWordIndex! < state.attentionMaps.length)
                                IgnorePointer(
                                  child: CustomPaint(
                                    painter: AttentionPainter(
                                      state.attentionMaps[state.selectedWordIndex!],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.tr.ok),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context, HomeCubit cubit, HomeState state,
      ImagePicker picker) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Button to Select Image
        ElevatedButton.icon(
          onPressed: () async {
            final pickedImage = await picker.pickImage(
              source: ImageSource.gallery,
            );
            if (pickedImage != null) {
              cubit.selectImage(pickedImage);
            }
          },
          icon: const Icon(Icons.photo_library),
          label: Text(context.tr.selectImageFromGallery),
        ),
        const SizedBox(height: 16),
        if (!kIsWeb && !Platform.isWindows)
          ElevatedButton.icon(
            onPressed: () async {
              final pickedImage = await picker.pickImage(
                source: ImageSource.camera,
              );
              if (pickedImage != null) {
                cubit.selectImage(pickedImage);
              }
            },
            icon: const Icon(Icons.camera_alt),
            label: Text(context.tr.camera),
          ),
        const SizedBox(height: 16),
        // Button to Upload Image
        ElevatedButton.icon(
          onPressed: state.isLoading
              ? null
              : () {
                  cubit.uploadAndGenerateCaption(context);
                },
          icon: const Icon(Icons.cloud_upload),
          label: state.isLoading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
              : Text(context.tr.generateCaption),
        ),
        const SizedBox(height: 16),
        if (state.isLoading)
          ElevatedButton.icon(
            onPressed: () {
              cubit.stopCaptionGeneration(context);
            },
            icon: const Icon(Icons.stop),
            label: Text(context.tr.stopCaptionGeneration),
          ),
        const SizedBox(height: 16),
        if (state.isLoading)
          Center(
            child: Text(
              context.tr.generatingCaption,
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 16),
        // Text Output for Caption
        Container(
          constraints: const BoxConstraints(minHeight: 100),
          child: Center(
            child: state.testOutput.isNotEmpty
                ? Column(
                    children: [
                      Text(
                        state.testOutput,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 18, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      state.words.isNotEmpty
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(state.words.length, (index) {
                                  final word = state.words[index];
                                  final isSelected = state.selectedWordIndex == index;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ChoiceChip(
                                      label: Text(
                                        word,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: Theme.of(context).colorScheme.primary,
                                      backgroundColor: Colors.grey.shade200,
                                      onSelected: (selected) {
                                        cubit.selectWord(index);
                                      },
                                    ),
                                  );
                                }),
                              ),
                            )
                          : const SizedBox(),
                      const SizedBox(height: 12),
                      if (!kIsWeb && !Platform.isWindows)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          child: state.isSpeaking
                              // Stop button (only visible when speaking)
                              ? ElevatedButton.icon(
                                  key: const ValueKey('stopButton'),
                                  onPressed: () {
                                    context.read<HomeCubit>().stopSpeaking();
                                  },
                                  icon: const Icon(Icons.stop),
                                  label: Text(context.tr.stop),
                                )
                              // Listen button (only visible when not speaking)
                              : ElevatedButton.icon(
                                  key: const ValueKey('listenButton'),
                                  onPressed: () {
                                    context
                                        .read<HomeCubit>()
                                        .speakCaption(state.testOutput, context);
                                  },
                                  icon: const Icon(Icons.volume_up),
                                  label: Text(context.tr.listen),
                                ),
                        ),
                    ],
                  )
                : Text(
                    context.tr.captionText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.black54),
                  ),
          ),
        ),
      ],
    );
  }
}
