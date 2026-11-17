import 'package:flutter/material.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/features/shared/widgets/status_summary.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({
    super.key,
    required this.initialConfig,
    this.status,
  });
  final DeviceStatus? status;
  final CameraConfig initialConfig;

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  late CameraConfig _saved;
  late CameraConfig _draft;

  @override
  void initState() {
    super.initState();
    _saved = widget.initialConfig;
    _draft = widget.initialConfig;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Configuration', style: text.titleLarge)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusSummary(status: widget.status),
                const SizedBox(height: 8),
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
                  onChanged: (newValue) {
                    setState(() {
                      _draft = _draft.copyWith(aiThreshold: newValue);
                    });
                  },
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
                  onChanged: (newValue) {
                    setState(() {
                      _draft = _draft.copyWith(pirThreshold: newValue);
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      key: const Key('reset_button'),
                      onPressed: _saved == _draft
                          ? null
                          : () {
                              setState(() {
                                _draft = _saved;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Configuration reset'),
                                ),
                              );
                            },
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      key: const Key('apply_button'),
                      onPressed: _saved == _draft
                          ? null
                          : () {
                              setState(() {
                                _saved = _draft;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Configuration applied'),
                                ),
                              );
                            },
                      child: const Text('Apply'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      key: const Key('test_button'),
                      onPressed: () {
                        //Add BLE "Hello World" command
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('BLE link test initiated'),
                          ),
                        );
                      },
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
