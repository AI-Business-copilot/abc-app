import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:abc_app/core/network/api_client.dart';

class UploadService {
  final _dio = ApiClient().dio;
  final _picker = ImagePicker();

  Future<XFile?> pickImageFromGallery() async {
    return await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
  }

  Future<XFile?> pickImageFromCamera() async {
    return await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
  }

  Future<String?> uploadImage(XFile imageFile) async {
    try {
      final bytes = await File(imageFile.path).readAsBytes();
      final base64String = base64Encode(bytes);
      final filename = imageFile.name;

      final response = await _dio.post(
        '/upload',
        data: {
          'base64': base64String,
          'filename': filename,
          'contentType': 'image/jpeg',
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data['url']?.toString();
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
