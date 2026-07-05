import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class VanBusinessLogoUploadResult {
  const VanBusinessLogoUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}

class VanBusinessLogoStorageService {
  VanBusinessLogoStorageService._({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  static final VanBusinessLogoStorageService instance =
      VanBusinessLogoStorageService._();

  final FirebaseStorage _storage;

  Future<String?> uploadBusinessLogo({
    required String ownerUid,
    required XFile logoFile,
  }) async {
    final result = await uploadBusinessLogoWithMetadata(
      ownerUid: ownerUid,
      logoFile: logoFile,
    );
    return result?.downloadUrl;
  }

  Future<VanBusinessLogoUploadResult?> uploadBusinessLogoWithMetadata({
    required String ownerUid,
    required XFile logoFile,
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      debugPrint('[BusinessLogoUpload] skipped: empty owner uid');
      return null;
    }

    final localPath = logoFile.path.trim();
    debugPrint(
      '[BusinessLogoUpload] selected local path=${localPath.isEmpty ? '(empty)' : localPath} '
      'name=${logoFile.name} uid=$normalizedOwnerUid',
    );

    final bytes = await logoFile.readAsBytes();
    if (bytes.isEmpty) {
      debugPrint('[BusinessLogoUpload] skipped: empty logo bytes');
      return null;
    }

    final extension = _resolveExtension(logoFile.name);
    final contentType = _resolveContentType(extension);
    final hash = _shortHash(bytes);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path =
        'users/$normalizedOwnerUid/van_business_profile/logo_${timestamp}_$hash.$extension';

    final ref = _storage.ref(path);
    debugPrint(
      '[BusinessLogoUpload] destination path=$path bytes=${bytes.length} contentType=$contentType',
    );
    try {
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'public,max-age=31536000',
        ),
      );
      final downloadUrl = await ref.getDownloadURL();
      debugPrint(
        '[BusinessLogoUpload] success path=$path downloadUrl=$downloadUrl',
      );
      return VanBusinessLogoUploadResult(
        downloadUrl: downloadUrl,
        storagePath: path,
      );
    } catch (error, stackTrace) {
      debugPrint('[BusinessLogoUpload] failure path=$path error=$error');
      debugPrint('[BusinessLogoUpload] stack=$stackTrace');
      rethrow;
    }
  }

  String _resolveExtension(String fileName) {
    final normalizedName = fileName.trim().toLowerCase();
    if (normalizedName.endsWith('.png')) {
      return 'png';
    }
    if (normalizedName.endsWith('.webp')) {
      return 'webp';
    }
    if (normalizedName.endsWith('.gif')) {
      return 'gif';
    }
    if (normalizedName.endsWith('.jpg') || normalizedName.endsWith('.jpeg')) {
      return 'jpg';
    }
    return 'jpg';
  }

  String _resolveContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  String _shortHash(Uint8List bytes) {
    return sha1.convert(bytes).toString().substring(0, 12);
  }
}
