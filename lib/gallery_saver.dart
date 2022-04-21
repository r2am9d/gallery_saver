import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:gallery_saver/files.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class GallerySaverResult {
  final String path;
  final bool isSaved;
  final bool isDeleted;

  GallerySaverResult(this.path, this.isSaved, this.isDeleted);
  GallerySaverResult.fromJson(Map<String, dynamic> json)
      : path = json["path"] ?? '',
        isSaved = json["isSaved"] ?? false,
        isDeleted = json["isDeleted"] ?? false;
}

class GallerySaver {
  static const String channelName = 'gallery_saver';

  static const String methodSaveImage = 'saveImage';
  static const String methodSaveVideo = 'saveVideo';
  static const String methodSaveFile = 'saveFile';

  static const String methodDeleteImage = 'deleteImage';
  static const String methodDeleteVideo = 'deleteVideo';
  static const String methodDeleteFile = 'deleteFile';

  static const String pleaseProvidePath = 'Please provide valid file path.';
  static const String fileIsNotVideo = 'File on path is not a video.';
  static const String fileIsNotImage = 'File on path is not an image.';

  static const MethodChannel _channel = const MethodChannel(channelName);

  /**
   * Saves video from provided path into the gallery.
   * 
   * @return returns a decoded json with the saved path
   * { isSaved: true, path: '/storage/...' }
   */
  static Future<GallerySaverResult> saveVideo(
    String path, {
    String? fileName,
    String? albumName,
    bool toDcim = false,
    Map<String, String>? headers,
  }) async {
    assert(path.isNotEmpty, pleaseProvidePath);
    assert(isVideo(path), fileIsNotVideo);

    File? tempFile;
    if (!isLocalFilePath(path)) {
      tempFile = await _downloadFile(path, headers: headers);
      path = tempFile.path;
    }

    final result = await _channel.invokeMethod(
      methodSaveVideo,
      <String, dynamic>{
        'path': path,
        'fileName': fileName,
        'albumName': albumName,
        'toDcim': toDcim,
      },
    );

    if (tempFile != null) {
      tempFile.delete();
    }

    return GallerySaverResult.fromJson(jsonDecode(result));
  }

  /**
   * Deletes a video file from provided path.
   * 
   * @return returns a decoded json
   * { isDeleted: true }
   */
  static Future<GallerySaverResult> deleteVideo(
    String path,
  ) async {
    assert(path.isNotEmpty, pleaseProvidePath);
    assert(isVideo(path), fileIsNotVideo);

    final result = await _channel.invokeMethod(
      methodDeleteVideo,
      <String, dynamic>{
        'path': path,
      },
    );

    return GallerySaverResult.fromJson(jsonDecode(result));
  }

  /**
   * Saves image from provided path into the gallery.
   * 
   * @return returns a decoded json with the saved path
   * { isSaved: true, path: '/storage/...' }
   */
  static Future<GallerySaverResult> saveImage(
    String path, {
    String? fileName,
    String? albumName,
    bool toDcim = false,
    Map<String, String>? headers,
  }) async {
    assert(path.isNotEmpty, pleaseProvidePath);
    assert(isImage(path), fileIsNotImage);

    File? tempFile;
    if (!isLocalFilePath(path)) {
      tempFile = await _downloadFile(path, headers: headers);
      path = tempFile.path;
    }

    final result = await _channel.invokeMethod(
      methodSaveImage,
      <String, dynamic>{
        'path': path,
        'fileName': fileName,
        'albumName': albumName,
        'toDcim': toDcim,
      },
    );

    if (tempFile != null) {
      tempFile.delete();
    }

    return GallerySaverResult.fromJson(jsonDecode(result));
  }

  /**
   * Deletes an image file from provided path.
   * 
   * @return returns a decoded json
   * { isDeleted: true }
   */
  static Future<GallerySaverResult> deleteImage(
    String path,
  ) async {
    assert(path.isNotEmpty, pleaseProvidePath);
    assert(isImage(path), fileIsNotImage);

    final result = await _channel.invokeMethod(
      methodDeleteImage,
      <String, dynamic>{
        'path': path,
      },
    );

    return GallerySaverResult.fromJson(jsonDecode(result));
  }

    /**
   * Saves a generic file from provided path into the gallery.
   * 
   * @return returns a decoded json with the saved path
   * { isSaved: true, path: '/storage/...' }
   */
  static Future<GallerySaverResult> saveFile(
    String path, {
    String? fileName,
    String? albumName,
    bool toDcim = false,
    Map<String, String>? headers,
  }) async {
    assert(path.isNotEmpty, pleaseProvidePath);

    File? tempFile;
    if (!isLocalFilePath(path)) {
      tempFile = await _downloadFile(path, headers: headers);
      path = tempFile.path;
    }

    final result = await _channel.invokeMethod(
      methodSaveFile,
      <String, dynamic>{
        'path': path,
        'fileName': fileName,
        'albumName': albumName,
        'toDcim': toDcim,
      },
    );

    if (tempFile != null) {
      tempFile.delete();
    }

    return GallerySaverResult.fromJson(jsonDecode(result));
  }

  /**
   * Deletes a generic file from provided path.
   * 
   * @return returns a decoded json
   * { isDeleted: true }
   */
  static Future<GallerySaverResult> deleteFile(
    String path,
  ) async {
    assert(path.isNotEmpty, pleaseProvidePath);

    final result = await _channel.invokeMethod(
      methodDeleteFile,
      <String, dynamic>{
        'path': path,
      },
    );

    return GallerySaverResult.fromJson(jsonDecode(result));
  }

  static Future<File> _downloadFile(
    String url, {
    Map<String, String>? headers,
  }) async {
    http.Client _client = new http.Client();
    var req = await _client.get(Uri.parse(url), headers: headers);
    if (req.statusCode >= 400) {
      throw HttpException(req.statusCode.toString());
    }
    var bytes = req.bodyBytes;
    String dir = (await getTemporaryDirectory()).path;
    String fileName = _shortenFileName(url);

    File file = new File('$dir/$fileName');

    await file.writeAsBytes(bytes);
    log(
      'Saving $fileName, ${await file.length() ~/ 1024} Kb',
      name: 'GallerySaver',
    );

    return file;
  }

  static String _shortenFileName(String url) {
    String fileName = basename(url);
    final len = fileName.length;

    if (len > 255) {
      fileName = fileName.substring(len - 255, len);
    }

    return fileName;
  }
}
