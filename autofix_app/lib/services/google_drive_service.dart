import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

/// Custom HTTP client using access token
class GoogleAuthClient extends http.BaseClient {
  final String accessToken;
  final http.Client _inner = http.Client();

  GoogleAuthClient(this.accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static const String _webClientId =
      '903962440902-9s7u72p3p75e4218ni8ookv29g9dv8fg.apps.googleusercontent.com';
  static const String _parentFolderId = '1jmD_XBl_4a_FEvT3xQ9RKgH7-26gmM30';

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  String? _lastError;

  bool get isSignedIn => _driveApi != null;
  GoogleSignInAccount? get currentUser => _currentUser;
  String? get lastError => _lastError;

  /// Initialize Google Sign-In
  Future<void> initialize() async {
    try {
      _googleSignIn = GoogleSignIn(
        scopes: [drive.DriveApi.driveFileScope],
        clientId: kIsWeb ? _webClientId : null,
      );

      if (kDebugMode) print('Google Sign-In initialized successfully');
    } catch (e) {
      if (kDebugMode) print('Google Sign-In initialization failed: $e');
      rethrow;
    }
  }

  /// Attempt silent sign-in
  Future<void> signInSilently() async {
    try {
      // Lazily initialize if not already initialized
      if (_googleSignIn == null) {
        await initialize();
      }
      _currentUser = await _googleSignIn?.signInSilently();
      if (_currentUser != null) {
        await _initializeDriveApi();
        _lastError = null;
      }
    } catch (e) {
      if (kDebugMode) print('Silent sign-in failed: $e');
      _currentUser = null;
      _driveApi = null;
      _lastError = 'Silent sign-in failed: $e';
    }
  }

  /// Interactive sign-in
  Future<bool> signIn() async {
    try {
      // Lazily initialize if not already initialized
      if (_googleSignIn == null) {
        await initialize();
      }
      // Add timeout to avoid hanging indefinitely on web when cookies/popups are blocked
      _currentUser = await (_googleSignIn?.signIn()
          .timeout(const Duration(seconds: 60), onTimeout: () {
        if (kDebugMode) {
          print('Google Sign-In timed out. Check popup blockers and third-party cookies.');
        }
        _lastError = 'Google Sign-In timed out. Enable third-party cookies and allow popups for accounts.google.com, or add your localhost origin in Google Cloud Console.';
        return null;
      }));
      if (_currentUser != null) {
        await _initializeDriveApi();
        _lastError = null;
        return true;
      }
      _lastError ??= 'Google Sign-In was cancelled or failed to complete.';
      return false;
    } catch (e) {
      if (kDebugMode) print('Sign-in error: $e');
      _driveApi = null;
      _lastError = 'Sign-in error: $e';
      return false;
    }
  }

  /// Build Drive API client using auth headers
  Future<void> _initializeDriveApi() async {
    if (_currentUser == null) throw Exception('User not signed in');

    try {
      final client = await _googleSignIn!.authenticatedClient();
      if (client == null) {
        throw Exception('Failed to obtain authenticated client');
      }
      _driveApi = drive.DriveApi(client);

      if (kDebugMode) print('Google Drive API initialized successfully');
    } catch (e) {
      if (kDebugMode) print('Drive init failed: $e');
      rethrow;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn?.disconnect();
      _currentUser = null;
      _driveApi = null;
      _lastError = null;
      if (kDebugMode) print('Signed out successfully');
    } catch (e) {
      if (kDebugMode) print('Sign-out error: $e');
      _lastError = 'Sign-out error: $e';
    }
  }

  // ---------------- Folder & File Operations ---------------- //

  Future<String?> createFolder(String folderName) async {
    if (_driveApi == null) throw Exception('Not signed in');
    try {
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [_parentFolderId];
      final result = await _driveApi!.files.create(folder);
      return result.id;
    } catch (e) {
      if (kDebugMode) print('Folder creation error: $e');
      return null;
    }
  }

  Future<String?> uploadFileToFolder(
      File file,
      String fileName,
      String folderId, {
        String? mimeType,
      }) async {
    if (_driveApi == null) throw Exception('Not signed in');
    try {
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..mimeType = mimeType;

      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
      );
      return result.id;
    } catch (e) {
      if (kDebugMode) print('Upload error: $e');
      return null;
    }
  }

  String getFolderUrl(String folderId) =>
      'https://drive.google.com/drive/folders/$folderId';

  Future<String?> uploadFileWithProgress(
      File file,
      String fileName,
      String folderId,
      void Function(int sent, int total)? onProgress,
      ) async {
    if (_driveApi == null) throw Exception('Not signed in');
    try {
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];

      final int length = file.lengthSync();
      int sent = 0;

      final stream = file.openRead().transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            sent += data.length;
            onProgress?.call(sent, length);
            sink.add(data);
          },
        ),
      );

      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: drive.Media(stream, length),
      );
      return result.id;
    } catch (e) {
      if (kDebugMode) print('Upload with progress error: $e');
      return null;
    }
  }

  Future<String?> uploadFileBytesToFolder(
      Uint8List data,
      String fileName,
      String folderId, {
        String? mimeType,
      }) async {
    if (_driveApi == null) throw Exception('Not signed in');
    try {
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId]
        ..mimeType = mimeType;

      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: drive.Media(Stream.value(data), data.length),
      );
      return result.id;
    } catch (e) {
      if (kDebugMode) print('Bytes upload error: $e');
      return null;
    }
  }
}
