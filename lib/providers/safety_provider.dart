import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safesite_ai/model/safety_response_model.dart';
import '../repositories/safety_repository.dart';

// Repository Provider
final safetyRepositoryProvider = Provider((ref) => SafetyRepository());

// State Class (100% On-Device)
class SafetyState {
  final bool isLoading;
  final SafetyResponseModel? data;
  final String? errorMessage;
  final File? selectedFile;
  final bool isVideo;
  final Size? imageSize;

  SafetyState({
    this.isLoading = false,
    this.data,
    this.errorMessage,
    this.selectedFile,
    this.isVideo = false,
    this.imageSize,
  });

  bool get isOnDevice => true;

  File? get selectedImage => isVideo ? null : selectedFile;

  SafetyState copyWith({
    bool? isLoading,
    SafetyResponseModel? data,
    String? errorMessage,
    File? selectedFile,
    bool? isVideo,
    Size? imageSize,
  }) {
    return SafetyState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      errorMessage: errorMessage,
      selectedFile: selectedFile ?? this.selectedFile,
      isVideo: isVideo ?? this.isVideo,
      imageSize: imageSize ?? this.imageSize,
    );
  }
}

// StateNotifier
class SafetyNotifier extends StateNotifier<SafetyState> {
  final SafetyRepository _repository;

  SafetyNotifier(this._repository) : super(SafetyState());

  Future<void> analyzeImage(
    File imageFile, {
    double conf = 0.25,
    double iouThresh = 0.45,
  }) async {
    Size? computedSize;
    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = await decodeImageFromList(bytes);
      computedSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
    } catch (_) {}

    state = state.copyWith(
      isLoading: true,
      selectedFile: imageFile,
      isVideo: false,
      imageSize: computedSize,
      errorMessage: null,
    );

    try {
      final result = await _repository.uploadAndDetectImage(
        imageFile,
        conf: conf,
        iouThresh: iouThresh,
      );
      state = state.copyWith(
        isLoading: false,
        data: result,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = SafetyState();
  }
}

// Global Provider
final safetyProvider = StateNotifierProvider<SafetyNotifier, SafetyState>((ref) {
  final repo = ref.read(safetyRepositoryProvider);
  return SafetyNotifier(repo);
});
