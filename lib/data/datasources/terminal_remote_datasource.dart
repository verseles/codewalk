import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../models/pty_session_model.dart';

abstract class TerminalRemoteDataSource {
  Future<PtySessionModel> createPty({required String directory});

  Future<void> resizePty({
    required String ptyId,
    required String directory,
    required int rows,
    required int cols,
  });

  Future<void> deletePty({required String ptyId, required String directory});
}

class TerminalRemoteDataSourceImpl implements TerminalRemoteDataSource {
  TerminalRemoteDataSourceImpl({required this.dio});

  final Dio dio;

  @override
  Future<PtySessionModel> createPty({required String directory}) async {
    try {
      final response = await dio.post(
        ApiConstants.ptyEndpoint,
        data: <String, dynamic>{'cwd': directory},
        queryParameters: <String, String>{'directory': directory},
      );
      if (response.statusCode != 200) {
        throw ServerException(
          L10nBridge.current?.terminalCreateFailed ??
              'Failed to create terminal session',
        );
      }
      return PtySessionModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw NotFoundException(
          L10nBridge.current?.terminalEndpointUnavailable ??
              'Terminal endpoint is not available',
        );
      }
      if (error.response?.statusCode == 400) {
        throw ValidationException(
          L10nBridge.current?.terminalInvalidDirectory ??
              'Invalid terminal directory',
        );
      }
      throw ServerException(
        L10nBridge.current?.terminalCreateFailed ??
            'Failed to create terminal session',
      );
    }
  }

  @override
  Future<void> resizePty({
    required String ptyId,
    required String directory,
    required int rows,
    required int cols,
  }) async {
    try {
      final response = await dio.put(
        '${ApiConstants.ptyEndpoint}/$ptyId',
        data: <String, dynamic>{
          'size': <String, int>{'rows': rows, 'cols': cols},
        },
        queryParameters: <String, String>{'directory': directory},
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to resize terminal session');
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw const NotFoundException('Terminal session not found');
      }
      throw const ServerException('Failed to resize terminal session');
    }
  }

  @override
  Future<void> deletePty({
    required String ptyId,
    required String directory,
  }) async {
    try {
      final response = await dio.delete(
        '${ApiConstants.ptyEndpoint}/$ptyId',
        queryParameters: <String, String>{'directory': directory},
      );
      if (response.statusCode != 200) {
        throw const ServerException('Failed to close terminal session');
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return;
      }
      throw const ServerException('Failed to close terminal session');
    }
  }
}
