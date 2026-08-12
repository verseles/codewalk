import 'package:codewalk/presentation/widgets/chat_input_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('done is terminal even before service finalization clears', () {
    expect(
      speechStatusIndicatesListening(status: 'done', serviceIsListening: true),
      isFalse,
    );
  });

  test('processing remains busy while the service is finalizing', () {
    expect(
      speechStatusIndicatesListening(
        status: 'processing',
        serviceIsListening: true,
      ),
      isTrue,
    );
  });
}
