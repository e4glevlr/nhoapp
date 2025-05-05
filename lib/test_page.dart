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

  // --- Biến trạng thái cho giao diện Chat ---
  final TextEditingController _chatController = TextEditingController();
  final List<String> _messages = [
    "Chào mừng đến với buổi stream!",
    "Đây là khung chat mẫu.",
    "Bạn có thể gửi tin nhắn ở đây (chức năng chưa được cài đặt).",
  ]; // Danh sách tin nhắn mẫu

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
    _remoteStream?.getTracks().forEach(
      (track) => track.stop(),
    ); // Dùng forEach ở đây vẫn ổn vì không cần await
    _remoteStream?.dispose();
    _peerConnection?.close();
    _peerConnection?.dispose();
    _chatController.dispose(); // Quan trọng: dispose chat controller
    super.dispose(); // Quan trọng: gọi super.dispose() sau cùng
  }

  // Hàm kết nối WHEP (giống hệt WhepPlayerPage, chỉ thay đổi log và setState)
  Future<void> _connect() async {
    if (_isLoading || _peerConnection != null) return;

    setStateIfNotDisposed(() {
      _isLoading = true;
      _errorMessage = null;
      _status = 'Connecting...';
    });
    _logger.i("Starting WHEP connection to: $_whepUrl");

    try {
      _peerConnection = await createPeerConnection({
        'iceServers': [
          // {'urls': 'stun:stun.l.google.com:19302'}, // Có thể thêm STUN server nếu cần
        ],
        'sdpSemantics': 'unified-plan', // Thường là mặc định nhưng thêm cho rõ
      }, {});

      _remoteStream = await createLocalMediaStream(
        'remoteStream-${DateTime.now().millisecondsSinceEpoch}',
      ); // Tên stream duy nhất
      setStateIfNotDisposed(() {
        _renderer.srcObject = _remoteStream;
      });

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        _logger.i(
          "Track received: kind=${event.track.kind}, id=${event.track.id}",
        );
        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          _logger.i(
            "--> Received ${event.track.kind?.toUpperCase()} track: ${event.track.id}",
          );
          // Flutter WebRTC tự động thêm track vào stream liên kết với transceiver
          // Nhưng để chắc chắn, chúng ta sẽ thêm vào _remoteStream nếu cần
          if (_remoteStream != null &&
              !_remoteStream!.getTracks().any((t) => t.id == event.track.id)) {
            _logger.i(
              "Manually adding track ${event.track.id} to _remoteStream",
            );
            _remoteStream?.addTrack(event.track);
          }
        }

        // Quan trọng: cập nhật renderer khi track sẵn sàng hoặc unmute
        event.track.onUnMute = () {
          _logger.i("Track unmuted: ${event.track.id}");
          if (mounted && _remoteStream != null) {
            setState(() {
              // Cần gọi setState để cập nhật UI, ngay cả khi srcObject không thay đổi tham chiếu
              _renderer.srcObject = _remoteStream;
            });
          }
        };

        event.track.onEnded = () {
          _logger.w("Track ended: ${event.track.id}");
          if (_remoteStream != null) {
            _remoteStream!.removeTrack(event.track);
            if (mounted) {
              setState(() {
                _renderer.srcObject = _remoteStream;
              });
            }
          }
        };
        event.track.onMute = () => _logger.w("Track muted: ${event.track.id}");

        // Thử cập nhật renderer ngay khi có track
        if (mounted && _remoteStream != null) {
          setState(() {
            _renderer.srcObject = _remoteStream;
          });
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          _logger.i(
            'Got ICE candidate: ${candidate.candidate!.substring(0, 20)}...',
          ); // Log ngắn gọn
          // Việc gửi ICE candidate thường không cần thiết với WHEP (server gửi ICE của nó trong answer)
          // Nếu server yêu cầu trickle ICE thì mới cần gửi candidate qua endpoint riêng (không phải WHEP)
        } else {
          _logger.i('End of ICE candidates.');
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        _logger.i('ICE connection state changed: $state');
        setStateIfNotDisposed(() {
          // Cập nhật trạng thái dựa trên ICE state
          switch (state) {
            case RTCIceConnectionState.RTCIceConnectionStateChecking:
              _status = 'Checking...';
              break;
            case RTCIceConnectionState.RTCIceConnectionStateConnected:
            case RTCIceConnectionState.RTCIceConnectionStateCompleted:
              _status = 'Connected';
              _errorMessage = null; // Xóa lỗi cũ khi kết nối thành công
              break;
            case RTCIceConnectionState.RTCIceConnectionStateFailed:
              _status = 'Failed';
              _errorMessage = 'ICE Connection Failed.';
              _disconnect(); // Tự động ngắt kết nối khi ICE fail
              break;
            case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
              _status = 'Disconnected';
              // Có thể là tạm thời, không nên tự động ngắt ngay
              break;
            case RTCIceConnectionState.RTCIceConnectionStateClosed:
              _status = 'Closed';
              break;
            default:
              _status = state.toString().split('.').last;
              break;
          }
        });
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        _logger.i('Peer connection state changed: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          _logger.e('Peer Connection failed');
          _disconnect();
          setStateIfNotDisposed(() {
            _status = 'Failed';
            _errorMessage = 'Peer Connection failed';
          });
        }
      };

      // WHEP chỉ cần nhận, không cần gửi
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
      // Không log toàn bộ offer/answer trong production để tránh quá nhiều log
      await _peerConnection!.setLocalDescription(offer);
      _logger.i("Local description set");

      _logger.i("Sending Offer SDP via HTTP POST to $_whepUrl");
      final response = await http
          .post(
            Uri.parse(_whepUrl),
            headers: {'Content-Type': 'application/sdp'},
            body: offer.sdp,
          )
          .timeout(const Duration(seconds: 10)); // Thêm timeout

      _logger.i("Received WHEP response: Status=${response.statusCode}");
      // Log Headers để debug CORS hoặc Location
      // response.headers.forEach((key, value) {
      //   _logger.d("Header: $key = $value");
      // });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final answerSdp = response.body;
        _logger.i("Received Answer SDP (length: ${answerSdp.length})");
        _logger.d("Answer SDP:\n$answerSdp"); // Log answer để debug
        final answer = RTCSessionDescription(answerSdp, 'answer');
        await _peerConnection!.setRemoteDescription(answer);
        _logger.i("Remote description set successfully!");
        // Trạng thái sẽ chuyển thành 'Connected' khi ICE thành công
      } else {
        final errorBody =
            response.body.length > 200
                ? '${response.body.substring(0, 200)}...'
                : response.body;
        _logger.e(
          "WHEP request failed: ${response.statusCode}\nBody: $errorBody",
        );
        // Cung cấp thông báo lỗi rõ ràng hơn
        String detailedError =
            'Server responded with status ${response.statusCode}.';
        if (response.body.isNotEmpty) {
          detailedError += ' Body: $errorBody';
        }
        if (response.statusCode == 404) {
          detailedError += ' (Stream or App not found?)';
        } else if (response.statusCode >= 500) {
          detailedError += ' (Server error?)';
        }
        throw Exception(detailedError);
      }
    } catch (e, s) {
      _logger.e("Error during WHEP connection", error: e, stackTrace: s);
      setStateIfNotDisposed(() {
        // Hiển thị lỗi cụ thể hơn nếu có thể
        _errorMessage =
            e is TimeoutException
                ? "Connection timed out."
                : "Connection Error: ${e.toString()}";
        _status = 'Error';
      });
      await _disconnect(); // Đảm bảo cleanup khi có lỗi
    } finally {
      // Chỉ set isLoading = false nếu widget chưa bị dispose
      setStateIfNotDisposed(() {
        _isLoading = false;
        // Nếu trạng thái vẫn là 'Connecting...' sau khi kết thúc mà không có lỗi,
        // có thể đặt thành 'Waiting for ICE' hoặc tương tự.
        if (_status == 'Connecting...' && _errorMessage == null) {
          _status = 'Negotiating...';
        }
      });
    }
  }

  // Hàm ngắt kết nối (Sử dụng vòng lặp for để await từng track.stop())
  Future<void> _disconnect() async {
    _logger.i("Disconnecting...");
    setStateIfNotDisposed(() {
      // Giữ _isLoading để ngăn nhấn nút Connect lại ngay lập tức
      // _isLoading = false; // Không reset ở đây vội
      _status = 'Disconnecting...';
    });

    // Lấy danh sách tracks trước khi stream bị dispose
    List<MediaStreamTrack> tracksToStop = [];
    if (_remoteStream != null) {
      tracksToStop.addAll(_remoteStream!.getTracks());
    }

    try {
      // Dừng các tracks
      if (tracksToStop.isNotEmpty) {
        _logger.i("Stopping ${tracksToStop.length} track(s)...");
        for (var track in tracksToStop) {
          _logger.i("Stopping track: ${track.id} (${track.kind})");
          try {
            await track.stop();
            _logger.i("Track ${track.id} stopped.");
          } catch (e) {
            _logger.w("Error stopping track ${track.id}: $e");
          }
        }
      }

      // Dispose stream
      if (_remoteStream != null) {
        await _remoteStream!.dispose();
        _remoteStream = null;
        _logger.i("Remote stream disposed.");
      }

      // Đóng và dispose peer connection
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _logger.i("Peer connection closed.");
        await _peerConnection!.dispose();
        _peerConnection = null;
        _logger.i("Peer connection disposed.");
      }

      // Reset renderer cuối cùng, kiểm tra mounted
      if (mounted) {
        _renderer.srcObject = null;
        _logger.i("Renderer srcObject set to null.");
      }

      _logger.i("Disconnected successfully.");
    } catch (e, s) {
      _logger.e("Error during disconnection", error: e, stackTrace: s);
      // Đặt lại trạng thái lỗi nếu cần
      // setStateIfNotDisposed(() { _errorMessage = "Disconnection error: $e"; });
    } finally {
      // Reset trạng thái cuối cùng, bất kể lỗi hay không
      setStateIfNotDisposed(() {
        _status = 'Disconnected';
        _isLoading = false; // Reset loading indicator
        _errorMessage = null; // Xóa lỗi khi ngắt kết nối thành công hoặc cố ý
      });
    }
  }

  // Hàm helper để tránh gọi setState khi widget đã bị dispose
  void setStateIfNotDisposed(Function() fn) {
    if (mounted) {
      setState(fn);
    } else {
      _logger.w("Tried to call setState on a disposed widget.");
    }
  }

  // Hàm xử lý gửi tin nhắn (chưa có logic thực tế)
  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      setStateIfNotDisposed(() {
        _messages.add(
          "You: $text",
        ); // Thêm tin nhắn của bạn vào danh sách (giả lập)
        _chatController.clear();
        // Trong ứng dụng thực tế, bạn sẽ gửi tin nhắn này qua WebSocket hoặc một kênh khác
        _logger.i("Chat message entered: $text");
      });
      // Tự cuộn xuống cuối (ví dụ)
      // _scrollController.animateTo(...)
    }
  }

  // Hàm xử lý khi nhấn nút micro (chưa có logic thực tế)
  void _handleMicTap() {
    _logger.i("Microphone icon tapped!");
    // Thêm logic bật/tắt micro hoặc xử lý khác ở đây
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Microphone action triggered (placeholder)."),
        duration: Duration(seconds: 2),
      ),
    );
  }
  // --- Kết thúc sao chép/thêm phương thức ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Video Stream & Chat"), // Cập nhật tiêu đề
        backgroundColor: Colors.blueGrey[800],
      ),
      // Sử dụng SafeArea để tránh các phần giao diện bị che khuất (tai thỏ, thanh điều hướng)
      body: SafeArea(
        child: Column(
          children: [
            // --- Phần trên: Video Stream ---
            Expanded(
              flex: 3, // Cho video nhiều không gian hơn chat (tỷ lệ 3:2)
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blueGrey, // Màu khung
                      width: 2.0, // Độ dày khung
                    ),
                    borderRadius: BorderRadius.circular(12.0), // Bo góc khung
                    color: Colors.black, // Nền đen cho vùng video
                  ),
                  child: ClipRRect(
                    // Cắt nội dung theo góc bo của Container
                    borderRadius: BorderRadius.circular(
                      10.0,
                    ), // Phải nhỏ hơn Container's radius một chút
                    child: Stack(
                      // Stack để hiển thị loading/status trên video
                      alignment: Alignment.center,
                      children: [
                        // Video View
                        RTCVideoView(
                          _renderer,
                          mirror: false,
                          objectFit:
                              RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitContain,
                        ),
                        // Loading Indicator
                        if (_isLoading && _status.contains('Connecting'))
                          const CircularProgressIndicator(),
                        // Status Text Overlay (hiển thị khi không connecting và không connected)
                        if (!_isLoading &&
                            _status != 'Connected' &&
                            _status != 'Checking...' &&
                            _status != 'Negotiating...')
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Status: $_status${_errorMessage != null ? '\nError: $_errorMessage' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- Hàng điều khiển ---
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 5.0,
                horizontal: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon:
                        _isLoading && _status.contains('Connecting')
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.play_arrow),
                    label: const Text('Start Play'),
                    onPressed:
                        (_isLoading || _peerConnection != null)
                            ? null
                            : _connect,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green[700], // Text/icon color
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed:
                        (_isLoading || _peerConnection == null)
                            ? null
                            : _disconnect,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),

            // --- Phần dưới: Chat ---
            Expanded(
              flex: 2, // Cho chat ít không gian hơn video (tỷ lệ 3:2)
              child: Container(
                margin: const EdgeInsets.only(
                  left: 8.0,
                  right: 8.0,
                  bottom: 8.0,
                  top: 0,
                ), // Margin thay vì Padding để tách biệt rõ hơn
                decoration: BoxDecoration(
                  color: Colors.grey[200], // Nền nhạt cho khung chat
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    // Thêm đổ bóng nhẹ
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Khu vực hiển thị tin nhắn
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(10.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final isUserMessage = _messages[index].startsWith(
                            "You:",
                          );
                          return Align(
                            alignment:
                                isUserMessage
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isUserMessage
                                        ? Colors.blue[300]
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(15.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                _messages[index],
                                style: TextStyle(
                                  color:
                                      isUserMessage
                                          ? Colors.white
                                          : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Đường kẻ phân cách
                    Divider(height: 1, color: Colors.grey[400]),
                    // Khu vực nhập tin nhắn
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              decoration: InputDecoration(
                                hintText: "Nhập tin nhắn...",
                                border: OutlineInputBorder(
                                  // Viền input field
                                  borderRadius: BorderRadius.circular(20.0),
                                  borderSide:
                                      BorderSide.none, // Bỏ viền mặc định
                                ),
                                filled: true, // Cho phép tô màu nền
                                fillColor: Colors.white, // Màu nền input
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15.0,
                                  vertical: 10.0,
                                ),
                              ),
                              onSubmitted:
                                  (_) =>
                                      _sendMessage(), // Gửi khi nhấn Enter trên bàn phím (nếu có)
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          // Nút gửi tin nhắn
                          IconButton(
                            icon: Icon(
                              Icons.send,
                              color: Theme.of(context).primaryColor,
                            ),
                            onPressed: _sendMessage,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white, // Nền nút gửi
                              shape: const CircleBorder(), // Bo tròn nút
                              padding: const EdgeInsets.all(
                                12,
                              ), // Tăng vùng nhấn
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Nút hành động nổi (Floating Action Button) cho Micro
      floatingActionButton: FloatingActionButton(
        onPressed: _handleMicTap,
        backgroundColor: Colors.blueGrey[600],
        child: const Icon(Icons.mic, color: Colors.white),
        tooltip: 'Bật/Tắt Micro', // Tooltip khi nhấn giữ
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation
              .centerDocked, // Đặt ở giữa dưới, hơi nhô lên nếu có BottomAppBar
      // Nếu muốn FAB nằm hoàn toàn phía trên BottomNavigationBar/Chat Input thì dùng centerFloat
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // Thêm một BottomAppBar giả để tạo khoảng trống cho FAB nếu dùng centerDocked
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Tạo vết cắt cho FAB
        notchMargin: 6.0, // Khoảng cách giữa FAB và AppBar
        color: Colors.blueGrey[800], // Màu nền của thanh dưới cùng
        child: Container(height: 40.0), // Chỉ cần chiều cao để hiển thị
      ),
    );
  }
}
