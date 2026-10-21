// ignore_for_file: avoid_print, public_member_api_docs

/// Minimal stand-in for `package:flutter/services.dart`.
///
/// Only the surface needed by `path_provider_platform_interface`
/// (`MethodChannel`, `PlatformException`, etc.) is stubbed so the harness
/// can compile and run on the plain Dart VM.
library;

class MethodChannel {
  const MethodChannel(this.name, [this.codec]);
  final String name;
  final MethodCodec? codec;

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    throw UnsupportedError(
      'MethodChannel("$name").invokeMethod("$method") is not supported on the Dart VM.',
    );
  }

  Future<List<T>?> invokeListMethod<T>(String method, [dynamic arguments]) async {
    throw UnsupportedError(
      'MethodChannel("$name").invokeListMethod("$method") is not supported on the Dart VM.',
    );
  }

  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {}
}

class MethodCall {
  const MethodCall(this.method, [this.arguments]);
  final String method;
  final dynamic arguments;
}

class PlatformException implements Exception {
  PlatformException({
    required this.code,
    this.message,
    this.details,
    this.stacktrace,
  });
  final String code;
  final String? message;
  final dynamic details;
  final String? stacktrace;

  @override
  String toString() => 'PlatformException($code, $message, $details, $stacktrace)';
}

class MissingPluginException implements Exception {
  MissingPluginException([this.message]);
  final String? message;

  @override
  String toString() => 'MissingPluginException($message)';
}

class BasicMessageChannel<T> {
  const BasicMessageChannel(this.name, this.codec);
  final String name;
  final MessageCodec<T> codec;
}

class EventChannel {
  const EventChannel(this.name, [this.codec]);
  final String name;
  final MethodCodec? codec;
}

abstract class MethodCodec {
  const MethodCodec();
}

class JSONMethodCodec extends MethodCodec {
  const JSONMethodCodec();
}

class StandardMethodCodec extends MethodCodec {
  const StandardMethodCodec();
}

abstract class MessageCodec<T> {
  const MessageCodec();
}

class StandardMessageCodec extends MessageCodec<dynamic> {
  const StandardMessageCodec();
}

abstract class BinaryMessenger {
  const BinaryMessenger();
}
