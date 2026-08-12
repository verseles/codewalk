import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import 'oauth_credential.dart';
import 'oauth_service_result.dart';
import 'oauth_token_storage.dart';

enum OAuthCallbackDecision {
  ignoreWrongPath,
  acceptCode,
  rejectProviderError,
  rejectTerminal,
}

class OAuthCallbackValidation {
  const OAuthCallbackValidation(this.decision, [this.code]);

  final OAuthCallbackDecision decision;
  final String? code;

  bool get isTerminal => decision != OAuthCallbackDecision.ignoreWrongPath;
}

class OAuthCallbackCompletionGuard {
  bool _isTerminal = false;

  bool get isTerminal => _isTerminal;

  bool tryMarkTerminal() {
    if (_isTerminal) return false;
    _isTerminal = true;
    return true;
  }
}

/// Outcome of the browser round-trip: an authorization [code] on success,
/// or a user-readable [failureReason] describing exactly which step failed.
class _CallbackResult {
  _CallbackResult.code(this.code) : failureReason = null;
  _CallbackResult.failure(this.failureReason) : code = null;

  final String? code;
  final String? failureReason;
}

/// Outcome of the PKCE flow: token [data] on success, or a user-readable
/// [error] describing exactly which step failed.
class _PkceResult {
  _PkceResult.data(this.data) : error = null;
  _PkceResult.failure(this.error) : data = null;

  final Map<String, dynamic>? data;
  final String? error;
}

/// Outcome of the authorization-code exchange at the token endpoint.
class _ExchangeResult {
  _ExchangeResult.data(this.data) : error = null;
  _ExchangeResult.failure(this.error) : data = null;

  final Map<String, dynamic>? data;
  final String? error;
}

class OAuthService {
  OAuthService({
    required this.profileId,
    required this.serverUrl,
    this.challengeHeaders,
    this.challengeBody,
    bool Function()? shouldPersistCredential,
    OAuthTokenStorage? storage,
  }) : _shouldPersistCredential = shouldPersistCredential,
       _storage = storage ?? OAuthTokenStorage();

  static const _androidChannel = MethodChannel('codewalk/system');
  static const _bodyTimeout = Duration(seconds: 15);
  static const _maxJsonBodyBytes = 256 * 1024;
  static const _maxDiscoveryBodyBytes = 1024 * 1024;
  static final Map<String, void Function()> _androidCloseListeners =
      <String, void Function()>{};
  static bool _androidCloseHandlerInstalled = false;

  final String profileId;
  final String serverUrl;
  final Map<String, String>? challengeHeaders;
  final String? challengeBody;

  final bool Function()? _shouldPersistCredential;
  final OAuthTokenStorage _storage;

  static String loopbackRedirectUriForPort(int port) {
    if (port < 1 || port > 65535) {
      throw RangeError.range(port, 1, 65535, 'port');
    }
    return 'http://127.0.0.1:$port/oauth/callback';
  }

  static Map<String, dynamic> clientRegistrationPayload({
    required String redirectUri,
    required String resource,
  }) {
    return <String, dynamic>{
      'redirect_uris': <String>[redirectUri],
      'token_endpoint_auth_method': 'none',
      'grant_types': <String>['authorization_code', 'refresh_token'],
      'response_types': <String>['code'],
      'client_name': 'CodeWalk',
      'client_uri': 'https://github.com/verseles/codewalk',
      'resource': resource,
    };
  }

  static Map<String, String> authorizationParameters({
    required String redirectUri,
    required String challenge,
    required String state,
    required String resource,
    String? clientId,
  }) {
    return <String, String>{
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'resource': resource,
      'client_id': ?clientId,
    };
  }

  static Map<String, String> authorizationCodeParameters({
    required String code,
    required String verifier,
    required String redirectUri,
    required String resource,
    String? clientId,
  }) {
    return <String, String>{
      'grant_type': 'authorization_code',
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': redirectUri,
      'resource': resource,
      'client_id': ?clientId,
    };
  }

  static bool canRetryAuthorizationCodeExchange({
    required Object error,
    required bool requestMayHaveBeenSent,
  }) {
    return !requestMayHaveBeenSent &&
        (error is SocketException ||
            error is TimeoutException ||
            error is HandshakeException);
  }

  static Future<String> readBoundedBody(
    Stream<List<int>> body, {
    Duration timeout = _bodyTimeout,
    int maxBytes = _maxJsonBodyBytes,
  }) async {
    final bytes = await _readBoundedBytes(
      body,
      timeout: timeout,
      maxBytes: maxBytes,
    );
    return utf8.decode(bytes);
  }

