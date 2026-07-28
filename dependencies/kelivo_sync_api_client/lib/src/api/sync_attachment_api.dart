//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:dio/dio.dart';

import 'package:kelivo_sync_api_client/src/model/attachment_commit_upload_request.dart';
import 'package:kelivo_sync_api_client/src/model/attachment_create_upload_request.dart';
import 'package:kelivo_sync_api_client/src/model/attachment_delete_request.dart';
import 'package:kelivo_sync_api_client/src/model/attachment_get_chunk_request.dart';
import 'package:kelivo_sync_api_client/src/model/attachment_get_manifest_request.dart';
import 'package:kelivo_sync_api_client/src/model/attachment_put_chunk_request.dart';
import 'package:kelivo_sync_api_client/src/model/commit_encrypted_attachment_upload_response.dart';
import 'package:kelivo_sync_api_client/src/model/create_encrypted_attachment_upload_response.dart';
import 'package:kelivo_sync_api_client/src/model/delete_encrypted_attachment_response.dart';
import 'package:kelivo_sync_api_client/src/model/error_response.dart';
import 'package:kelivo_sync_api_client/src/model/get_encrypted_attachment_chunk_response.dart';
import 'package:kelivo_sync_api_client/src/model/get_encrypted_attachment_manifest_response.dart';
import 'package:kelivo_sync_api_client/src/model/put_encrypted_attachment_chunk_response.dart';

class SyncAttachmentApi {
  final Dio _dio;

  final Serializers _serializers;

  const SyncAttachmentApi(this._dio, this._serializers);

  /// 提交认证清单并完成附件密文上传
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [attachmentCommitUploadRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CommitEncryptedAttachmentUploadResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CommitEncryptedAttachmentUploadResponse>>
  commitEncryptedAttachmentUpload({
    required String xKelivoSyncProtocolVersion,
    required AttachmentCommitUploadRequest attachmentCommitUploadRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/sync/attachment/upload/commit';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'x-kelivo-sync-protocol-version': xKelivoSyncProtocolVersion,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'BearerAuth'},
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      const _type = FullType(AttachmentCommitUploadRequest);
      _bodyData = _serializers.serialize(
        attachmentCommitUploadRequest,
        specifiedType: _type,
      );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    CommitEncryptedAttachmentUploadResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(
                    CommitEncryptedAttachmentUploadResponse,
                  ),
                )
                as CommitEncryptedAttachmentUploadResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CommitEncryptedAttachmentUploadResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// 创建不透明附件密文上传
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [attachmentCreateUploadRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CreateEncryptedAttachmentUploadResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CreateEncryptedAttachmentUploadResponse>>
  createEncryptedAttachmentUpload({
    required String xKelivoSyncProtocolVersion,
    required AttachmentCreateUploadRequest attachmentCreateUploadRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/sync/attachment/upload/create';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'x-kelivo-sync-protocol-version': xKelivoSyncProtocolVersion,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'BearerAuth'},
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      const _type = FullType(AttachmentCreateUploadRequest);
      _bodyData = _serializers.serialize(
        attachmentCreateUploadRequest,
        specifiedType: _type,
      );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    CreateEncryptedAttachmentUploadResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(
                    CreateEncryptedAttachmentUploadResponse,
                  ),
                )
                as CreateEncryptedAttachmentUploadResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CreateEncryptedAttachmentUploadResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// 写入附件墓碑并删除密文对象
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [attachmentDeleteRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [DeleteEncryptedAttachmentResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<DeleteEncryptedAttachmentResponse>>
  deleteEncryptedAttachment({
    required String xKelivoSyncProtocolVersion,
    required AttachmentDeleteRequest attachmentDeleteRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/sync/attachment/record/delete';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'x-kelivo-sync-protocol-version': xKelivoSyncProtocolVersion,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'BearerAuth'},
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      const _type = FullType(AttachmentDeleteRequest);
      _bodyData = _serializers.serialize(
        attachmentDeleteRequest,
        specifiedType: _type,
      );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    DeleteEncryptedAttachmentResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(
                    DeleteEncryptedAttachmentResponse,
                  ),
                )
                as DeleteEncryptedAttachmentResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<DeleteEncryptedAttachmentResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// 读取单个附件密文分块
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [attachmentGetChunkRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetEncryptedAttachmentChunkResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetEncryptedAttachmentChunkResponse>>
  getEncryptedAttachmentChunk({
    required String xKelivoSyncProtocolVersion,
    required AttachmentGetChunkRequest attachmentGetChunkRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/sync/attachment/chunk/get';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'x-kelivo-sync-protocol-version': xKelivoSyncProtocolVersion,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'BearerAuth'},
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      const _type = FullType(AttachmentGetChunkRequest);
      _bodyData = _serializers.serialize(
        attachmentGetChunkRequest,
        specifiedType: _type,
      );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    GetEncryptedAttachmentChunkResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(
                    GetEncryptedAttachmentChunkResponse,
                  ),
                )
                as GetEncryptedAttachmentChunkResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetEncryptedAttachmentChunkResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// 读取附件认证清单密文
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [attachmentGetManifestRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetEncryptedAttachmentManifestResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetEncryptedAttachmentManifestResponse>>
  getEncryptedAttachmentManifest({
    required String xKelivoSyncProtocolVersion,
    required AttachmentGetManifestRequest attachmentGetManifestRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/sync/attachment/manifest/get';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'x-kelivo-sync-protocol-version': xKelivoSyncProtocolVersion,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'BearerAuth'},
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      const _type = FullType(AttachmentGetManifestRequest);
      _bodyData = _serializers.serialize(
        attachmentGetManifestRequest,
        specifiedType: _type,
      );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    GetEncryptedAttachmentManifestResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(
                    GetEncryptedAttachmentManifestResponse,
                  ),
                )
                as GetEncryptedAttachmentManifestResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetEncryptedAttachmentManifestResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// 幂等写入单个附件密文分块
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [attachmentPutChunkRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [PutEncryptedAttachmentChunkResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<PutEncryptedAttachmentChunkResponse>>
  putEncryptedAttachmentChunk({
    required String xKelivoSyncProtocolVersion,
    required AttachmentPutChunkRequest attachmentPutChunkRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/sync/attachment/chunk/put';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'x-kelivo-sync-protocol-version': xKelivoSyncProtocolVersion,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'BearerAuth'},
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      const _type = FullType(AttachmentPutChunkRequest);
      _bodyData = _serializers.serialize(
        attachmentPutChunkRequest,
        specifiedType: _type,
      );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    PutEncryptedAttachmentChunkResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(
                    PutEncryptedAttachmentChunkResponse,
                  ),
                )
                as PutEncryptedAttachmentChunkResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<PutEncryptedAttachmentChunkResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }
}
