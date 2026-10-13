import 'package:geolocator/geolocator.dart';

import '../log.dart';

/// Where the phone or browser is, for my profile's location: the device's
/// own positioning (GPS, network, the browser's geolocation), so nothing
/// to pay for. See specs/matching.md, Where I climb.
abstract class DeviceLocation {
  const DeviceLocation();

  /// Never knows (tests, and the default).
  const factory DeviceLocation.none() = _NoDeviceLocation;

  /// Where the device is, about; null when it can't tell: no location
  /// service, permission refused, or no fix in time.
  Future<({double lat, double lon})?> current();
}

class _NoDeviceLocation extends DeviceLocation {
  const _NoDeviceLocation();

  @override
  Future<({double lat, double lon})?> current() async => null;
}

/// The platform's location, through geolocator. Asks for permission (the
/// system's prompt) the first time; coarse is enough, the server keeps
/// only about 1 km anyway.
class GeolocatorDeviceLocation extends DeviceLocation {
  const GeolocatorDeviceLocation({this.timeout = const Duration(seconds: 15)});

  final Duration timeout;

  @override
  Future<({double lat, double lon})?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: timeout,
        ),
      );
      return (lat: position.latitude, lon: position.longitude);
    } on Object catch (e) {
      log.warn('location', 'no device location', e);
      return null;
    }
  }
}