  static Future<Uint8List> _readBoundedBytes(
    Stream<List<int>> body, {
    required Duration timeout,
    required int maxBytes,
  }) async {
    final iterator = StreamIterator<List<int>>(body);
    final stopwatch = Stopwatch()..start();
    final bytes = BytesBuilder(copy: false);
    try {
      while (true) {
        final remaining = timeout - stopwatch.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('OAuth response body timed out.', timeout);
        }
        final hasNext = await iterator.moveNext().timeout(remaining);
        if (!hasNext) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('OAuth response body is too large.');
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } finally {
      stopwatch.stop();
      await iterator.cancel();
    }
  }

  static bool isOAuthChallenge(int statusCode, Map<String, String> headers) {
    if (statusCode != 401 && statusCode != 403) return false;
    final auth = headers['www-authenticate'] ?? '';
    return auth.startsWith('Bearer ') || auth.startsWith('Cloudflare-Access');
  }

  static bool isCloudflareAccessHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'cloudflareaccess.com' ||
        lower.endsWith('.cloudflareaccess.com');
  }

  static bool isTrustedOAuthEndpoint(String? value) {
    if (value == null || value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      return false;
    }
    return isCloudflareAccessHost(uri.host);
  }

  static bool isTrustedOAuthMetadataEndpoint({
    required String? value,
    required String serverUrl,
  }) {
    if (value == null || value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    if (isCloudflareAccessHost(uri.host)) {
      return !uri.hasPort || uri.port == 443;
    }

    var normalizedServerUrl = serverUrl.trim();
    if (!normalizedServerUrl.contains('://')) {
      normalizedServerUrl = 'http://$normalizedServerUrl';
    }
    final server = Uri.tryParse(normalizedServerUrl);
    if (server == null || server.scheme != 'https' || server.host.isEmpty) {
      return false;
    }
    final serverPort = server.hasPort ? server.port : 443;
    final endpointPort = uri.hasPort ? uri.port : 443;
    return uri.host == server.host && endpointPort == serverPort;
  }

  static OAuthCallbackValidation validateCallback({
    required String method,
    required Uri requestTarget,
    required String requestScheme,
    required String? hostHeader,
    required Uri expectedRedirectUri,
    required String expectedState,
  }) {
    if (_rawRequestPath(requestTarget) != expectedRedirectUri.path) {
      return const OAuthCallbackValidation(
        OAuthCallbackDecision.ignoreWrongPath,
      );
    }

    final requestUri = _absoluteCallbackUri(
      requestTarget: requestTarget,
      requestScheme: requestScheme,
      hostHeader: hostHeader,
    );
    if (method != 'GET' ||
        requestUri == null ||
        requestUri.scheme != expectedRedirectUri.scheme ||
        requestUri.host != expectedRedirectUri.host ||
        requestUri.port != expectedRedirectUri.port ||
        requestUri.path != expectedRedirectUri.path) {
      return const OAuthCallbackValidation(
        OAuthCallbackDecision.rejectTerminal,
      );
    }

    final parameters = requestTarget.queryParametersAll;
    final states = parameters['state'];
    if (!_hasSingleNonEmptyValue(states) || states!.single != expectedState) {
      return const OAuthCallbackValidation(
        OAuthCallbackDecision.rejectTerminal,
      );
    }

    final codes = parameters['code'];
    final errors = parameters['error'];
    final hasCode = codes != null;
    final hasError = errors != null;
    if (hasCode && !hasError && _hasSingleNonEmptyValue(codes)) {
      return OAuthCallbackValidation(
        OAuthCallbackDecision.acceptCode,
        codes.single,
      );
    }
    if (hasError && !hasCode && _hasSingleNonEmptyValue(errors)) {
      return const OAuthCallbackValidation(
        OAuthCallbackDecision.rejectProviderError,
      );
    }
    return const OAuthCallbackValidation(OAuthCallbackDecision.rejectTerminal);
  }

  static String tokenExchangeHttpFailure(int statusCode) {
    return L10nBridge.current?.oauthFlowTokenExchangeHttpFailure(statusCode) ??
        'Token exchange failed (HTTP $statusCode). Please try again.';
  }

  static Uri? _absoluteCallbackUri({
    required Uri requestTarget,
    required String requestScheme,
    required String? hostHeader,
  }) {
    if (hostHeader == null || hostHeader.isEmpty) return null;
    final origin = Uri.tryParse('$requestScheme://$hostHeader');
    if (origin == null ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.path.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment) {
      return null;
    }
    return origin.replace(path: requestTarget.path);
  }

  static String _rawRequestPath(Uri requestTarget) {
    final value = requestTarget.toString();
    final queryStart = value.indexOf('?');
    return queryStart == -1 ? value : value.substring(0, queryStart);
  }

  static bool _hasSingleNonEmptyValue(List<String>? values) {
    return values != null && values.length == 1 && values.single.isNotEmpty;
  }

  Future<OAuthCredential?> getCachedCredential() async {
    final credential = await _storage.loadCredential(
      profileId: profileId,
      serverUrl: serverUrl,
    );
    if (credential != null && credential.isValid) return credential;
    return null;
  }

  Future<OAuthFlowResult> authenticate({bool skipCache = false}) async {
    try {
      return await _authenticate(skipCache: skipCache);
    } on OAuthTokenStorageException {
      _log('OAuth flow aborted because secure storage is unavailable');
      return OAuthFlowResult(
        log: [],
        error:
            L10nBridge.current?.oauthFlowSecureStorageUnavailable ??
            'Secure credential storage is unavailable for OAuth.',
        token: null,
      );
    } catch (e) {
      // Never let an unexpected failure (secure-storage errors, loopback
      // bind failures, browser launch errors, malformed token responses)
      // escape as an exception — callers would otherwise wait on a future
      // that never resolves and the UI spinner would run forever.
      _log('OAuth flow aborted with an unexpected ${e.runtimeType}');
      return OAuthFlowResult(
        log: [],
        error:
            L10nBridge.current?.oauthFlowUnexpectedError ??
            'OAuth flow failed unexpectedly. Please try again.',
        token: null,
      );
    }
  }

  Future<OAuthFlowResult> _authenticate({bool skipCache = false}) async {
    _log('Starting OAuth flow');

    if (!skipCache) {
      final cached = await getCachedCredential();
      if (cached != null) {
        _log('Using cached credential');
        return OAuthFlowResult(token: cached.accessToken, needsConsent: false);
      }

      // Cached credential is missing or expired — try silent refresh first
      final stored = await _storage.loadCredential(
        profileId: profileId,
        serverUrl: serverUrl,
      );
      if (stored != null && stored.refreshToken != null) {
        _log('Cached credential expired, attempting silent refresh');
        final refreshResult = await refreshCredential(stored);
        if (refreshResult.ok) {
          _log('Silent refresh succeeded, returning new token');
          return refreshResult;
        }
        _log('Silent refresh failed, falling back to full PKCE flow');
      }
    }

    final meta = await _fetchOAuthMetadata();
    if (meta == null) {
      return OAuthFlowResult(
        log: [],
        error:
            L10nBridge.current?.oauthFlowNoEndpointsDiscovered ??
            'No OAuth endpoints discovered. '
                'Enable Managed OAuth in Cloudflare Dashboard '
                '→ Access → Applications → [this app].',
        token: null,
      );
    }
    _log('OAuth metadata accepted');

    final pkce = await _runPkceFlow(meta);
    if (pkce.error != null) {
      return OAuthFlowResult(log: [], error: pkce.error!, token: null);
    }
    _log('Token received');

    final tokenData = pkce.data!;
    final client = tokenData.remove('_client') as Map<String, dynamic>?;
    _log('Client registration ${client == null ? 'not used' : 'completed'}');

    final accessToken = tokenData['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      return OAuthFlowResult(
        log: [],
        error:
            L10nBridge.current?.oauthFlowTokenResponseMissingAccessToken ??
            'OAuth token response did not include an access token.',
        token: null,
      );
    }

    final credential = OAuthCredential(
      profileId: profileId,
      accessToken: accessToken,
      refreshToken: tokenData['refresh_token'] as String?,
      expiresAt: tokenData.containsKey('expires_in')
          ? DateTime.now().add(
              Duration(seconds: tokenData['expires_in'] as int),
            )
          : null,
      serverUrl: serverUrl,
      clientId: client?['client_id'] as String?,
    );
    try {
      final persisted = await _persistCredentialIfCurrent(credential);
      if (!persisted) {
        return OAuthFlowResult(
          log: [],
          error:
              L10nBridge.current?.oauthFlowProfileChanged ??
              'The server profile changed before OAuth could finish.',
          token: null,
        );
      }
      _log('Credential saved securely');
    } catch (e) {
      _log('Credential save failed: secure storage unavailable');
      return OAuthFlowResult(
        log: [],
        error:
            L10nBridge.current?.oauthFlowSecureStorageUnavailable ??
            'Secure credential storage is unavailable for OAuth.',
        token: null,
      );
    }

    return OAuthFlowResult(token: credential.accessToken);
  }

  Future<OAuthFlowResult> refreshCredential(OAuthCredential credential) async {
    _log('Refreshing credential');

    if (credential.refreshToken == null) {
      _log('No refresh token, re-authenticating');
      return authenticate(skipCache: true);
    }

    final meta = await _fetchOAuthMetadata();
    if (meta == null) {
      _log('Metadata fetch failed, re-authenticating');
      return authenticate(skipCache: true);
    }

    final tokenEp = meta['token_endpoint'] as String?;
    if (tokenEp == null) {
      _log('No token endpoint, re-authenticating');
      return authenticate(skipCache: true);
    }

    HttpClient? client;
    try {
      final bodyParams = <String, String>{
        'grant_type': 'refresh_token',
        'refresh_token': credential.refreshToken!,
        'resource': _baseUrl,
      };
      if (credential.clientId != null) {
        bodyParams['client_id'] = credential.clientId!;
      }

      client = HttpClient();
      final request = await client.postUrl(Uri.parse(tokenEp));
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      request.write(
        bodyParams
            .map((k, v) => MapEntry(k, Uri.encodeQueryComponent(v)))
            .entries
            .map((e) => '${e.key}=${e.value}')
            .join('&'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await readBoundedBody(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final newCredential = OAuthCredential(
          profileId: credential.profileId,
          accessToken: data['access_token'] as String,
          refreshToken:
              data['refresh_token'] as String? ?? credential.refreshToken,
          expiresAt: data.containsKey('expires_in')
              ? DateTime.now().add(Duration(seconds: data['expires_in'] as int))
              : null,
          serverUrl: serverUrl,
          clientId: credential.clientId,
        );
        final persisted = await _persistCredentialIfCurrent(newCredential);
        if (!persisted) {
          return OAuthFlowResult(
            log: [],
            error:
                L10nBridge.current?.oauthFlowProfileChanged ??
                'The server profile changed before OAuth could finish.',
            token: null,
          );
        }
        _log('Token refreshed and saved securely');
        return OAuthFlowResult(token: newCredential.accessToken);
      }
      _log('Refresh failed (${response.statusCode}), re-authenticating');
      return authenticate(skipCache: true);
    } on OAuthTokenStorageException {
      _log('Credential refresh failed: secure storage unavailable');
      return OAuthFlowResult(
        log: [],
        error:
            L10nBridge.current?.oauthFlowSecureStorageUnavailable ??
            'Secure credential storage is unavailable for OAuth.',
        token: null,
      );
    } catch (e) {
      _log('Refresh failed with ${e.runtimeType}; re-authenticating');
      return authenticate(skipCache: true);
    } finally {
      client?.close(force: true);
    }
  }

  Future<void> clearCredential() async {
    await _storage.deleteCredential(profileId: profileId, serverUrl: serverUrl);
  }

  Future<bool> _persistCredentialIfCurrent(OAuthCredential credential) async {
    if (!(_shouldPersistCredential?.call() ?? true)) return false;
    await _storage.saveCredential(credential);
    if (_shouldPersistCredential?.call() ?? true) return true;
    await _storage.deleteCredential(profileId: profileId, serverUrl: serverUrl);
    return false;
  }

  Future<Map<String, dynamic>?> _fetchOAuthMetadata() async {
    var metadataUri = _metadataEndpointFor(_baseUrl);
    final asUri = _parseWwwAuthenticate(challengeHeaders?['www-authenticate']);
    if (asUri != null) {
      final challengeMetadataUri = _metadataEndpointFor(asUri);
      if (isTrustedOAuthMetadataEndpoint(
        value: challengeMetadataUri?.toString(),
        serverUrl: serverUrl,
      )) {
        metadataUri = challengeMetadataUri;
      } else {
        _log('Ignoring untrusted OAuth metadata endpoint');
      }
    }

    if (isTrustedOAuthMetadataEndpoint(
      value: metadataUri?.toString(),
      serverUrl: serverUrl,
    )) {
      _log('Fetching OAuth metadata');
      HttpClient? client;
      try {
        client = HttpClient();
        final request = await client.getUrl(metadataUri!);
        final response = await request.close().timeout(
          const Duration(seconds: 10),
        );
        final body = await readBoundedBody(
          response,
          maxBytes: _maxDiscoveryBodyBytes,
        );

        if (response.statusCode == 200) {
          final ct = response.headers.contentType?.value ?? '';
          if (ct.contains('json')) {
            final data = jsonDecode(body) as Map<String, dynamic>;
            if (_metadataEndpointsAreTrusted(data)) {
              return data;
            }
            _log('Metadata rejected because endpoint hosts are not trusted');
            return null;
          }
          final domain = _extractCfDomain(body);
          if (domain != null) return _buildManagedEndpoints(domain);
        }
      } catch (e) {
        _log('Metadata fetch failed with ${e.runtimeType}');
      } finally {
        client?.close(force: true);
      }
    } else {
      _log('Skipping untrusted OAuth metadata endpoint');
    }

    final redirectDomain = await _discoverCfDomain();
    if (redirectDomain != null) return _buildManagedEndpoints(redirectDomain);

    final login = challengeHeaders?['cf-access-login'];
    if (login != null) {
      final loginUri = Uri.tryParse(login);
      if (loginUri == null || !isTrustedOAuthEndpoint(login)) {
        _log('Ignoring untrusted CF-Access-Login endpoint');
        return null;
      }
      _log('Using CF-Access-Login endpoint');
      final endpoints = <String, dynamic>{
        'authorization_endpoint': '$login/authorize',
        'token_endpoint': '$login/token',
        'registration_endpoint': '$login/register',
      };
      return _metadataEndpointsAreTrusted(endpoints) ? endpoints : null;
    }

    if (challengeBody != null) {
      final htmlDomain = _extractCfDomain(challengeBody!);
      if (htmlDomain != null) return _buildManagedEndpoints(htmlDomain);
    }

    return null;
  }

  Future<Map<String, dynamic>?> _registerClient(
    Map<String, dynamic> meta,
    String redirectUri,
  ) async {
    final regEndpoint = meta['registration_endpoint'] as String?;
    if (regEndpoint == null || regEndpoint.isEmpty) {
      _log('No registration endpoint — proceeding without DCR');
      return null;
    }

    _log('DCR: registering loopback client');

    HttpClient? httpClient;
    try {
      httpClient = HttpClient();
      final request = await httpClient.postUrl(Uri.parse(regEndpoint));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(
          clientRegistrationPayload(
            redirectUri: redirectUri,
            resource: _baseUrl,
          ),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await readBoundedBody(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        _log('DCR succeeded');
        return data;
      }
      _log('DCR failed: ${response.statusCode} — proceeding without DCR');
    } catch (e) {
      _log('DCR failed with ${e.runtimeType} — proceeding without DCR');
    } finally {
      httpClient?.close(force: true);
    }
    return null;
  }

  Future<_PkceResult> _runPkceFlow(Map<String, dynamic> meta) async {
    final authEp = meta['authorization_endpoint'] as String?;
    final tokenEp = meta['token_endpoint'] as String?;
    if (authEp == null || tokenEp == null) {
      return _PkceResult.failure(
        L10nBridge.current?.oauthFlowMetadataMissingEndpoints ??
            'OAuth metadata is missing authorization/token endpoints.',
      );
    }

    final callbackServer = await HttpServer.bind('127.0.0.1', 0);
    try {
      final redirectUri = loopbackRedirectUriForPort(callbackServer.port);
      final client = await _registerClient(meta, redirectUri);

      final verifier = _generateVerifier();
      final challenge = _generateChallenge(verifier);
      final state = _generateVerifier();

      final clientId = client?['client_id'] as String?;

      final params = authorizationParameters(
        redirectUri: redirectUri,
        challenge: challenge,
        state: state,
        resource: _baseUrl,
        clientId: clientId,
      );

      final authUri = Uri.parse(authEp).replace(queryParameters: params);
      _log('Opening browser for authorization');

      final callback = await _launchAndCapture(
        authUri,
        redirectUri,
        state,
        callbackServer,
      );
      if (callback.code == null) {
        return _PkceResult.failure(
          callback.failureReason ??
              L10nBridge.current?.oauthFlowCallbackNotCompleted ??
              'Authorization callback was not completed',
        );
      }
      _log('Authorization code received');

      final exchange = await _exchangeCode(
        tokenEp,
        callback.code!,
        verifier,
        redirectUri,
        clientId,
      );
      if (exchange.error != null) {
        return _PkceResult.failure(exchange.error!);
      }
      final data = exchange.data!;
      data['_client'] = client;
      return _PkceResult.data(data);
    } finally {
      await callbackServer.close(force: true);
    }
  }

  Future<_CallbackResult> _launchAndCapture(
    Uri authUri,
    String redirectUri,
    String state,
    HttpServer server,
  ) async {
    final expectedRedirectUri = Uri.parse(redirectUri);
    final completer = Completer<_CallbackResult>();
    final completionGuard = OAuthCallbackCompletionGuard();

    void completeOnce(_CallbackResult result) {
      if (!completionGuard.tryMarkTerminal()) return;
      if (!completer.isCompleted) completer.complete(result);
    }

    try {
      _log('Callback server listening on loopback');
      server.listen((req) async {
        if (completionGuard.isTerminal) {
          req.response.statusCode = 409;
          try {
            await req.response.close().timeout(const Duration(seconds: 2));
          } catch (_) {}
          return;
        }
        _log('Callback received on path ${req.uri.path}');
        final validation = validateCallback(
          method: req.method,
          requestTarget: req.uri,
          requestScheme: 'http',
          hostHeader: req.headers.value(HttpHeaders.hostHeader),
          expectedRedirectUri: expectedRedirectUri,
          expectedState: state,
        );
        if (validation.decision == OAuthCallbackDecision.ignoreWrongPath) {
          req.response.statusCode = 404;
          try {
            await req.response.close().timeout(const Duration(seconds: 2));
          } catch (_) {}
          return;
        }

        final accepted =
            validation.decision == OAuthCallbackDecision.acceptCode;
        final providerRejected =
            validation.decision == OAuthCallbackDecision.rejectProviderError;
        final rejection = providerRejected
            ? (L10nBridge.current?.oauthFlowProviderDeclined ??
                  'The authorization server declined the OAuth request. '
                      'Please try again.')
            : (L10nBridge.current?.oauthFlowCallbackValidationFailed ??
                  'OAuth callback validation failed. Please try again.');
        _log(
          accepted
              ? 'Authorization code received (callback validated)'
              : providerRejected
              ? 'Authorization server returned an OAuth error'
              : 'OAuth callback failed validation',
        );

        if (!completionGuard.tryMarkTerminal()) {
          req.response.statusCode = 409;
          await req.response.close();
          return;
        }
        final result = accepted
            ? _CallbackResult.code(validation.code!)
            : _CallbackResult.failure(rejection);
        try {
          req.response.statusCode = accepted ? 200 : 400;
          req.response.headers.contentType = ContentType.html;
          req.response.write(accepted ? _successPage() : _errorPage());
          await req.response.close().timeout(const Duration(seconds: 2));
        } catch (_) {
          _log('Callback response closed before page flush completed');
        } finally {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        }
      });
    } catch (e) {
      _log('Callback server failed with ${e.runtimeType}');
      completeOnce(
        _CallbackResult.failure(
          L10nBridge.current?.oauthFlowCallbackServerStartFailed ??
              'Local OAuth callback server failed to start.',
        ),
      );
      return completer.future;
    }

    final flowId = _generateVerifier();
    if (Platform.isAndroid) {
      _registerAndroidCloseListener(flowId, () {
        completeOnce(
          _CallbackResult.failure(
            L10nBridge.current?.oauthFlowSignInCanceled ??
                'OAuth sign-in was canceled.',
          ),
        );
      });
    }
    try {
      final launched = await _launchAuthorization(authUri, flowId);
      if (!launched) {
        _log('Browser failed to open');
        completeOnce(
          _CallbackResult.failure(
            L10nBridge.current?.oauthFlowBrowserOpenFailed ??
                'Could not open the system browser for OAuth sign-in.',
          ),
        );
        return completer.future;
      }

      _log('Waiting for callback (timeout: 5 min)...');
      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          completionGuard.tryMarkTerminal();
          _log('Login timed out after 5 minutes');
          return _CallbackResult.failure(
            L10nBridge.current?.oauthFlowCallbackTimeout ??
                'No authorization callback reached the app within 5 minutes. '
                    'The browser was expected to redirect to the local callback '
                    'address after consent. If the browser showed a connection '
                    'error instead, this device or network blocks loopback '
                    'redirects.',
          );
        },
      );
      await server.close(force: true);
      _log('Callback server stopped');
      return result;
    } finally {
      if (Platform.isAndroid) {
        _androidCloseListeners.remove(flowId);
      }
    }
  }

  static void _registerAndroidCloseListener(
    String flowId,
    void Function() onClosed,
  ) {
    _androidCloseListeners[flowId] = onClosed;
    if (_androidCloseHandlerInstalled) return;
    _androidCloseHandlerInstalled = true;
    _androidChannel.setMethodCallHandler((call) async {
      if (call.method != 'oauthAuthorizationClosed') return;
      final arguments = call.arguments;
      if (arguments is! Map) return;
      final closedFlowId = arguments['flowId'];
      if (closedFlowId is! String) return;
      _androidCloseListeners.remove(closedFlowId)?.call();
    });
  }

  Future<bool> _launchAuthorization(Uri authUri, String flowId) async {
    if (!Platform.isAndroid) {
      return launchUrl(authUri, mode: LaunchMode.externalApplication);
    }
    try {
      final mode = await _androidChannel.invokeMethod<String>(
        'launchOAuthAuthorization',
        {'url': authUri.toString(), 'flowId': flowId},
      );
      if (mode == 'custom_tab') {
        _log('Opening authorization in a browser Custom Tab');
        return true;
      }
      if (mode == 'external_browser') {
        _log('Custom Tabs unavailable; opening the external browser');
        return true;
      }
      return false;
    } catch (_) {
      _log('Android browser launch failed');
      return false;
    }
  }

  Future<_ExchangeResult> _exchangeCode(
    String tokenEp,
    String code,
    String verifier,
    String redirectUri,
    String? clientId,
  ) async {
    _log('Exchanging authorization code');
    final bodyParams = authorizationCodeParameters(
      code: code,
      verifier: verifier,
      redirectUri: redirectUri,
      resource: _baseUrl,
      clientId: clientId,
    );

    // Retry only failures known to happen before request.close(), the point
    // after which the one-time authorization code may have been consumed.
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final outcome = await _exchangeCodeOnce(tokenEp, bodyParams);
      if (outcome != null) return outcome;
      if (attempt < maxAttempts) {
        _log('Token exchange attempt $attempt failed, retrying...');
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
    _log('Token exchange failed after $maxAttempts transient attempts');
    return _ExchangeResult.failure(
      L10nBridge.current?.oauthFlowTokenExchangeTransientFailure(maxAttempts) ??
          'Token exchange failed after $maxAttempts attempts because of a '
              'temporary network problem. Please try again.',
    );
  }

  /// Single token-exchange attempt. Returns null on transient network errors
  /// (worth retrying); returns a result for both success and HTTP-level
  /// failures (not retryable).
  Future<_ExchangeResult?> _exchangeCodeOnce(
    String tokenEp,
    Map<String, String> bodyParams,
  ) async {
    HttpClient? client;
    var requestMayHaveBeenSent = false;
    try {
      client = HttpClient();
      final request = await client.postUrl(Uri.parse(tokenEp));
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      request.write(
        bodyParams.entries
            .map(
              (e) =>
                  '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
            )
            .join('&'),
      );
      requestMayHaveBeenSent = true;
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await readBoundedBody(response);

      if (response.statusCode != 200) {
        _log('Token exchange failed with HTTP ${response.statusCode}');
        return _ExchangeResult.failure(
          tokenExchangeHttpFailure(response.statusCode),
        );
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final hasAccess = data.containsKey('access_token');
      final hasRefresh = data.containsKey('refresh_token');
      final hasExpiry = data.containsKey('expires_in');
      _log(
        'Token exchange OK: access_token=${hasAccess ? 'present' : 'MISSING'}, '
        'refresh_token=${hasRefresh ? 'present' : 'absent'}, '
        'expires_in=${hasExpiry ? 'present' : 'absent'}',
      );
      return _ExchangeResult.data(data);
    } on SocketException catch (error) {
      return _authorizationCodeTransportFailure(error, requestMayHaveBeenSent);
    } on TimeoutException catch (error) {
      return _authorizationCodeTransportFailure(error, requestMayHaveBeenSent);
    } on HandshakeException catch (error) {
      return _authorizationCodeTransportFailure(error, requestMayHaveBeenSent);
    } catch (e) {
      _log('Token exchange failed with ${e.runtimeType}');
      return _ExchangeResult.failure(
        L10nBridge.current?.oauthFlowTokenExchangeUnexpectedFailure ??
            'Token exchange failed unexpectedly. Please try again.',
      );
    } finally {
      client?.close(force: true);
    }
  }

  _ExchangeResult? _authorizationCodeTransportFailure(
    Object error,
    bool requestMayHaveBeenSent,
  ) {
    if (canRetryAuthorizationCodeExchange(
      error: error,
      requestMayHaveBeenSent: requestMayHaveBeenSent,
    )) {
      _log('Token exchange failed before request send; retry is safe');
      return null;
    }
    _log('Token exchange failed after possible request send; not retrying');
    return _ExchangeResult.failure(
      L10nBridge.current?.oauthFlowTokenExchangeIncomplete ??
          'Token exchange did not complete after the authorization code was '
              'sent. Please start OAuth sign-in again.',
    );
  }

  String? _parseWwwAuthenticate(String? header) {
    if (header == null) return null;
    final asUriMatch = RegExp("""as_uri=['"]([^'"]+)['"]""").firstMatch(header);
    if (asUriMatch != null) return asUriMatch.group(1);
    if (header.startsWith('Cloudflare-Access')) return _baseUrl;
    return null;
  }

  Uri? _metadataEndpointFor(String base) {
    final uri = Uri.tryParse(base);
    if (uri == null || uri.hasQuery || uri.hasFragment) return null;
    final basePath = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri.replace(
      path: '$basePath/.well-known/oauth-authorization-server',
    );
  }

  Future<String?> _discoverCfDomain() async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.autoUncompress = false;
      final request = await client.getUrl(Uri.parse(_baseUrl));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final location = response.headers.value('location');
      await _readBoundedBytes(
        response,
        timeout: _bodyTimeout,
        maxBytes: _maxDiscoveryBodyBytes,
      );
      if (location != null) {
        final uri = Uri.tryParse(location);
        if (uri != null && isCloudflareAccessHost(uri.host)) {
          return uri.host;
        }
      }
    } catch (e) {
      _log('Redirect probe failed with ${e.runtimeType}');
    } finally {
      client?.close(force: true);
    }
    return null;
  }

  Map<String, dynamic> _buildManagedEndpoints(String domain) {
    return {
      'authorization_endpoint':
          'https://$domain/cdn-cgi/access/oauth/managed/authorize',
      'token_endpoint': 'https://$domain/cdn-cgi/access/oauth/managed/token',
      'registration_endpoint':
          'https://$domain/cdn-cgi/access/oauth/managed/register',
    };
  }

  String? _extractCfDomain(String html) {
    final patterns = [
      RegExp(r'''https?://([a-zA-Z0-9][-a-zA-Z0-9]*\.cloudflareaccess\.com)'''),
      RegExp(
        r'''(?:action|src|href|data-url)=["\']https?://([a-zA-Z0-9][-a-zA-Z0-9]*\.cloudflareaccess\.com)''',
      ),
      RegExp(r'''["\'](https?://[^"\']*\.cloudflareaccess\.com[^"\']*)["\']'''),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        var domain = match.group(1)!;
        if (domain.startsWith('http')) {
          domain = Uri.parse(domain).host;
        }
        if (isCloudflareAccessHost(domain)) return domain;
      }
    }
    return null;
  }

  bool _metadataEndpointsAreTrusted(Map<String, dynamic> metadata) {
    final auth = metadata['authorization_endpoint'] as String?;
    final token = metadata['token_endpoint'] as String?;
    final register = metadata['registration_endpoint'] as String?;
    return isTrustedOAuthEndpoint(auth) &&
        isTrustedOAuthEndpoint(token) &&
        (register == null || isTrustedOAuthEndpoint(register));
  }

  String _generateVerifier() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateChallenge(String verifier) {
    final bytes = sha256.convert(utf8.encode(verifier)).bytes;
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String get _baseUrl {
    var url = serverUrl.trim();
    if (!url.contains('://')) url = 'http://$url';
    final uri = Uri.parse(url);
    final portStr = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portStr';
  }

  String _successPage() => '''<!DOCTYPE html>
<html><head><title>Authentication Complete</title>
<style>
  body { font-family: system-ui, -apple-system, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f5f5f5 }
  .card { text-align: center; padding: 40px; background: white; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1) }
  .check { width: 64px; height: 64px; margin: 0 auto 16px; border-radius: 50%; background: #10b981; display: flex; align-items: center; justify-content: center }
  .check svg { width: 32px; height: 32px }
  h2 { font-size: 18px; color: #333; margin: 0 0 8px 0; font-weight: 600 }
  p { font-size: 14px; color: #666; margin: 0 }
</style></head>
<body><div class="card">
<div class="check"><svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg></div>
<h2>Authentication successful</h2>
<p>You can close this tab and return to the app.</p>
</div></body></html>''';

  String _errorPage() => '''<!DOCTYPE html>
<html><head><title>Authentication Failed</title>
<style>
  body { font-family: system-ui, -apple-system, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f5f5f5 }
  .card { text-align: center; padding: 40px; background: white; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.1) }
  h2 { font-size: 18px; color: #991b1b; margin: 0 0 8px 0; font-weight: 600 }
  p { font-size: 14px; color: #666; margin: 0 }
</style></head>
<body><div class="card">
<h2>Authentication failed</h2>
<p>Return to CodeWalk and try again.</p>
</div></body></html>''';

  void _log(String msg) {
    AppLogger.debug('[OAuth] $msg');
  }
}
