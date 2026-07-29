import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:archive/archive.dart';

class LocalMediaService {
  static final LocalMediaService _instance = LocalMediaService._internal();
  factory LocalMediaService() => _instance;
  LocalMediaService._internal();

  static const String _boxName = 'local_media';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _mediaBox => Hive.box<dynamic>(_boxName);

  Future<String> saveMediaBytes({
    required Uint8List bytes,
    required String vehicleNo,
    required String mediaType, // 'photo' | 'audio'
    required String mimeType,
    required String fileName,
    int? jobId,
  }) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}_$mediaType';
    final record = <String, dynamic>{
      'id': id,
      'jobId': jobId,
      'vehicleNo': vehicleNo,
      'fileName': fileName,
      'type': mediaType,
      'mime': mimeType,
      'bytes': bytes,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _mediaBox.put(id, record);
    return id;
  }

  List<Map<String, dynamic>> listByVehicle(String vehicleNo) {
    final items = <Map<String, dynamic>>[];
    for (final key in _mediaBox.keys) {
      final v = _mediaBox.get(key);
      if (v is Map && v['vehicleNo'] == vehicleNo) {
        items.add(Map<String, dynamic>.from(v));
      }
    }
    return items;
  }

  List<Map<String, dynamic>> listByJob(int jobId) {
    final items = <Map<String, dynamic>>[];
    for (final key in _mediaBox.keys) {
      final v = _mediaBox.get(key);
      if (v is Map && v['jobId'] == jobId) {
        items.add(Map<String, dynamic>.from(v));
      }
    }
    return items;
  }

  Map<String, dynamic>? getById(String id) {
    final v = _mediaBox.get(id);
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  Future<void> deleteById(String id) async {
    await _mediaBox.delete(id);
  }

  /// Build a ZIP of all media for a jobId. Returns the ZIP as bytes.
  Uint8List exportZipForJob(int jobId) {
    final archive = Archive();
    final items = listByJob(jobId);
    for (final item in items) {
      final bytes = item['bytes'] as Uint8List;
      final name = item['fileName'] as String? ?? '${item['id']}.${(item['type'] == 'photo') ? 'jpg' : 'webm'}';
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    final zip = ZipEncoder().encode(archive);
    return Uint8List.fromList(zip ?? const <int>[]);
  }
}
