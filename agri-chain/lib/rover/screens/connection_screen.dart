import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/rover_model.dart';
import '../providers/rover_provider.dart';
import '../widgets/connection_card.dart';
import '../../screens/rover/field_map_screen.dart';

class RoverConnectionScreen extends StatefulWidget {
  const RoverConnectionScreen({super.key});

  @override
  State<RoverConnectionScreen> createState() => _RoverConnectionScreenState();
}

class _RoverConnectionScreenState extends State<RoverConnectionScreen> {
  final TextEditingController _ipController = TextEditingController();
  List<BluetoothDevice> _bluetoothDevices = [];
  bool _isScanning = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadSavedIP();
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
  }

  Future<void> _loadSavedIP() async {
    final provider = Provider.of<RoverProvider>(context, listen: false);
    _ipController.text = provider.wifiIP;
  }

  Future<void> _scanBluetooth() async {
    setState(() => _isScanning = true);

    final provider = Provider.of<RoverProvider>(context, listen: false);
    _bluetoothDevices = await provider.scanBluetoothDevices();

    setState(() => _isScanning = false);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RoverProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Rover'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white24,
            height: 1,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.80),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (provider.isConnected) _buildConnectedCard(provider),
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    _buildTabButton('WiFi', 0),
                    _buildTabButton('Bluetooth', 1),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildWiFiTab(provider),
                    _buildBluetoothTab(provider),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _selectedIndex == index
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _selectedIndex == index ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedCard(RoverProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connected',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  provider.connectionMessage,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: provider.disconnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildWiFiTab(RoverProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ConnectionCard(
            icon: Icons.wifi,
            title: 'WiFi Connection',
            subtitle: 'Connect to ESP32 rover access point',
            children: [
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.router),
                  suffixText: ':80',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: provider.isConnecting
                      ? null
                      : () async {
                          provider.setWifiIP(_ipController.text);
                          final connected = await provider.connectWiFi();

                          if (!mounted) return;
                          if (connected) {
                            _showSuccessDialog('WiFi Connected');
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RoverControlScreen(),
                              ),
                            );
                          } else {
                            _showErrorDialog('Connection Failed');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: provider.isConnecting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Connect via WiFi',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConnectionCard(
            icon: Icons.info_outline,
            title: 'Connection Steps',
            subtitle: 'How to connect via WiFi',
            children: [
              _buildStep(1, 'Connect phone to rover WiFi network'),
              _buildStep(2, 'Enter IP (default: 192.168.4.1)'),
              _buildStep(3, 'Tap "Connect via WiFi"'),
              _buildStep(4, 'Wait for connection confirmation'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab(RoverProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ConnectionCard(
            icon: Icons.bluetooth,
            title: 'Bluetooth Connection',
            subtitle: 'Connect to your paired ESP32 rover device',
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _scanBluetooth,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isScanning
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Scan for Devices',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
          if (_bluetoothDevices.isNotEmpty) ...[
            const SizedBox(height: 16),
            ConnectionCard(
              icon: Icons.devices,
              title: 'Paired Devices',
              subtitle: 'Select a device to connect',
              children: [
                ..._bluetoothDevices.map((device) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.bluetooth, color: Colors.blue),
                    ),
                    title: Text(device.name ?? 'Unknown Device'),
                    subtitle: Text(device.address),
                    trailing: provider.bluetoothDevice == device
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: provider.isConnecting
                        ? null
                        : () async {
                            final connected = await provider.connectBluetooth(device);
                            if (!mounted) return;
                            if (connected) {
                              _showSuccessDialog('Bluetooth Connected');
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RoverControlScreen(),
                                ),
                              );
                            } else {
                              _showErrorDialog('Connection Failed');
                            }
                          },
                  );
                }).toList(),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ConnectionCard(
            icon: Icons.info_outline,
            title: 'Connection Steps',
            subtitle: 'How to connect via Bluetooth',
            children: [
              _buildStep(1, 'Enable Bluetooth on your phone'),
              _buildStep(2, 'Pair with the rover (if not paired)'),
              _buildStep(3, 'Tap "Scan for Devices"'),
              _buildStep(4, 'Select your device from the list'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(Icons.error, color: Colors.red, size: 50),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class RoverControlScreen extends StatefulWidget {
  const RoverControlScreen({super.key});

  @override
  State<RoverControlScreen> createState() => _RoverControlScreenState();
}

class _RoverControlScreenState extends State<RoverControlScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  static const Duration _minPressDuration = Duration(milliseconds: 200);
  Timer? _stopTimer;
  DateTime? _pressStartedAt;

  bool _isLeftPressed = false;
  bool _isRightPressed = false;
  bool _isForwardPressed = false;
  bool _isBackwardPressed = false;
  bool _isRotateLeftPressed = false;
  bool _isRotateRightPressed = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _handlePressDown(RoverProvider provider, RoverCommand command, VoidCallback setPressedTrue) {
    _stopTimer?.cancel();
    _pressStartedAt = DateTime.now();
    provider.sendCommand(command);
    setState(setPressedTrue);
  }

  void _handlePressUp(RoverProvider provider, VoidCallback setPressedFalse) {
    setState(setPressedFalse);

    final startedAt = _pressStartedAt;
    final elapsed = startedAt == null ? Duration.zero : DateTime.now().difference(startedAt);
    final remaining = _minPressDuration - elapsed;
    final delay = remaining.isNegative ? Duration.zero : remaining;

    _stopTimer?.cancel();
    _stopTimer = Timer(delay, () {
      provider.sendCommand(RoverCommand.stop);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RoverProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rover Control'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Field Map',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FieldMapScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoverSettingsScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildStatusBar(provider),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: Column(
              children: [
                _buildSystemInfoCard(provider),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildDirectionDisplay(provider),
                          const SizedBox(height: 30),
                          _buildMainControls(provider),
                          const SizedBox(height: 30),
                          _buildRotationControls(provider),
                          const SizedBox(height: 30),
                          _buildEmergencyStop(provider),
                          const SizedBox(height: 20),
                          _buildConnectionInfo(provider),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(RoverProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: provider.isConnected
          ? provider.status.isMoving
              ? Colors.green
              : Theme.of(context).colorScheme.primary
          : Colors.red,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                provider.isConnected
                    ? provider.status.isMoving
                        ? Icons.directions_run
                        : Icons.check_circle
                    : Icons.error,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                provider.isConnected
                    ? provider.status.isMoving
                        ? 'MOVING'
                        : 'CONNECTED'
                    : 'DISCONNECTED',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.battery_charging_full,
                  color: Colors.white, size: 20),
              const SizedBox(width: 4),
              Text(
                '${provider.status.battery}%',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard(RoverProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInfoItem(Icons.speed, 'Speed', provider.status.speed.toString()),
            _buildInfoItem(
              Icons.timer,
              'Uptime',
              _formatUptime(provider.status.uptime),
            ),
            _buildInfoItem(
              Icons.people,
              'Clients',
              provider.status.clients.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionDisplay(RoverProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getDirectionIcon(provider.status.direction),
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          Text(
            provider.status.direction.toUpperCase(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDirectionIcon(String direction) {
    switch (direction) {
      case 'forward':
        return Icons.arrow_upward;
      case 'backward':
        return Icons.arrow_downward;
      case 'left':
        return Icons.arrow_back;
      case 'right':
        return Icons.arrow_forward;
      case 'rotate-left':
        return Icons.rotate_left;
      case 'rotate-right':
        return Icons.rotate_right;
      default:
        return Icons.stop;
    }
  }

  Widget _buildMainControls(RoverProvider provider) {
    return Column(
      children: [
        Center(
          child: _ControlButton(
            icon: Icons.arrow_upward,
            label: 'FORWARD',
            onTapDown: () => _handlePressDown(
              provider,
              RoverCommand.forward,
              () => _isForwardPressed = true,
            ),
            onTapUp: () => _handlePressUp(
              provider,
              () => _isForwardPressed = false,
            ),
            isPressed: _isForwardPressed,
            color: Colors.green,
            size: 80,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              icon: Icons.arrow_back,
              label: 'LEFT',
              onTapDown: () => _handlePressDown(
                provider,
                RoverCommand.left,
                () => _isLeftPressed = true,
              ),
              onTapUp: () => _handlePressUp(
                provider,
                () => _isLeftPressed = false,
              ),
              isPressed: _isLeftPressed,
              color: Colors.orange,
              size: 70,
            ),
            const SizedBox(width: 20),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stop,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(width: 20),
            _ControlButton(
              icon: Icons.arrow_forward,
              label: 'RIGHT',
              onTapDown: () => _handlePressDown(
                provider,
                RoverCommand.right,
                () => _isRightPressed = true,
              ),
              onTapUp: () => _handlePressUp(
                provider,
                () => _isRightPressed = false,
              ),
              isPressed: _isRightPressed,
              color: Colors.orange,
              size: 70,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: _ControlButton(
            icon: Icons.arrow_downward,
            label: 'BACKWARD',
            onTapDown: () => _handlePressDown(
              provider,
              RoverCommand.backward,
              () => _isBackwardPressed = true,
            ),
            onTapUp: () => _handlePressUp(
              provider,
              () => _isBackwardPressed = false,
            ),
            isPressed: _isBackwardPressed,
            color: Colors.red,
            size: 80,
          ),
        ),
      ],
    );
  }

  Widget _buildRotationControls(RoverProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: Icons.rotate_left,
          label: 'ROTATE L',
          onTapDown: () => _handlePressDown(
            provider,
            RoverCommand.rotateLeft,
            () => _isRotateLeftPressed = true,
          ),
          onTapUp: () => _handlePressUp(
            provider,
            () => _isRotateLeftPressed = false,
          ),
          isPressed: _isRotateLeftPressed,
          color: Colors.purple,
          size: 100,
        ),
        const SizedBox(width: 20),
        _ControlButton(
          icon: Icons.rotate_right,
          label: 'ROTATE R',
          onTapDown: () => _handlePressDown(
            provider,
            RoverCommand.rotateRight,
            () => _isRotateRightPressed = true,
          ),
          onTapUp: () => _handlePressUp(
            provider,
            () => _isRotateRightPressed = false,
          ),
          isPressed: _isRotateRightPressed,
          color: Colors.purple,
          size: 100,
        ),
      ],
    );
  }

  Widget _buildEmergencyStop(RoverProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          provider.emergencyStop();
          _resetButtonStates();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency Stop Activated'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 1),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          'EMERGENCY STOP',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionInfo(RoverProvider provider) {
    final icon = provider.connectionType == ConnectionType.wifi
        ? Icons.wifi
        : Icons.bluetooth;

    final label = provider.connectionType == ConnectionType.wifi
        ? provider.wifiIP
        : (provider.bluetoothDevice?.name ?? 'Bluetooth');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Source: ${provider.status.source}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _resetButtonStates() {
    setState(() {
      _isLeftPressed = false;
      _isRightPressed = false;
      _isForwardPressed = false;
      _isBackwardPressed = false;
      _isRotateLeftPressed = false;
      _isRotateRightPressed = false;
    });
  }

  String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final bool isPressed;
  final Color color;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTapDown,
    required this.onTapUp,
    required this.isPressed,
    required this.color,
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapUp(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPressed
                ? [color.withOpacity(0.8), color]
                : [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: isPressed ? 5 : 10,
              offset: Offset(0, isPressed ? 2 : 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: size * 0.4),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoverSettingsScreen extends StatefulWidget {
  const RoverSettingsScreen({super.key});

  @override
  State<RoverSettingsScreen> createState() => _RoverSettingsScreenState();
}

class _RoverSettingsScreenState extends State<RoverSettingsScreen> {
  late TextEditingController _ipController;
  int _speedValue = 255;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<RoverProvider>(context, listen: false);
    _ipController = TextEditingController(text: provider.wifiIP);
    _speedValue = provider.status.speed;
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RoverProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rover Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Connection Settings',
            Icons.settings_ethernet,
            [
              ListTile(
                title: const Text('WiFi IP Address'),
                subtitle: TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(hintText: '192.168.4.1'),
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    provider.setWifiIP(_ipController.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('IP Address Saved')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Control Settings',
            Icons.tune,
            [
              ListTile(
                title: const Text('Default Speed'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Speed: $_speedValue'),
                    Slider(
                      value: _speedValue.toDouble(),
                      min: 0,
                      max: 255,
                      divisions: 255,
                      onChanged: (value) {
                        setState(() {
                          _speedValue = value.toInt();
                        });
                      },
                      onChangeEnd: (value) {
                        provider.setSpeed(value.toInt());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'System Information',
            Icons.info,
            [
              if (provider.info != null) ...[
                _buildInfoRow('System', provider.info!.name),
                _buildInfoRow('Version', provider.info!.version),
                _buildInfoRow('Board', provider.info!.board),
                _buildInfoRow('Driver', provider.info!.driver),
                _buildInfoRow('WiFi SSID', provider.info!.wifiSSID),
                _buildInfoRow('WiFi IP', provider.info!.wifiIP),
                _buildInfoRow('Bluetooth', provider.info!.bluetooth),
              ],
              _buildInfoRow('Uptime', _formatUptime(provider.status.uptime)),
              _buildInfoRow('Clients', provider.status.clients.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }
}
