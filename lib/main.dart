import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: 'assets/.env');
  return runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isBusy = false;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  String? _codeVerifier;
  String? _nonce;
  String? _authorizationCode;
  String? _refreshToken;
  String? _idToken;
  String? _accessToken;
  final String _clientId = dotenv.env['CLIENT_ID'] ?? '';
  final String _redirectUrl = dotenv.env['REDIRECT_URL'] ?? '';
  final String _clientSecret = dotenv.env['CLIENT_SECRET'] ?? '';

  final String _discoveryUrl = '';
  final String _postLogoutRedirectUrl = '';
  final List<String> _scopes = <String>['read'];

  AuthorizationServiceConfiguration? loadAuthorizationServiceConfiguration() {
    final String _authorizationEndpoint;
    final String _tokenEndpoint;
    final String _endSessionEndpoint;
    if (dotenv.env['AUTHORIZATION_ENDPOINT'] == null) {
      return null;
    }
    _authorizationEndpoint = dotenv.env['AUTHORIZATION_ENDPOINT'] ?? '';

    if (dotenv.env['TOKEN_ENDPOINT'] == null) {
      return null;
    }
    _tokenEndpoint = dotenv.env['TOKEN_ENDPOINT'] ?? '';

    if (dotenv.env['ENDSESSION_ENDPOINT'] == null) {
      return null;
    }
    _endSessionEndpoint = dotenv.env['ENDSESSION_ENDPOINT'] ?? '';

    return AuthorizationServiceConfiguration(
        authorizationEndpoint: _authorizationEndpoint,
        tokenEndpoint: _tokenEndpoint,
        endSessionEndpoint: _endSessionEndpoint);
  }

  Future<void> authorizeWithOAuth() async {
    final AuthorizationTokenResponse? result =
        await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        clientSecret: _clientSecret,
        scopes: ['read'],
        serviceConfiguration: loadAuthorizationServiceConfiguration(),
      ),
    );
    if (result != null) {
      // Handle the authorization response
      final String? accessToken = result.accessToken;
      final String? refreshToken = result.refreshToken;
      print(accessToken);
      print(refreshToken);
      // Store the access token and refresh token securely
    } else {
      // Authorization failed
    }
  }

  // For a list of client IDs, go to https://demo.duendesoftware.com

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                children: <Widget>[
                  ElevatedButton(
                      child: const Text('test'),
                      onPressed: () =>
                          authorizeWithOAuth() //_signInWithNoCodeExchange(),
                      ),
                  ElevatedButton(
                    child: const Text('Sign in with auto code exchange'),
                    onPressed: () => _signInWithAutoCodeExchange(),
                  ),
                  if (Platform.isIOS || Platform.isMacOS)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        child: const Text(
                          'Sign in with auto code exchange using ephemeral '
                          'session',
                          textAlign: TextAlign.center,
                        ),
                        onPressed: () => _signInWithAutoCodeExchange(
                            preferEphemeralSession: true),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _endSession() async {
    try {
      _setBusyState();
      await _appAuth.endSession(EndSessionRequest(
          idTokenHint: _idToken,
          postLogoutRedirectUrl: _postLogoutRedirectUrl,
          serviceConfiguration: loadAuthorizationServiceConfiguration()));
      _clearSessionInfo();
    } catch (_) {}
    _clearBusyState();
  }

  void _clearSessionInfo() {
    setState(() {
      _codeVerifier = null;
      _nonce = null;
      _authorizationCode = null;
    });
  }

  Future<void> _refresh() async {
    try {
      _setBusyState();
      final TokenResponse? result = await _appAuth.token(TokenRequest(
          _clientId, _redirectUrl,
          refreshToken: _refreshToken, scopes: _scopes));
      _processTokenResponse(result);
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _exchangeCode() async {
    try {
      _setBusyState();
      final TokenResponse? result = await _appAuth.token(TokenRequest(
          _clientId, _redirectUrl,
          authorizationCode: _authorizationCode,
          discoveryUrl: _discoveryUrl,
          codeVerifier: _codeVerifier,
          nonce: _nonce,
          scopes: _scopes));
      _processTokenResponse(result);
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _signInWithNoCodeExchangeAndGeneratedNonce() async {
    try {
      _setBusyState();
      final Random random = Random.secure();
      final String nonce =
          base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
      // use the discovery endpoint to find the configuration
      final AuthorizationResponse? result = await _appAuth.authorize(
        AuthorizationRequest(_clientId, _redirectUrl,
            discoveryUrl: _discoveryUrl,
            scopes: _scopes,
            loginHint: 'bob',
            nonce: nonce),
      );

      if (result != null) {
        _processAuthResponse(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _signInWithAutoCodeExchange(
      {bool preferEphemeralSession = false}) async {
    try {
      _setBusyState();

      /*
        This shows that we can also explicitly specify the endpoints rather than
        getting from the details from the discovery document.
      */
      final AuthorizationTokenResponse? result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          serviceConfiguration: loadAuthorizationServiceConfiguration(),
          scopes: _scopes,
          preferEphemeralSession: preferEphemeralSession,
        ),
      );

      /* 
        This code block demonstrates passing in values for the prompt
        parameter. In this case it prompts the user login even if they have
        already signed in. the list of supported values depends on the
        identity provider

        ```dart
        final AuthorizationTokenResponse result = await _appAuth
        .authorizeAndExchangeCode(
          AuthorizationTokenRequest(_clientId, _redirectUrl,
              serviceConfiguration: loadAuthorizationServiceConfiguration(),
              scopes: _scopes,
              promptValues: ['login']),
        );
        ```
      */

      if (result != null) {
        _processAuthTokenResponse(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  void _clearBusyState() {
    setState(() {
      _isBusy = false;
    });
  }

  void _setBusyState() {
    setState(() {
      _isBusy = true;
    });
  }

  void _processAuthTokenResponse(AuthorizationTokenResponse response) {
    setState(() {
      _accessToken = response.accessToken!;
      _idToken = response.idToken!;
      _refreshToken = response.refreshToken!;
    });
  }

  void _processAuthResponse(AuthorizationResponse response) {
    setState(() {
      /*
        Save the code verifier and nonce as it must be used when exchanging the
        token.
      */
      _codeVerifier = response.codeVerifier;
      _nonce = response.nonce;
      _authorizationCode = response.authorizationCode!;
      _isBusy = false;
    });
  }

  void _processTokenResponse(TokenResponse? response) {
    setState(() {
      _accessToken = response!.accessToken!;
      _idToken = response.idToken!;
      _refreshToken = response.refreshToken!;
    });
  }
}
