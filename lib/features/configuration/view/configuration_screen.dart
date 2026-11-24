import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera_trap_app/data/camera_service.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/features/shared/widgets/status_summary.dart';
import 'package:camera_trap_app/state/cameras_cubit.dart';
import 'package:camera_trap_app/state/cameras_state.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({
    super.key,
    required this.cameraId,
    required this.initialConfig,
  });

  final String cameraId;
  final CameraConfig initialConfig;

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  late CameraConfig _saved;
  late CameraConfig _draft;
  bool _pinging = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.initialConfig;
    _draft = widget.initialConfig;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _ping() async {
    final service = context.read<CameraService>();
    setState(() => _pinging = true);
    String message;
    try {
      final rtt = await service
          .ping(widget.cameraId)
          .timeout(const Duration(seconds: 1));
      message = 'Echo in ${rtt.inMilliseconds} ms';
    } on TimeoutException {
      message = 'No response from camera';
    } finally {
      if (mounted) setState(() => _pinging = false);
    }
    if (!mounted) return;
    _showMessage(message);
  }

  Future<void> _apply() async {
    final service = context.read<CameraService>();
    final config = _draft;
    setState(() => _applying = true);
    String message;
    try {
      await service
          .applyConfig(widget.cameraId, config)
          .timeout(const Duration(seconds: 5));
      if (mounted) setState(() => _saved = config);
      message = 'Configuration applied';
    } on TimeoutException {
      message = 'No response from camera, configuration not applied';
    } catch (_) {
      message = 'Could not apply configuration';
    } finally {
      if (mounted) setState(() => _applying = false);
    }
    if (!mounted) return;
    _showMessage(message);
  }

  void _reset() {
    setState(() => _draft = _saved);
    _showMessage('Configuration reset');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Rebuilds only when this camera changes, e.g. on a live status update.
    final camera = context.select<CamerasCubit, CameraTrap?>(
      (cubit) => switch (cubit.state) {
        CamerasLoaded loaded => loaded.byId(widget.cameraId),
        _ => null,
      },
    );

    final hasChanges = _saved != _draft;
    final canEdit = !_applying;

    return Scaffold(
      appBar: AppBar(title: Text('Configuration', style: text.titleLarge)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (camera != null) ...[
                  Text(camera.name, style: text.titleMedium),
                  const SizedBox(height: 4),
                ],
                StatusSummary(status: camera?.status),
                const SizedBox(height: 8),
                Text(
                  'AI Threshold: ${(_draft.aiThreshold * 100).toStringAsFixed(0)}%',
                ),
                Slider(
                  key: const Key('ai_threshold_slider'),
                  value: _draft.aiThreshold,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: canEdit
                      ? (newValue) => setState(
                          () => _draft = _draft.copyWith(aiThreshold: newValue),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  'PIR Threshold: ${_draft.pirThreshold.toStringAsFixed(2)} V',
                ),
                Slider(
                  key: const Key('pir_threshold_slider'),
                  value: _draft.pirThreshold,
                  min: 0.0,
                  max: 3.3,
                  onChanged: canEdit
                      ? (newValue) => setState(
                          () =>
                              _draft = _draft.copyWith(pirThreshold: newValue),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      key: const Key('reset_button'),
                      onPressed: hasChanges && canEdit ? _reset : null,
                      child: const Text('Reset'),
                    ),
                    ElevatedButton(
                      key: const Key('apply_button'),
                      onPressed: hasChanges && canEdit ? _apply : null,
                      child: Text(_applying ? 'Applying…' : 'Apply'),
                    ),
                    OutlinedButton(
                      key: const Key('test_button'),
                      // TODO: send BLE "hello" test command
                      onPressed: _pinging ? null : _ping,
                      child: const Text('Test'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
