import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ControlButtons extends StatelessWidget {
  final bool isLoading;
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const ControlButtons({
    Key? key,
    required this.isLoading,
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
  }) : super(key: key);

  Widget _buildButton({
    required Widget icon, // đổi từ Icon → Widget
    required String label,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return ElevatedButton.icon(
      icon: icon,
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: foregroundColor),
      ),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildButton(
            icon: isLoading && !isConnected
                ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF06203a)),
              ),
            )
                : const Icon(Icons.play_arrow_rounded, color: Color(0xFF06203a)),
            label: 'Bắt đầu',
            onPressed: (isLoading || isConnected) ? null : onConnect,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF06203a),
          ),
          const SizedBox(width: 20),
          _buildButton(
            icon: const Icon(Icons.stop_rounded),
            label: 'Dừng',
            onPressed: (isLoading || !isConnected) ? null : onDisconnect,
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
