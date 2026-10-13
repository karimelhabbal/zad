import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/settings_models.dart';

/// Resolves the coordinates used for prayer times and the Qibla.
///
/// The location is used **live** and is never sent anywhere; only the optional
/// manual city (and its coordinates) is persisted locally so the app still
/// works when permission is denied.
class LocationService {
  LocationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Resolves a usable location from the saved settings.
  Future<ResolvedLocation> resolve(PrayerLocation settings) async {
    if (!settings.useDeviceLocation) {
      return _fromManual(settings);
    }
    return resolveFromDevice(settings);
  }

  /// Asks the device for a position, handling every permission state.
  Future<ResolvedLocation> resolveFromDevice(PrayerLocation settings) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final manual = _fromManual(settings);
      if (manual.isOk) return manual;
      return const ResolvedLocation(status: LocationStatus.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      final manual = _fromManual(settings);
      if (manual.isOk) return manual;
      return const ResolvedLocation(
        status: LocationStatus.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      final manual = _fromManual(settings);
      if (manual.isOk) return manual;
      return const ResolvedLocation(status: LocationStatus.permissionDenied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 25),
        ),
      );
      return ResolvedLocation(
        status: LocationStatus.ok,
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: settings.cityName,
      );
    } catch (_) {
      // Try the last known fix before giving up.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return ResolvedLocation(
            status: LocationStatus.ok,
            latitude: last.latitude,
            longitude: last.longitude,
            cityName: settings.cityName,
          );
        }
      } catch (_) {
        // ignore and fall through
      }
      final manual = _fromManual(settings);
      if (manual.isOk) return manual;
      return const ResolvedLocation(status: LocationStatus.unavailable);
    }
  }

  ResolvedLocation _fromManual(PrayerLocation settings) {
    if (!settings.hasCoordinates) {
      return const ResolvedLocation(status: LocationStatus.notConfigured);
    }
    return ResolvedLocation(
      status: LocationStatus.ok,
      latitude: settings.latitude,
      longitude: settings.longitude,
      cityName: settings.cityName,
    );
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Resolves a city name to coordinates using the Open-Meteo geocoding API
  /// (free, no API key). Returns an empty list when nothing matched or offline.
  Future<List<GeoPlace>> searchCity(String query, {String language = 'ar'}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const <GeoPlace>[];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': trimmed,
      'count': '8',
      'language': language,
      'format': 'json',
    });
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const <GeoPlace>[];
      return GeoPlace.parseResults(response.body);
    } catch (_) {
      return const <GeoPlace>[];
    }
  }

  void dispose() => _client.close();
}

/// A geocoding result.
class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? country;

  String get label => country == null ? name : '$name، $country';

  /// Parses the Open-Meteo geocoding payload. Kept static and dependency-free
  /// so it can be unit tested without a network call.
  static List<GeoPlace> parseResults(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return const <GeoPlace>[];
      final results = decoded['results'];
      if (results is! List) return const <GeoPlace>[];
      final out = <GeoPlace>[];
      for (final entry in results) {
        if (entry is! Map) continue;
        final name = entry['name'];
        final lat = entry['latitude'];
        final lng = entry['longitude'];
        if (name is! String || lat is! num || lng is! num) continue;
        out.add(
          GeoPlace(
            name: name,
            latitude: lat.toDouble(),
            longitude: lng.toDouble(),
            country: entry['country'] as String?,
          ),
        );
      }
      return out;
    } catch (_) {
      return const <GeoPlace>[];
    }
  }
}
