import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:carplay/core/trip_manager.dart';

class SettingsScreen extends StatefulWidget {
  // FIX: Remove initialImperial parameter entirely.
  // It was the root cause of the toggle resetting — dashboard passed false
  // every time (because _useImperial in dashboard was never loaded from Hive),
  // then _loadSettings() read the correct value from Hive but immediately
  // overwrote it with widget.initialImperial (which was always false).
  // Now SettingsScreen reads directly from Hive — single source of truth.
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _useImperial;
  late bool _autoStart;
  late Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _settingsBox = Hive.box('settings');
    // FIX: Read ONLY from Hive — no widget parameter to overwrite it
    _useImperial = _settingsBox.get('useImperial', defaultValue: false) as bool;
    _autoStart = _settingsBox.get('autoStart', defaultValue: false) as bool;
  }

  void _saveAndPop() {
    _settingsBox.put('useImperial', _useImperial);
    _settingsBox.put('autoStart', _autoStart);
    TripState.instance.autoStart = _autoStart;
    // FIX: Return _useImperial so dashboard can update its display unit
    Navigator.pop(context, _useImperial);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: _saveAndPop,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _SectionHeader(label: 'UNITS'),
            _SettingsTile(
              title: 'Imperial Units',
              subtitle: 'Display mph and miles instead of km/h and km',
              value: _useImperial,
              onChanged: (v) {
                setState(() => _useImperial = v);
                // Save immediately on toggle — no need to press back
                _settingsBox.put('useImperial', v);
              },
            ),

            const SizedBox(height: 24),
            const _SectionHeader(label: 'TRIP BEHAVIOUR'),
            _SettingsTile(
              title: 'Auto-Start Trip',
              subtitle:
                  'Automatically starts a trip when speed exceeds 10 km/h',
              value: _autoStart,
              onChanged: (v) {
                setState(() => _autoStart = v);
                _settingsBox.put('autoStart', v);
                TripState.instance.autoStart = v;
              },
            ),

            const SizedBox(height: 24),
            const _SectionHeader(label: 'ABOUT'),
            const _InfoTile(label: 'Version', value: '1.0.0'),
            const _InfoTile(label: 'Speed source', value: 'GPS only (no OBD)'),
            const _InfoTile(label: 'Car display', value: 'Android Auto'),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00E676),
        inactiveTrackColor: Colors.white12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
