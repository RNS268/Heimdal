class DeviceModel {
  final String name;
  final bool isConnected;
  final List<String> capabilities;

  DeviceModel({
    required this.name,
    required this.isConnected,
    required this.capabilities,
  });
}

List<DeviceModel> getValidDevices(List<DeviceModel> devices) {
  return devices.where((d) => d.isConnected && d.capabilities.isNotEmpty).toList();
}
