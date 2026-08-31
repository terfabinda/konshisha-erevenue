import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/services/printer_service.dart';

// Consistent with Dashboard branding
class AppColors {
  static const primary = Color(0xFF0E4D31); // Deep Emerald
  static const secondary = Color(0xFF1E293B); // Slate Blue
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const success = Color(0xFF10B981);
}

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen>
    with SingleTickerProviderStateMixin {
  final PrinterService _printerService = PrinterService();

  bool _isBluetoothEnabled = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _hasPermissions = false;
  bool _permissionDenied = false;
  String? _selectedPrinterName;
  String? _connectedPrinterName;

  // For scanning animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initPrinter();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initPrinter() async {
    await _printerService.init();

    // Check and request permissions
    _hasPermissions = await _printerService.requestBluetoothPermissions();
    if (!_hasPermissions) {
      _permissionDenied = true;
      if (mounted) setState(() {});
      _showSnackBar(
        'Bluetooth permissions required for device discovery',
        isError: true,
      );
      return;
    }

    _isBluetoothEnabled = await _printerService.checkBluetoothEnabled();

    _printerService.onBluetoothStateChanged = (enabled) {
      if (mounted) setState(() => _isBluetoothEnabled = enabled);
    };

    _printerService.onDeviceConnected = (device) {
      if (mounted) {
        setState(() {
          _connectedPrinterName = device?.name;
          _selectedPrinterName = device?.name;
          _isConnecting = false;
        });
        _showSnackBar('Printer Ready', isSuccess: true);
      }
    };

    _printerService.onDeviceDisconnected = (device) {
      if (mounted) {
        setState(() => _connectedPrinterName = null);
        _showSnackBar('Printer Disconnected');
      }
    };

    _printerService.onScanStarted = () {
      if (mounted) setState(() => _isScanning = true);
    };

    _printerService.onScanStopped = () {
      if (mounted) setState(() => _isScanning = false);
    };

    _printerService.onDevicesUpdated = (devices) {
      if (mounted) setState(() {});
    };

    if (_isBluetoothEnabled && _hasPermissions) {
      _scanForDevices();
    }
  }

  Future<void> _scanForDevices() async {
    if (_isScanning) return;

    // Check permissions again before scanning
    if (!_hasPermissions) {
      _permissionDenied = true;
      setState(() {});
      _showSnackBar(
        'Please enable Bluetooth permissions in settings',
        isError: true,
      );
      return;
    }

    setState(() => _isScanning = true);

    try {
      // First get paired devices
      await _printerService.getPairedDevices();

      // Then start discovery for available devices
      await _printerService.startDeviceDiscovery();
    } catch (e) {
      debugPrint('Error scanning for devices: $e');
      _showSnackBar('Error scanning for devices', isError: true);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToPrinter(PrinterDevice printer) async {
    // Only allow connection if it's a paired device (has BluetoothDevice)
    if (printer.device == null) {
      _showSnackBar(
        'This device is not yet paired. Please pair it first in Bluetooth settings.',
        isError: true,
      );
      return;
    }

    setState(() {
      _selectedPrinterName = printer.name;
      _isConnecting = true;
    });

    final success = await _printerService.connect(printer.device!);
    if (!success && mounted) {
      setState(() => _isConnecting = false);
      _showSnackBar('Failed to connect');
    }
  }

  Future<void> _testPrint() async {
    if (!_printerService.isConnected) {
      _showSnackBar('No printer connected', isError: true);
      return;
    }

    setState(() => _isConnecting = true);

    try {
      // Initialize printer first
      final initialized = await _printerService.initializePrinter();
      if (!initialized) {
        _showSnackBar('Failed to initialize printer', isError: true);
        return;
      }

      // Send test page
      final success = await _printerService.printTestPage();

      if (mounted) {
        setState(() => _isConnecting = false);
        _showSnackBar(
          success
              ? 'Test page printed successfully! Check your printer.'
              : 'Failed to send test page to printer',
          isSuccess: success,
          isError: !success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        _showSnackBar('Error during test print: $e', isError: true);
      }
    }
  }

  void _showSnackBar(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Colors.redAccent
            : (isSuccess ? AppColors.primary : Colors.grey.shade700),
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.secondary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Printer Setup",
          style: TextStyle(
            color: AppColors.secondary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildConnectionStatusCard(),
                const SizedBox(height: 32),
                _buildBluetoothSection(),
                const SizedBox(height: 32),
                _buildDeviceListSection(),
                const SizedBox(height: 32),
                _buildSettingsSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
          _buildBottomActionArea(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    final bool isConnected = _connectedPrinterName != null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected
              ? [AppColors.primary, const Color(0xFF166534)]
              : [AppColors.secondary, const Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isConnected ? AppColors.primary : AppColors.secondary)
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(
              isConnected
                  ? Icons.check_circle_rounded
                  : Icons.print_disabled_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isConnected ? "Printer Connected" : "No Device Linked",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isConnected
                ? _connectedPrinterName!
                : "Please select a paired thermal printer",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          if (isConnected) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _isConnecting ? null : _testPrint,
              icon: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _isConnecting ? "Testing..." : "Print Test Page",
                style: const TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBluetoothSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: "Hardware Settings"),
        if (_permissionDenied)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bluetooth permissions required',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Open Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            leading: Icon(
              Icons.bluetooth_rounded,
              color: _isBluetoothEnabled ? Colors.blue : Colors.grey,
            ),
            title: const Text(
              "Bluetooth Status",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _isBluetoothEnabled
                  ? (_hasPermissions
                        ? "Active and scanning"
                        : "Enabled (no permissions)")
                  : "Turned off",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Switch.adaptive(
              value: _isBluetoothEnabled,
              activeColor: AppColors.primary,
              onChanged: (val) {
                setState(() => _isBluetoothEnabled = val);
                if (val && _hasPermissions) _scanForDevices();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceListSection() {
    final devices = _printerService.allDevices;

    // Debug: Log categorization details
    debugPrint('=== Device Categorization Debug ===');
    debugPrint('Total devices: ${devices.length}');
    for (var d in devices) {
      debugPrint(
        'Device: ${d.name} (${d.address})'
        ' | isPrinter: ${d.isPrinter}'
        ' | isDiscovered: ${d.isDiscovered}'
        ' | hasDevice: ${d.device != null}',
      );
    }

    // Categorize devices - be explicit about the filters
    final confirmedPrinters = devices
        .where(
          (d) => d.isPrinter && d.isDiscovered && d.discoveredDevice != null,
        ) // Must be discovered device
        .toList();

    final pairedDevices = devices
        .where(
          (d) =>
              !d.isDiscovered &&
              d.device != null && // Must have OS paired device
              d.discoveredDevice == null,
        ) // Must NOT have discovered device
        .toList();

    final otherDevices = devices
        .where(
          (d) => !d.isPrinter && d.isDiscovered && d.discoveredDevice != null,
        ) // Must be discovered device
        .toList();

    debugPrint('  Confirmed Printers: ${confirmedPrinters.length}');
    debugPrint('  Paired Devices: ${pairedDevices.length}');
    debugPrint('  Other Devices: ${otherDevices.length}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel(label: "Available Printers"),
            if (_isScanning)
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.2).animate(_pulseController),
                child: const Text(
                  "Scanning...",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _isBluetoothEnabled && _hasPermissions
                    ? _scanForDevices
                    : null,
                child: Text(
                  "Refresh",
                  style: TextStyle(
                    color: _isBluetoothEnabled && _hasPermissions
                        ? AppColors.primary
                        : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        if (!_hasPermissions)
          _buildEmptyState(
            Icons.bluetooth_disabled_rounded,
            "Enable Bluetooth permissions to find devices",
          )
        else if (!_isBluetoothEnabled)
          _buildEmptyState(Icons.bluetooth_disabled, "Bluetooth is disabled")
        else if (devices.isEmpty && !_isScanning)
          _buildEmptyState(
            Icons.search_off_rounded,
            "No printers found\nTap Refresh to scan",
          )
        else if (devices.isEmpty && _isScanning)
          _buildEmptyState(Icons.search_rounded, "Searching for printers...")
        else ...[
          // Section 1: Confirmed Printer Devices (from BLE scan)
          if (confirmedPrinters.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Detected Printers (BLE)",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            ...confirmedPrinters.map((device) => _buildPrinterTile(device)),
          ],

          // Section 2: Paired Devices
          if (pairedDevices.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                "Paired Devices (OS)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ...pairedDevices.map((device) => _buildPrinterTile(device)),
          ],

          // Section 3: Other Discovered Devices (with warning)
          if (otherDevices.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.info_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    "Other Devices",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                "These devices are not identified as printers. Connection may not work correctly.",
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
            ...otherDevices.map((device) => _buildPrinterTile(device)),
          ],
        ],
      ],
    );
  }

  Widget _buildPrinterTile(PrinterDevice printer) {
    final bool isSelected = _selectedPrinterName == printer.name;
    final bool isConnected = printer.isConnected;
    final bool isDiscovered = printer.isDiscovered;
    final bool isPrinter = printer.isPrinter;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.08),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => _connectToPrinter(printer),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isConnected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.print_rounded,
            color: isConnected ? AppColors.primary : AppColors.secondary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                printer.name ?? "Thermal Printer",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            if (isPrinter && isDiscovered)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Printer",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConnected
                  ? "Connected"
                  : (isDiscovered
                        ? "Discovered • Tap to pair"
                        : "Paired • Tap to connect"),
              style: TextStyle(
                fontSize: 12,
                color: isConnected ? AppColors.primary : Colors.grey,
              ),
            ),
            if (printer.address != null)
              Text(
                printer.address ?? "",
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            if (printer.rssi != null && printer.rssi! != 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Signal: ${printer.rssi} dBm",
                  style: TextStyle(
                    fontSize: 9,
                    color: _getSignalQualityColor(printer.rssi!),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        trailing: isConnected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
            : (isSelected && _isConnecting)
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ),
    );
  }

  /// Determine signal quality color based on RSSI value
  /// RSSI values range from 0 to -120 dBm
  /// Higher (less negative) is stronger
  Color _getSignalQualityColor(int rssi) {
    if (rssi >= -50) return Colors.green; // Excellent
    if (rssi >= -60) return Colors.lightGreen; // Good
    if (rssi >= -70) return Colors.orange; // Fair
    return Colors.red; // Poor
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: "Printer Configurations"),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
          ),
          child: const Column(
            children: [
              _SettingTile(label: "Paper Size", value: "58mm / 80mm"),
              Divider(height: 1, indent: 20),
              _SettingTile(label: "Character Set", value: "UTF-8"),
              Divider(height: 1, indent: 20),
              _SettingTile(label: "Auto-cut", value: "Enabled"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.shade300, size: 40),
          const SizedBox(height: 12),
          Text(
            msg,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionArea() {
    final bool isConnected = _connectedPrinterName != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isConnected ? () => _printerService.disconnect() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isConnected ? Colors.red.shade50 : null,
            foregroundColor: isConnected ? Colors.red : null,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: isConnected
                ? const BorderSide(color: Colors.red, width: 1)
                : null,
          ),
          child: Text(
            isConnected ? "Disconnect Device" : "Select a Printer Above",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String label, value;
  const _SettingTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.secondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
