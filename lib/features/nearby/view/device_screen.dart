import 'package:camera_trap_app/data/ble/ble_adapter.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:camera_trap_app/state/device_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Connects to one device and lists its services and characteristics.
/// A diagnostic tool until the camera protocol is defined; readable
/// characteristics can be read by tapping them.
class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key, required this.deviceId, required this.name});

  final String deviceId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DeviceCubit(context.read<BleAdapter>(), deviceId)..connect(),
      child: _DeviceView(deviceId: deviceId, name: name),
    );
  }
}

class _DeviceView extends StatelessWidget {
  const _DeviceView({required this.deviceId, required this.name});

  final String deviceId;
  final String name;

  static String _phaseLabel(DevicePhase phase) => switch (phase) {
    DevicePhase.disconnected => 'Disconnected',
    DevicePhase.connecting => 'Connecting…',
    DevicePhase.discovering => 'Reading services…',
    DevicePhase.connected => 'Connected',
    DevicePhase.disconnecting => 'Disconnecting…',
  };

  Future<void> _read(
    BuildContext context,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final hex = await context.read<DeviceCubit>().readHex(
        serviceUuid,
        characteristicUuid,
      );
      message = 'Value: $hex';
    } catch (_) {
      message = 'Could not read the value';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final device = context.watch<DeviceCubit>().state;
    final error = device.error;
    final connected = device.phase == DevicePhase.connected;

    return Scaffold(
      appBar: AppBar(title: Text(name, style: text.titleLarge)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(deviceId, style: text.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _phaseLabel(device.phase),
                  key: const Key('device_phase'),
                  style: text.titleMedium,
                ),
              ),
              FilledButton(
                key: const Key('connect_button'),
                onPressed: device.isBusy
                    ? null
                    : connected
                    ? () => context.read<DeviceCubit>().disconnect()
                    : () => context.read<DeviceCubit>().connect(),
                child: Text(connected ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
          if (device.isBusy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error, style: text.bodyMedium),
          ],
          if (connected) ...[
            const SizedBox(height: 16),
            Text('Services', style: text.titleMedium),
            if (device.services.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('The device reports no services.'),
              ),
            for (final service in device.services)
              _ServiceSection(
                service: service,
                onRead: (characteristic) =>
                    _read(context, service.uuid, characteristic.uuid),
              ),
          ],
        ],
      ),
    );
  }
}

class _ServiceSection extends StatelessWidget {
  const _ServiceSection({required this.service, required this.onRead});

  final BleServiceInfo service;
  final void Function(BleCharacteristicInfo characteristic) onRead;

  static String _properties(BleCharacteristicInfo c) => [
    if (c.canRead) 'read',
    if (c.canWrite) 'write',
    if (c.canNotify) 'notify',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Service ${service.uuid}', style: text.titleSmall),
            ),
            for (final characteristic in service.characteristics)
              ListTile(
                dense: true,
                title: Text(characteristic.uuid),
                subtitle: Text(_properties(characteristic)),
                trailing: characteristic.canRead
                    ? const Icon(Icons.download)
                    : null,
                onTap: characteristic.canRead
                    ? () => onRead(characteristic)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
