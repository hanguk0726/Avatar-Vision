import 'package:flutter_test/flutter_test.dart';
import 'package:video_diary/services/native.dart';

void main() {
  test('Native object initialization and get call', () {
    final native = Native();
    native.init();
    expect(native.textureId, isNotNull);
  });
}
