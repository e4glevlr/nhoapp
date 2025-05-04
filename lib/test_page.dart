import 'package:flutter/material.dart';
import 'dart:convert'; // Cần cho JSON (mặc dù không dùng trực tiếp ở đây nhưng cần cho http response)
import 'dart:async'; // Cần cho Future
import 'package:flutter_webrtc/flutter_webrtc.dart'; // Dependency chính cho WebRTC
import 'package:http/http.dart' as http; // Dependency cho HTTP POST (WHEP)
import 'package:logger/logger.dart'; // Dependency tùy chọn để logging

// Chuyển thành StatefulWidget
class TestPage extends StatefulWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  State<TestPage> createState() => _TestPageState();
}

// Tạo State class tương ứng
class _TestPageState extends State<TestPage> {
  // --- Sao chép các biến trạng thái từ WhepPlayerPage ---
  final Logger _logger = Logger(); // Tùy chọn
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;
  bool _isLoading = false;
  String? _errorMessage;
  String _status = 'Disconnected';

  // !!! THAY THẾ ĐỊA CHỈ SERVER SRS CỦA BẠN VÀO ĐÂY !!!
  final String _whepUrl =
      'https://aitools.ptit.edu.vn/rtc/v1/whep/?app=live&stream=livestream';
  // ----------------------------------------------------

  // --- Sao chép các phương thức cần thiết ---
  @override
  void initState() {
    super.initState(); // Quan trọng: gọi super.initState() trước
    _initializeRenderer();
  }

  Future<void> _initializeRenderer() async {
    await _renderer.initialize();
  }

  @override
  void dispose() {
    _logger.i("Disposing TestPage...");
    _renderer.dispose();
    _remoteStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.dispose();
    _peerConnection?.close();
    _peerConnection?.dispose();
    super.dispose(); // Quan trọng: gọi super.dispose() sau cùng
  }

  // Hàm kết nối WHEP (giống hệt WhepPlayerPage)
  Future<void> _connect() async {
    if (_isLoading || _peerConnection != null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _status = 'Connecting...';
    });
    _logger.i("Starting WHEP connection to: $_whepUrl");

    try {
      _peerConnection = await createPeerConnection({
        'iceServers': [
          // {'urls': 'stun:stun.l.google.com:19302'},
        ],
      }, {});

      _remoteStream = await createLocalMediaStream('remoteStream');
      setState(() {
        _renderer.srcObject = _remoteStream;
      });

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        _logger.i(
          "Track received: kind=${event.track.kind}, id=${event.track.id}",
        );
        if (event.streams.isEmpty) {
          _logger.w(
            "Received track has no streams associated, adding manually.",
          );
          _remoteStream?.addTrack(event.track);
        } else {
          if (_remoteStream == null) {
            _remoteStream = event.streams[0];
          } else {
            event.streams[0].getTracks().forEach((track) {
              _remoteStream?.addTrack(track);
            });
          }
        }
        setState(() {
          _renderer.srcObject = _remoteStream;
        });

        event.track.onMute = () => _logger.w("Track muted: ${event.track.id}");
        event.track.onUnMute = () {
          _logger.i("Track unmuted: ${event.track.id}");
          setState(() {
            _renderer.srcObject = _remoteStream;
          });
        };
        event.track.onEnded = () => _logger.w("Track ended: ${event.track.id}");
      };

