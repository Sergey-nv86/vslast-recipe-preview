import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

@JS('window.vslastRecipeOcr')
external JSPromise<JSString> _recognizeRecipeImages(JSString imagesJson);

class LocalRecipeOcrService {
  LocalRecipeOcrService._();

  static final instance = LocalRecipeOcrService._();

  Future<String> recognize(List<XFile> photos) async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Локальный OCR сейчас доступен в веб-версии preview.',
      );
    }
    if (photos.isEmpty || photos.length > 8) {
      throw ArgumentError('Нужно выбрать от 1 до 8 фотографий.');
    }

    final dataUrls = <String>[];
    for (final photo in photos) {
      final name = photo.name.toLowerCase();
      final mime = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
      final bytes = await photo.readAsBytes();
      dataUrls.add('data:$mime;base64,${base64Encode(bytes)}');
    }

    try {
      final result = await _recognizeRecipeImages(
        jsonEncode(dataUrls).toJS,
      ).toDart;
      return result.toDart.trim();
    } catch (error) {
      throw Exception(
        'Не удалось запустить локальное распознавание. Проверьте интернет для первой загрузки OCR-модуля и повторите попытку. Подробности: $error',
      );
    }
  }
}
