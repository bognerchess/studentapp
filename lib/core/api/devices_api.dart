// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/generated/operations/devices.graphql.dart';
import 'package:bogner_chess/core/api/generated/operations/fragments.graphql.dart';
import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/mappers/enum_mappers.dart';
import 'package:bogner_chess/core/api/mappers/mutation_error.dart';
import 'package:bogner_chess/core/api/models/device_models.dart';

export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/device_models.dart'
    show ApnsEnvironment, RegisteredDevice;

/// This installation's registration for push.
class DevicesApi {
  DevicesApi(this._executor);

  final ApiExecutor _executor;

  /// Registers or refreshes this installation. Call it after sign-in and
  /// whenever the APNs token changes. [apnsToken] is null while the user has
  /// not granted push permission; a token the server has is kept then.
  ///
  /// Throws an `ApiError`; a rate limit is an `ApiRejected` with `retryAfter`.
  Future<RegisteredDevice> register({
    required String deviceId,
    required ApnsEnvironment environment,
    String? apnsToken,
    String? appVersion,
    String? locale,
  }) async {
    final data = await _executor.mutate(
      document: documentNodeMutationRegisterMobileDevice,
      operationName: 'RegisterMobileDevice',
      variables: Variables$Mutation$RegisterMobileDevice(
        input: Input$RegisterMobileDeviceInput(
          deviceId: deviceId,
          apnsToken: apnsToken,
          environment: apnsEnvironmentToWire(environment),
          appVersion: appVersion,
          locale: locale,
        ),
      ).toJson(),
      parse: Mutation$RegisterMobileDevice.fromJson,
    );
    final payload = data.registerMobileDevice;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      throw error.toRejected();
    }
    final device = payload.mobileDevice;
    if (device == null) {
      throw emptyPayload('RegisterMobileDevice');
    }
    return _deviceOf(device);
  }

  /// Stops push for this installation (sign-out). Idempotent: null when the
  /// server did not know the device. Throws an `ApiError`.
  Future<RegisteredDevice?> unregister(String deviceId) async {
    final data = await _executor.mutate(
      document: documentNodeMutationUnregisterMobileDevice,
      operationName: 'UnregisterMobileDevice',
      variables: Variables$Mutation$UnregisterMobileDevice(
        input: Input$UnregisterMobileDeviceInput(deviceId: deviceId),
      ).toJson(),
      parse: Mutation$UnregisterMobileDevice.fromJson,
    );
    final payload = data.unregisterMobileDevice;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      throw error.toRejected();
    }
    final device = payload.mobileDevice;
    return device == null ? null : _deviceOf(device);
  }

  static RegisteredDevice _deviceOf(Fragment$DeviceFields device) =>
      RegisteredDevice(
        id: device.id,
        deviceId: device.deviceId,
        lastSeenAt: device.lastSeenAt,
        revokedAt: device.revokedAt,
      );
}
