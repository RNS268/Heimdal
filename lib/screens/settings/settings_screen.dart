import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../providers/ble_provider.dart";
import "../../services/settings_service.dart";
import "../../theme/app_colors.dart";

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final bleState = ref.watch(bleConnectionStateProvider).valueOrNull;
    final devices = ref.watch(validDevicesProvider);
    final connected =
        bleState == BleConnectionState.ready ||
        bleState == BleConnectionState.connected;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section("Connected Gear", [
            ListTile(
              leading: Icon(
                connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: connected ? AppColors.primary : AppColors.error,
              ),
              title: const Text("Helmet Connectivity"),
              subtitle: Text(bleState?.name ?? "disconnected"),
              trailing: Text("${devices.length} supported"),
            ),
            ...devices
                .take(3)
                .map(
                  (d) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.sports_motorsports),
                    title: Text(d.name),
                    subtitle: Text(
                      "Capabilities: ${d.capabilities.join(", ")}",
                    ),
                  ),
                ),
          ]),
          _section("Crash & Alerts", [
            DropdownButtonFormField<String>(
              value: settings.crashSensitivity,
              items: const ["low", "medium", "high"]
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) controller.setCrashSensitivity(v);
              },
              decoration: const InputDecoration(labelText: "Crash Sensitivity"),
            ),
            const SizedBox(height: 8),
            Text("Thresholds: ${settings.crashThresholds}"),
            SwitchListTile(
              title: const Text("Auto SOS on crash"),
              value: settings.autoSOS,
              onChanged: controller.setAutoSos,
            ),
          ]),
          _section("Emergency Contacts", [
            Text(
              settings.emergencyContacts.isEmpty
                  ? "No contacts set. Fallback emergency number: ${controller.fallbackEmergency}"
                  : "${settings.emergencyContacts.length}/5 contacts configured",
            ),
            const SizedBox(height: 8),
            ...settings.emergencyContacts.map(
              (c) => ListTile(
                leading: const Icon(Icons.contact_phone),
                title: Text(c.name),
                subtitle: Text(c.phone),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => controller.removeEmergencyContact(c),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _AddContactForm(
              onSubmit: (name, phone) async {
                final err = await controller.addEmergencyContact(name, phone);
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(err)));
                }
              },
            ),
          ]),
          _section("App Preferences", [
            DropdownButtonFormField<String>(
              value: settings.theme,
              items: const ["dark", "light"]
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) controller.setTheme(v);
              },
              decoration: const InputDecoration(labelText: "Theme"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: settings.units,
              items: const ["metric", "imperial"]
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) controller.setUnits(v);
              },
              decoration: const InputDecoration(labelText: "Units"),
            ),
            if (settings.lastSyncedAt != null) ...[
              const SizedBox(height: 8),
              Text("Synced: ${settings.lastSyncedAt}"),
            ],
          ]),
        ],
      ),
    );
  }
}

Widget _section(String title, List<Widget> children) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _AddContactForm extends StatefulWidget {
  const _AddContactForm({required this.onSubmit});
  final Future<void> Function(String name, String phone) onSubmit;

  @override
  State<_AddContactForm> createState() => _AddContactFormState();
}

class _AddContactFormState extends State<_AddContactForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: "Name"),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: "Phone"),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            await widget.onSubmit(_name.text.trim(), _phone.text.trim());
            if (mounted) {
              _name.clear();
              _phone.clear();
            }
          },
        ),
      ],
    );
  }
}
