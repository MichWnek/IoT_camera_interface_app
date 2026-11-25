import 'package:camera_trap_app/data/ble/ble_adapter.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:camera_trap_app/features/nearby/view/device_screen.dart';
import 'package:camera_trap_app/state/bluetooth_cubit.dart';
import 'package:camera_trap_app/state/scan_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lists Bluetooth devices in range, strongest signal first. Also guides the
/// user through permissions and switching Bluetooth on.
class NearbyDevicesScreen extends StatelessWidget {
  const NearbyDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScanCubit(context.read<BleAdapter>()),
      child: const _NearbyDevicesView(),
    );
  }
}

class _NearbyDevicesView extends StatefulWidget {
  const _NearbyDevicesView();

  @override
  State<_NearbyDevicesView> createState() => _NearbyDevicesViewState();
}

class _NearbyDevicesViewState extends State<_NearbyDevicesView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back from the system settings may have changed permissions.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<BluetoothCubit>().recheck(),
    );
    if (context.read<BluetoothCubit>().state == BleAvailability.ready) {
      context.read<ScanCubit>().start();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocListener<BluetoothCubit, BleAvailability>(
      // Start scanning as soon as Bluetooth becomes usable.
      listenWhen: (previous, current) =>
          previous != BleAvailability.ready && current == BleAvailability.ready,
      listener: (context, _) => context.read<ScanCubit>().start(),
      child: Scaffold(
        appBar: AppBar(title: Text('Nearby devices', style: text.titleLarge)),
        body: BlocBuilder<BluetoothCubit, BleAvailability>(
          builder: (context, availability) => switch (availability) {
            BleAvailability.checking => const Center(
              child: CircularProgressIndicator(),
            ),
            BleAvailability.unsupported => const _Message(
              icon: Icons.bluetooth_disabled,
              text: "This phone doesn't support Bluetooth Low Energy.",
            ),
            BleAvailability.permissionRequired => _Message(
              icon: Icons.bluetooth,
              text:
                  'The app needs permission to use Bluetooth to find and '
                  'connect to camera traps.',
              actionLabel: 'Allow Bluetooth',
              onAction: () =>
                  context.read<BluetoothCubit>().requestPermissions(),
            ),
            BleAvailability.permissionPermanentlyDenied => _Message(
              icon: Icons.bluetooth,
              text:
                  'Bluetooth permission was denied. Allow "Nearby devices" '
                  'for this app in the system settings.',
              actionLabel: 'Open settings',
              onAction: () => context.read<BluetoothCubit>().openSettings(),
            ),
            BleAvailability.off => _Message(
              icon: Icons.bluetooth_disabled,
              text: context.read<BluetoothCubit>().canTurnOn
                  ? 'Bluetooth is off.'
                  : 'Bluetooth is off. Turn it on in Control Center or '
                        'Settings.',
              actionLabel: context.read<BluetoothCubit>().canTurnOn
                  ? 'Turn on Bluetooth'
                  : null,
              onAction: () => context.read<BluetoothCubit>().turnOn(),
            ),
            BleAvailability.ready => const _ScanResults(),
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (label != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanResults extends StatelessWidget {
  const _ScanResults();

  void _open(BuildContext context, BleScanResult device) {
    // Android connects less reliably while a scan is running.
    context.read<ScanCubit>().stop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeviceScreen(
          deviceId: device.id,
          name: device.hasName ? device.name : 'Unnamed device',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scan = context.watch<ScanCubit>().state;
    final devices = scan.visibleResults;
    final error = scan.error;

    return Column(
      children: [
        if (scan.isScanning) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('scan_button'),
                onPressed: scan.isScanning
                    ? () => context.read<ScanCubit>().stop()
                    : () => context.read<ScanCubit>().start(),
                icon: Icon(scan.isScanning ? Icons.stop : Icons.refresh),
                label: Text(scan.isScanning ? 'Stop' : 'Scan again'),
              ),
              FilterChip(
                label: const Text('Show unnamed'),
                selected: scan.showUnnamed,
                onSelected: (show) =>
                    context.read<ScanCubit>().setShowUnnamed(show),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(error, style: text.bodyMedium),
          ),
        Expanded(
          child: devices.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      scan.isScanning
                          ? 'Looking for devices…'
                          : 'No devices found. On Android 11 and older, '
                                'Location must also be switched on to scan.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: Icon(_signalIcon(device.rssi)),
                      title: Text(
                        device.hasName ? device.name : 'Unnamed device',
                      ),
                      subtitle: Text(device.id),
                      trailing: Text('${device.rssi} dBm'),
                      onTap: () => _open(context, device),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static IconData _signalIcon(int rssi) => switch (rssi) {
    >= -60 => Icons.signal_cellular_alt,
    >= -80 => Icons.signal_cellular_alt_2_bar,
    _ => Icons.signal_cellular_alt_1_bar,
  };
}