      _peerConnection!.onIceCandidate =
          (RTCIceCandidate candidate) =>
              _logger.i('Got ICE candidate: ${candidate.candidate}');

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        _logger.i('ICE connection state changed: $state');
        setStateIfNotDisposed(() {
          _status = state.toString().split('.').last;
        });
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          _logger.e('ICE Connection failed or closed: $state');
          _disconnect();
          setStateIfNotDisposed(() {
            _errorMessage = 'ICE Connection failed: $state';
          });
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        _logger.i('Peer connection state changed: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _logger.e('Peer Connection failed');
          _disconnect();
          setStateIfNotDisposed(() {
            _errorMessage = 'Peer Connection failed';
          });
        }
      };

      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final offer = await _peerConnection!.createOffer();
      _logger.d("Created Offer:\n${offer.sdp}");
      await _peerConnection!.setLocalDescription(offer);
      _logger.i("Local description set");

      _logger.i("Sending Offer SDP via HTTP POST to $_whepUrl");
      final response = await http.post(
        Uri.parse(_whepUrl),
        headers: {'Content-Type': 'application/sdp'},
        body: offer.sdp,
      );

      _logger.i("Received WHEP response: Status=${response.statusCode}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final answerSdp = response.body;
        _logger.d("Received Answer SDP:\n$answerSdp");
        final answer = RTCSessionDescription(answerSdp, 'answer');
        await _peerConnection!.setRemoteDescription(answer);
        _logger.i("Remote description set successfully!");
        // Không set _status = 'Connected' ở đây ngay, chờ ICE connected
      } else {
        _logger.e(
          "WHEP request failed: ${response.statusCode}\nBody: ${response.body}",
        );
        throw Exception(
          'WHEP request failed (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e, s) {
      _logger.e("Error during WHEP connection", error: e, stackTrace: s);
      setStateIfNotDisposed(() {
        _errorMessage = "Connection Error: ${e.toString()}";
        _status = 'Error';
      });
      await _disconnect();
    } finally {
      setStateIfNotDisposed(() {
        _isLoading = false;
      });
    }
  }

  // Hàm ngắt kết nối (giống hệt WhepPlayerPage)
  Future<void> _disconnect() async {
    _logger.i("Disconnecting...");
    setStateIfNotDisposed(() {
      _isLoading = false;
      _status = 'Disconnecting...';
    });
    try {
      // SỬA LỖI Ở ĐÂY: Dùng vòng lặp for...in thay vì forEach
      if (_remoteStream != null) {
        // Lấy danh sách các track trước
        List<MediaStreamTrack> tracks = _remoteStream!.getTracks();
        _logger.i("Stopping ${tracks.length} track(s)...");
        // Lặp qua danh sách và await từng track.stop()
        for (var track in tracks) {
          _logger.i("Stopping track: ${track.id} (${track.kind})");
          try {
            await track.stop(); // await từng cái một
            _logger.i("Track ${track.id} stopped.");
          } catch (e) {
            // Ghi log nếu có lỗi dừng track cụ thể nhưng vẫn tiếp tục
            _logger.w("Error stopping track ${track.id}: $e");
          }
        }
      }
      // await _remoteStream?.getTracks().forEach((track) async { // Dòng cũ bị lỗi
      //   await track.stop();
      // });

      await _remoteStream?.dispose();
      _remoteStream = null;

      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;

      // Đảm bảo renderer được reset
      if (mounted) {
        // Kiểm tra mounted trước khi truy cập _renderer
        _renderer.srcObject = null;
      }

      _logger.i("Disconnected successfully.");
    } catch (e, s) {
      _logger.e("Error during disconnection", error: e, stackTrace: s);
    } finally {
      setStateIfNotDisposed(() {
        _status = 'Disconnected';
        _isLoading = false;
        _errorMessage = null; // Xóa lỗi cũ khi ngắt kết nối
      });
    }
  }

  // Hàm helper để tránh gọi setState khi widget đã bị dispose
  void setStateIfNotDisposed(Function() fn) {
    if (mounted) {
      setState(fn);
    }
  }
  // --- Kết thúc sao chép phương thức ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Test Page with Stream"),
      ), // Cập nhật tiêu đề
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          // Sử dụng Column để sắp xếp các thành phần
          children: [
            // Vùng hiển thị video (chiếm phần lớn không gian)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                ), // Nền đen cho video
                child: RTCVideoView(
                  _renderer,
                  mirror: false, // Thường không cần mirror khi xem
                  objectFit:
                      RTCVideoViewObjectFit
                          .RTCVideoViewObjectFitContain, // Hiển thị vừa vặn
                ),
              ),
            ),
            const SizedBox(height: 10), // Khoảng cách
            // Hiển thị trạng thái
            Text('Status: $_status'),

            // Hiển thị lỗi nếu có
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 10), // Khoảng cách
            // Hàng chứa các nút điều khiển
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  // Vô hiệu hóa nút khi đang tải hoặc đã kết nối
                  onPressed: _isLoading ? null : _connect,
                  child:
                      _isLoading && _status.contains('Connecting')
                          ? const SizedBox(
                            // Hiển thị vòng xoay khi đang loading
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Start Play'),
                ),
                const SizedBox(width: 20), // Khoảng cách giữa các nút
                ElevatedButton(
                  // Chỉ bật nút Stop khi đang không loading VÀ đã có kết nối
                  onPressed:
                      (_isLoading || _peerConnection == null)
                          ? null
                          : _disconnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ), // Màu đỏ cho nút Stop
                  child: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
