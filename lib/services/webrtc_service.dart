// lib/services/webrtc_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class WebRtcService extends ChangeNotifier {
  final Logger _logger = Logger();
  final String _whepUrl = 'https://aitools.ptit.edu.vn/rtc/v1/whep/?app=live&stream=livestream';
  final RTCVideoRenderer renderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;

  String _status = 'Disconnected';
  String get status => _status;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isConnected {
    return status == 'Connected' || status == 'Completed';
  }

  WebRtcService() {
    _initializeRenderer();
  }

  Future<void> _initializeRenderer() async {
    await renderer.initialize();
  }

  Future<void> connect() async {
    if (_isLoading || _peerConnection != null) return;

    _isLoading = true;
    _errorMessage = null;
    _status = 'Connecting...';
    notifyListeners();

    _logger.i("Starting WHEP connection...");

    try {
      _peerConnection = await createPeerConnection({'iceServers': []}, {});
      _setupPeerConnectionListeners();

      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      final response = await http.post(
        Uri.parse(_whepUrl),
        headers: {'Content-Type': 'application/sdp'},
        body: offer.sdp,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final answer = RTCSessionDescription(response.body, 'answer');
        await _peerConnection!.setRemoteDescription(answer);
        _logger.i("Remote description set successfully!");
      } else {
        throw Exception('Server responded with status ${response.statusCode}');
      }
    } catch (e, s) {
      _logger.e("Error during WHEP connection", error: e, stackTrace: s);
      _errorMessage = e.toString();
      _status = 'Error';
      await disconnect();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_status == 'Disconnecting...') return;

    _logger.i("Disconnecting...");
    _status = 'Disconnecting...';
    _isLoading = true;
    notifyListeners();

    try {
      // ▼▼▼ LỖI 1 ĐÃ SỬA ▼▼▼
      // Sử dụng Future.wait để dừng tất cả các track
      if (_remoteStream != null) {
        await Future.wait(_remoteStream!.getTracks().map((track) => track.stop()));
      }
      // ▲▲▲ LỖI 1 ĐÃ SỬA ▲▲▲

      await _remoteStream?.dispose();
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (e) {
      _logger.e("Error during disconnection steps", error: e);
    } finally {
      _peerConnection = null;
      _remoteStream = null;
      if (renderer.srcObject != null) {
        renderer.srcObject = null;
      }
      _status = 'Disconnected';
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setupPeerConnectionListeners() {
    // Thêm `async` vào hàm callback
    _peerConnection!.onTrack = (RTCTrackEvent event) async {
      _logger.i("Track received: ${event.track.kind}");
      if (event.track.kind == 'video' || event.track.kind == 'audio') {

        // ▼▼▼ LỖI 2 ĐÃ SỬA ▼▼▼
        // Sử dụng factory method `createLocalMediaStream`
        _remoteStream ??= await createLocalMediaStream('remoteStream_${DateTime.now().millisecondsSinceEpoch}');
        // ▲▲▲ LỖI 2 ĐÃ SỬA ▲▲▲

        _remoteStream!.addTrack(event.track);
        renderer.srcObject = _remoteStream;
        notifyListeners();
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      _logger.i('ICE connection state: $state');
      // Cập nhật status một cách an toàn hơn
      final newStatus = state.toString().split('.').last;
      if(_status != newStatus){
        _status = newStatus;
        notifyListeners();
      }
    };

    _peerConnection!.onConnectionState = (state) {
      _logger.i('Peer connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        disconnect();
      }
    };
  }

  @override
  void dispose() {
    renderer.dispose();
    disconnect();
    super.dispose();
  }
}