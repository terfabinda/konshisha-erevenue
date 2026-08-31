import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/services/security_config_service.dart';

class SyncStatusWidget extends StatefulWidget {
  final double? fontSize;
  final bool compact;

  const SyncStatusWidget({super.key, this.fontSize, this.compact = false});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  bool _isOnline = false;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _startListener();
  }

  Future<void> _checkStatus() async {
    final online = await SecurityConfigService.isOnline();
    final blocked = await SecurityConfigService.isBlocked();
    if (mounted) {
      setState(() {
        _isOnline = online;
        _isBlocked = blocked;
      });
    }
  }

  void _startListener() {
    Connectivity().onConnectivityChanged.listen((results) {
      final result = results.first;
      final online = result != ConnectivityResult.none;
      if (mounted) {
        setState(() => _isOnline = online);
        if (online) {
          SecurityConfigService.syncNow();
        }
      }
    });

    SecurityConfigService.onForceSyncChanged((active) {
      if (mounted) {
        setState(() => _isBlocked = active);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact();
    }
    return _buildFull();
  }

  Widget _buildCompact() {
    if (_isBlocked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync_disabled, size: 14, color: Colors.orange.shade300),
          const SizedBox(width: 4),
          Text(
            'Blocked',
            style: TextStyle(
              fontSize: widget.fontSize ?? 12,
              color: Colors.orange.shade300,
            ),
          ),
        ],
      );
    }
    if (!_isOnline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 14, color: Colors.red.shade300),
          const SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(
              fontSize: widget.fontSize ?? 12,
              color: Colors.red.shade300,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_done, size: 14, color: Colors.green.shade300),
        const SizedBox(width: 4),
        Text(
          'Synced',
          style: TextStyle(
            fontSize: widget.fontSize ?? 12,
            color: Colors.green.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildFull() {
    Color iconColor;
    Color textColor;
    String label;
    IconData icon;

    if (_isBlocked) {
      icon = Icons.sync_disabled;
      label = 'Sync Blocked';
      iconColor = Colors.orange.shade300;
      textColor = Colors.orange.shade300;
    } else if (!_isOnline) {
      icon = Icons.cloud_off;
      label = 'Offline Mode';
      iconColor = Colors.red.shade300;
      textColor = Colors.red.shade300;
    } else {
      icon = Icons.cloud_done;
      label = 'Synced';
      iconColor = Colors.green.shade300;
      textColor = Colors.green.shade300;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: widget.fontSize ?? 12,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
