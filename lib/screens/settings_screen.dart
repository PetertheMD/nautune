import 'package:flutter/material.dart';
import '../app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.appState});

  final NautuneAppState appState;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableTranscoding = false;
  int _transcodingBitrate = 320;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Playback',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Transcoding'),
            subtitle: const Text(
              'Convert audio format for compatibility (uses more server resources)',
            ),
            value: _enableTranscoding,
            onChanged: (value) {
              setState(() {
                _enableTranscoding = value;
              });
              // TODO: Save preference
            },
          ),
          if (_enableTranscoding)
            ListTile(
              title: const Text('Transcoding Bitrate'),
              subtitle: Text('${_transcodingBitrate}kbps'),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: _transcodingBitrate.toDouble(),
                  min: 128,
                  max: 320,
                  divisions: 3,
                  label: '${_transcodingBitrate}kbps',
                  onChanged: (value) {
                    setState(() {
                      _transcodingBitrate = value.toInt();
                    });
                    // TODO: Save preference
                  },
                ),
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Downloads',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Download Quality'),
            subtitle: const Text('Original (lossless when available)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show quality picker
            },
          ),
          ListTile(
            title: const Text('Storage Location'),
            subtitle: const Text('App documents directory'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show location picker
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Server',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Server URL'),
            subtitle: Text(widget.appState.session?.serverUrl ?? 'Not connected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Allow changing server
            },
          ),
          ListTile(
            title: const Text('Username'),
            subtitle: Text(widget.appState.session?.username ?? 'Not logged in'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'About',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0+1'),
          ),
          ListTile(
            title: const Text('Open Source Licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(context: context);
            },
          ),
        ],
      ),
    );
  }
}
