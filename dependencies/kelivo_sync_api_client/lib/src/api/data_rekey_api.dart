//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:dio/dio.dart';

import 'package:kelivo_sync_api_client/src/model/claim_data_rekey_lease_response.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_attachment_stage_request.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_finalize_request.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_lease_claim_request.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_record_stage_request.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_source_attachment_list_request.dart';
import 'package:kelivo_sync_api_client/src/model/data_rekey_source_record_list_request.dart';
import 'package:kelivo_sync_api_client/src/model/error_response.dart';
import 'package:kelivo_sync_api_client/src/model/finalize_data_rekey_response.dart';
import 'package:kelivo_sync_api_client/src/model/get_data_rekey_state_response.dart';
import 'package:kelivo_sync_api_client/src/model/list_data_rekey_source_attachments_response.dart';
import 'package:kelivo_sync_api_client/src/model/list_data_rekey_source_records_response.dart';
import 'package:kelivo_sync_api_client/src/model/stage_data_rekey_attachment_response.dart';
import 'package:kelivo_sync_api_client/src/model/stage_data_rekey_record_response.dart';

class DataRekeyApi {
  final Dio _dio;

  final Serializers _serializers;

  const DataRekeyApi(this._dio, this._serializers);

  /// 领取、续期或接管数据重加密租约
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [dataRekeyLeaseClaimRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [ClaimDataRekeyLeaseResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<ClaimDataRekeyLeaseResponse>> claimDataRekeyLease({
    required String xKelivoSyncProtocolVersion,
    required DataRekeyLeaseClaimRequest dataRekeyLeaseClaimRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/data-rekey/lease/claim';
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
      const _type = FullType(DataRekeyLeaseClaimRequest);
      _bodyData = _serializers.serialize(
        dataRekeyLeaseClaimRequest,
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

    ClaimDataRekeyLeaseResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(ClaimDataRekeyLeaseResponse),
                )
                as ClaimDataRekeyLeaseResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<ClaimDataRekeyLeaseResponse>(
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

  /// 验签并原子切换全部密文数据
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [dataRekeyFinalizeRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [FinalizeDataRekeyResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<FinalizeDataRekeyResponse>> finalizeDataRekey({
    required String xKelivoSyncProtocolVersion,
    required DataRekeyFinalizeRequest dataRekeyFinalizeRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/data-rekey/operation/finalize';
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
      const _type = FullType(DataRekeyFinalizeRequest);
      _bodyData = _serializers.serialize(
        dataRekeyFinalizeRequest,
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

    FinalizeDataRekeyResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(FinalizeDataRekeyResponse),
                )
                as FinalizeDataRekeyResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<FinalizeDataRekeyResponse>(
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

  /// 读取账户数据重加密状态与最近完成证明
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [GetDataRekeyStateResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<GetDataRekeyStateResponse>> getDataRekeyState({
    required String xKelivoSyncProtocolVersion,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/data-rekey/state/get';
    final _options = Options(
      method: r'GET',
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
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    GetDataRekeyStateResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(GetDataRekeyStateResponse),
                )
                as GetDataRekeyStateResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<GetDataRekeyStateResponse>(
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

  /// 分页读取冻结的附件 manifest 与 chunk 元数据
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [dataRekeySourceAttachmentListRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [ListDataRekeySourceAttachmentsResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<ListDataRekeySourceAttachmentsResponse>>
  listDataRekeySourceAttachments({
    required String xKelivoSyncProtocolVersion,
    required DataRekeySourceAttachmentListRequest
    dataRekeySourceAttachmentListRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/data-rekey/source/attachment-list';
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
      const _type = FullType(DataRekeySourceAttachmentListRequest);
      _bodyData = _serializers.serialize(
        dataRekeySourceAttachmentListRequest,
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

    ListDataRekeySourceAttachmentsResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(
                    ListDataRekeySourceAttachmentsResponse,
                  ),
                )
                as ListDataRekeySourceAttachmentsResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<ListDataRekeySourceAttachmentsResponse>(
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

  /// 分页读取冻结的源密文记录
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [dataRekeySourceRecordListRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [ListDataRekeySourceRecordsResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<ListDataRekeySourceRecordsResponse>>
  listDataRekeySourceRecords({
    required String xKelivoSyncProtocolVersion,
    required DataRekeySourceRecordListRequest dataRekeySourceRecordListRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/data-rekey/source/record-list';
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
      const _type = FullType(DataRekeySourceRecordListRequest);
      _bodyData = _serializers.serialize(
        dataRekeySourceRecordListRequest,
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

    ListDataRekeySourceRecordsResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(
                    ListDataRekeySourceRecordsResponse,
                  ),
                )
                as ListDataRekeySourceRecordsResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<ListDataRekeySourceRecordsResponse>(
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

  /// 暂存附件新代 manifest 与 ADK 包装
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [dataRekeyAttachmentStageRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [StageDataRekeyAttachmentResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<StageDataRekeyAttachmentResponse>> stageDataRekeyAttachment({
    required String xKelivoSyncProtocolVersion,
    required DataRekeyAttachmentStageRequest dataRekeyAttachmentStageRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/data-rekey/attachment/stage';
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
      const _type = FullType(DataRekeyAttachmentStageRequest);
      _bodyData = _serializers.serialize(
        dataRekeyAttachmentStageRequest,
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

    StageDataRekeyAttachmentResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(
                    StageDataRekeyAttachmentResponse,
                  ),
                )
                as StageDataRekeyAttachmentResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<StageDataRekeyAttachmentResponse>(
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

  /// 暂存单条新代不透明记录
  ///
  ///
  /// Parameters:
  /// * [xKelivoSyncProtocolVersion]
  /// * [dataRekeyRecordStageRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [StageDataRekeyRecordResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<StageDataRekeyRecordResponse>> stageDataRekeyRecord({
    required String xKelivoSyncProtocolVersion,
    required DataRekeyRecordStageRequest dataRekeyRecordStageRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/data-rekey/record/stage';
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
      const _type = FullType(DataRekeyRecordStageRequest);
      _bodyData = _serializers.serialize(
        dataRekeyRecordStageRequest,
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

    StageDataRekeyRecordResponse? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
                  rawResponse,
                  specifiedType: const FullType(StageDataRekeyRecordResponse),
                )
                as StageDataRekeyRecordResponse;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<StageDataRekeyRecordResponse>(
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
