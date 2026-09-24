import '../../domain/entities/experience_settings.dart';

class NemotronModelManager {
  String normalizeModelId(String? modelId) => kNemotronModelDefault;

  void setPreferredModelId(String modelId) {}

  String getPreferredModelId() => kNemotronModelDefault;

  Future<String?> findInstalledModelId() async => null;

  Future<bool> hasModel(String modelId) async => false;

  Future<void> downloadModel(
    String modelId, {
    void Function(double)? onProgress,
  }) async {}

  Future<void> deleteModel(String modelId) async {}

  Future<String> getModelDir(String modelId) async => '';
}
