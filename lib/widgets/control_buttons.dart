import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/GlassmorphicToggle.dart';

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

  Widget _buildGlassButton({
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final bool isDisabled = onPressed == null;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: GlassmorphicContainer(
        borderRadius: 30,
        blurSigma: 12,
        isPerformanceMode: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: isDisabled ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
          _buildGlassButton(
            icon: isLoading && !isConnected
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded, color: Colors.white),
            label: 'Bắt đầu',
            onPressed: (isLoading || isConnected) ? null : onConnect,
          ),
          const SizedBox(width: 16),
          _buildGlassButton(
            icon: const Icon(Icons.stop_rounded, color: Colors.white),
            label: 'Dừng',
            onPressed: (isLoading || !isConnected) ? null : onDisconnect,
          ),
        ],
      ),
    );
  }
}
