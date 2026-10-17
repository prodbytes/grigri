import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/config.dart';
import 'package:grigri_app/data/apple_sign_in.dart';

void main() {
  test('Apple\'s web flow returns to the site\'s callback', () {
    expect(AppConfig.appleServiceId, 'com.nu01.grigri.signin');
    expect(AppConfig.appleRedirectUri.path, '/api/apple/callback');
    expect(AppConfig.appleRedirectUri.scheme, 'https');
  });

  test('a closed or cancelled web popup is a quiet cancel', () {
    expect(
      webCancelled('Authentication failed with popup_closed_by_user'),
      isTrue,
    );
    expect(
      webCancelled('Authentication failed with user_cancelled_authorize'),
      isTrue,
    );
    expect(webCancelled('Authentication failed with invalid_client'), isFalse);
  });

  test('offered on Android, iOS and the web', () {
    expect(const NativeAppleSignIn().available, isTrue);
  });
}
