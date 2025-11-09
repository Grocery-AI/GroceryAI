import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 圖片上傳服務
/// 提供選擇和上傳圖片的功能
class ImageService {
  static final ImagePicker _imagePicker = ImagePicker();

  /// 從相機或相冊選擇圖片
  /// [source] 可以是 ImageSource.camera 或 ImageSource.gallery
  /// 返回選中的圖片文件，如果用戶取消則返回 null
  static Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85, // 壓縮品質
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// 顯示圖片選擇對話框（相機或相冊）
  static Future<File?> showImagePickerDialog(BuildContext context) async {
    final imageFile = await showDialog<File?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Image',
            style: TextStyle(
              fontFamily: 'Boska',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Choose image source:',
            style: TextStyle(
              fontFamily: 'Boska',
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Boska',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final file = await pickImage(source: ImageSource.camera);
                if (file != null && context.mounted) {
                  Navigator.pop(context, file);
                }
              },
              child: Text(
                'Camera',
                style: TextStyle(
                  fontFamily: 'Boska',
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF064E3B),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final file = await pickImage(source: ImageSource.gallery);
                if (file != null && context.mounted) {
                  Navigator.pop(context, file);
                }
              },
              child: Text(
                'Gallery',
                style: TextStyle(
                  fontFamily: 'Boska',
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF064E3B),
                ),
              ),
            ),
          ],
        );
      },
    );

    return imageFile;
  }

  /// 將圖片文件轉換為 base64 字符串
  static Future<String> imageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Error converting image to base64: $e');
      throw Exception('Failed to convert image to base64');
    }
  }

  /// 獲取圖片文件的大小（字節）
  static Future<int> getImageSize(File imageFile) async {
    try {
      return await imageFile.length();
    } catch (e) {
      print('Error getting image size: $e');
      return 0;
    }
  }

  /// 檢查圖片大小是否超過限制（默認 5MB）
  static Future<bool> isImageSizeValid(
    File imageFile, {
    int maxSizeMB = 5,
  }) async {
    final sizeInBytes = await getImageSize(imageFile);
    final sizeInMB = sizeInBytes / (1024 * 1024);
    return sizeInMB <= maxSizeMB;
  }
}
