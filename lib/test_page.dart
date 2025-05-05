import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:speech_to_text/speech_recognition_result.dart'; // NEW: Import for STT result
import 'package:speech_to_text/speech_to_text.dart'; // NEW: Import for STT

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
  bool _isLoading = false; // General loading state (e.g., for WHEP)
  String? _errorMessage;
  String _status = 'Disconnected';

  // !!! THAY THẾ ĐỊA CHỈ SERVER SRS CỦA BẠN VÀO ĐÂY !!!
  final String _whepUrl =
      'https://aitools.ptit.edu.vn/rtc/v1/whep/?app=live&stream=livestream';
  // ----------------------------------------------------

  // --- Biến trạng thái cho giao diện Chat ---
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController =
      ScrollController(); // NEW: Scroll controller for chat
  final List<String> _messages = [
    "Chào mừng đến với buổi stream!",
    "Đây là khung chat mẫu.",
    "Nhấn nút micro để nói.",
  ]; // Danh sách tin nhắn mẫu

  // --- NEW: Biến trạng thái cho Speech-to-Text ---
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = ''; // Stores recognized words during listening
  // NEW: Define user_id and session_id (replace with your actual logic if needed)
  final String _userId = 'flutter_user_test_001';
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  // NEW: State for chatbot loading
  bool _isSendingToBot = false;
  // ---------------------------------------------

  @override
  void initState() {
    super.initState(); // Quan trọng: gọi super.initState() trước
    _initializeRenderer();
    _initSpeech(); // NEW: Initialize speech recognition
  }

  Future<void> _initializeRenderer() async {
    await _renderer.initialize();
  }

  // --- NEW: Initialize Speech-to-Text ---
  Future<void> _initSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      if (mounted) {
        setStateIfNotDisposed(() {
          _speechEnabled = available;
          if (!available) {
            _logger.w("Speech recognition not available.");
            // Optionally show a message to the user
          } else {
            _logger.i("Speech recognition initialized successfully.");
          }
        });
      }
    } catch (e) {
      _logger.e("Error initializing speech recognition: $e");
      if (mounted) {
        setStateIfNotDisposed(() {
          _speechEnabled = false;
        });
      }
    }
  }
  // ------------------------------------

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
    _chatController.dispose();
    _scrollController.dispose(); // NEW: Dispose scroll controller
    _speechToText.cancel(); // NEW: Cancel any ongoing speech operation
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

      // Create a new stream for each connection attempt
      _remoteStream = await createLocalMediaStream(
        'remoteStream-${DateTime.now().millisecondsSinceEpoch}',
      ); // Tên stream duy nhất

      // Assign the stream BEFORE setting up listeners that might use it
      setStateIfNotDisposed(() {
        _renderer.srcObject = _remoteStream;
      });

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        _logger.i(
          "Track received: kind=${event.track.kind}, id=${event.track.id}",
        );
        if (event.streams.isEmpty) {
          _logger.w("Track received but event.streams is empty!");
          // Handle scenario where track is added without an associated stream initially
          // Often, the track is automatically added to the stream associated
          // with the transceiver, which might be _remoteStream.
          // Add it manually if needed and not already present:
          if (_remoteStream != null &&
              !_remoteStream!.getTracks().any((t) => t.id == event.track.id)) {
            _logger.i(
              "Manually adding track ${event.track.id} to _remoteStream",
            );
            _remoteStream?.addTrack(event.track);
            // Potentially trigger UI update if needed here
            setStateIfNotDisposed(() {
              _renderer.srcObject = _remoteStream;
            });
          }
          return; // Exit early if no stream info
        }

        final stream = event.streams[0]; // Use the first stream associated

        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          _logger.i(
            "--> Received ${event.track.kind?.toUpperCase()} track: ${event.track.id} for stream: ${stream.id}",
          );
          // Ensure the track is added to our target stream
          if (_remoteStream != null && stream.id == _remoteStream!.id) {
            if (!_remoteStream!.getTracks().any(
              (t) => t.id == event.track.id,
            )) {
              _logger.i("Adding track ${event.track.id} to _remoteStream");
              _remoteStream?.addTrack(event.track);
            }
          } else if (_remoteStream != null) {
            _logger.w(
              "Received track for a different stream ID (${stream.id}) than expected (${_remoteStream!.id}). Adding anyway.",
            );
            _remoteStream?.addTrack(event.track);
          } else {
            _logger.e("Received track but _remoteStream is null!");
            return;
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
        } else {
          _logger.i('End of ICE candidates.');
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        _logger.i('ICE connection state changed: $state');
        setStateIfNotDisposed(() {
          switch (state) {
            case RTCIceConnectionState.RTCIceConnectionStateChecking:
              _status = 'Checking...';
              break;
            case RTCIceConnectionState.RTCIceConnectionStateConnected:
            case RTCIceConnectionState.RTCIceConnectionStateCompleted:
              _status = 'Connected';
              _errorMessage = null;
              break;
            case RTCIceConnectionState.RTCIceConnectionStateFailed:
              _status = 'Failed';
              _errorMessage = 'ICE Connection Failed.';
              _disconnect();
              break;
            case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
              _status = 'Disconnected';
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
      final response = await http
          .post(
            Uri.parse(_whepUrl),
            headers: {'Content-Type': 'application/sdp'},
            body: offer.sdp,
          )
          .timeout(const Duration(seconds: 15)); // Increase timeout slightly

      _logger.i("Received WHEP response: Status=${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final answerSdp = response.body;
        _logger.i("Received Answer SDP (length: ${answerSdp.length})");
        _logger.d("Answer SDP:\n$answerSdp"); // Log answer để debug
        final answer = RTCSessionDescription(answerSdp, 'answer');
        await _peerConnection!.setRemoteDescription(answer);
        _logger.i("Remote description set successfully!");
      } else {
        final errorBody =
            response.body.length > 200
                ? '${response.body.substring(0, 200)}...'
                : response.body;
        _logger.e(
          "WHEP request failed: ${response.statusCode}\nBody: $errorBody",
        );
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
        _errorMessage =
            e is TimeoutException
                ? "Connection timed out."
                : "Connection Error: ${e.toString()}";
        _status = 'Error';
      });
      await _disconnect();
    } finally {
      setStateIfNotDisposed(() {
        _isLoading = false;
        if (_status == 'Connecting...' && _errorMessage == null) {
          _status = 'Negotiating...';
        }
      });
    }
  }

  // Hàm ngắt kết nối (Sử dụng vòng lặp for để await từng track.stop())
  Future<void> _disconnect() async {
    _logger.i("Disconnecting...");
    // Prevent multiple disconnect calls
    if (_status == 'Disconnecting...' || _peerConnection == null) {
      _logger.w("Already disconnecting or not connected.");
      // Ensure state is reset if called while not connected
      if (_peerConnection == null && _status != 'Disconnected') {
        setStateIfNotDisposed(() {
          _status = 'Disconnected';
          _isLoading = false;
          _errorMessage = null;
          _renderer.srcObject = null; // Ensure renderer is cleared
        });
      }
      return;
    }

    setStateIfNotDisposed(() {
      _status = 'Disconnecting...';
      // Keep _isLoading true during disconnect to prevent reconnect attempts
      _isLoading = true;
    });

    List<MediaStreamTrack> tracksToStop = [];
    if (_remoteStream != null) {
      try {
        tracksToStop.addAll(_remoteStream!.getTracks());
      } catch (e) {
        _logger.w(
          "Error getting tracks from remoteStream during disconnect: $e",
        );
      }
    }

    try {
      // Stop tracks first
      if (tracksToStop.isNotEmpty) {
        _logger.i("Stopping ${tracksToStop.length} track(s)...");
        await Future.wait(
          tracksToStop.map((track) async {
            try {
              _logger.i("Stopping track: ${track.id} (${track.kind})");
              await track.stop();
              _logger.i("Track ${track.id} stopped.");
            } catch (e) {
              _logger.w("Error stopping track ${track.id}: $e");
            }
          }),
        );
      }

      // Dispose stream
      if (_remoteStream != null) {
        try {
          await _remoteStream!.dispose();
          _logger.i("Remote stream disposed.");
        } catch (e) {
          _logger.w("Error disposing remote stream: $e");
        }
        _remoteStream = null; // Set to null regardless of disposal error
      }

      // Close and dispose peer connection
      if (_peerConnection != null) {
        try {
          await _peerConnection!.close();
          _logger.i("Peer connection closed.");
        } catch (e) {
          _logger.w("Error closing peer connection: $e");
        }
        try {
          // Add a small delay before disposing, sometimes helps avoid race conditions
          await Future.delayed(const Duration(milliseconds: 100));
          await _peerConnection!.dispose();
          _logger.i("Peer connection disposed.");
        } catch (e) {
          _logger.w("Error disposing peer connection: $e");
        }
        _peerConnection = null; // Set to null regardless of disposal error
      }

      // Reset renderer cuối cùng, kiểm tra mounted
      if (mounted) {
        _renderer.srcObject = null;
        _logger.i("Renderer srcObject set to null.");
      } else {
        _logger.w("Widget unmounted before renderer could be cleared.");
      }

      _logger.i("Disconnected process finished.");
    } catch (e, s) {
      _logger.e("Error during disconnection steps", error: e, stackTrace: s);
    } finally {
      // Reset state after all cleanup attempts
      setStateIfNotDisposed(() {
        _status = 'Disconnected';
        _isLoading = false; // Now safe to reset loading
        _errorMessage = null; // Clear error on successful/attempted disconnect
        // Ensure renderer is null if not already done
        if (mounted && _renderer.srcObject != null) {
          _renderer.srcObject = null;
        }
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

  // Hàm xử lý gửi tin nhắn (từ text input)
  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      // Add user message immediately
      _addMessageToList("You: $text");
      _chatController.clear();

      // Call the chatbot function
      _sendToChatbot(text);

      _logger.i("Chat message sent via text input: $text");
    }
  }

  // --- NEW: Speech-to-Text methods ---
  void _onSpeechStatus(String status) {
    _logger.i("Speech status changed: $status");
    // Update listening state based on status (e.g., 'listening', 'notListening', 'done')
    bool listening = status == 'listening';
    if (_isListening != listening && mounted) {
      setStateIfNotDisposed(() {
        _isListening = listening;
        // If status is 'done' or 'notListening' and we were listening, process the result
        if (!_isListening && _lastWords.isNotEmpty) {
          _logger.i("Speech recognition finished. Recognized: $_lastWords");
          // Automatically send to chatbot when listening stops naturally
          _sendToChatbot(_lastWords);
          _lastWords = ''; // Clear after sending
        } else if (!_isListening) {
          // Handle cases where listening stopped without recognizing words (e.g., cancelled, timeout with no speech)
          _logger.i(
            "Speech recognition stopped without results or already processed.",
          );
          _lastWords = ''; // Ensure it's cleared
        }
      });
    }
  }

  void _onSpeechError(dynamic errorNotification) {
    _logger.e("Speech error: ${errorNotification.errorMsg}");
    setStateIfNotDisposed(() {
      _isListening = false; // Ensure listening stops on error
      _lastWords = ''; // Clear any partial results
      // Optionally display an error message in the chat
      _addMessageToList(
        "Bot: Lỗi nhận dạng giọng nói: ${errorNotification.errorMsg}",
      );
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _logger.d(
      "Speech result: ${result.recognizedWords}, final: ${result.finalResult}",
    );
    setStateIfNotDisposed(() {
      _lastWords = result.recognizedWords;
      // Optional: Update chat input temporarily while speaking?
      // _chatController.text = _lastWords; // Example, might be annoying
    });
    // If the result is final, we could potentially trigger send here,
    // but often letting the pause detection handle it is smoother.
    // if (result.finalResult && _lastWords.isNotEmpty) {
    //    _sendToChatbot(_lastWords);
    //    _lastWords = '';
    // }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled || _isListening) return;
    _logger.i("Starting speech recognition...");
    _lastWords = ''; // Clear previous words
    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: 'vi_VN', // Set Vietnamese locale
        listenFor: const Duration(seconds: 30), // Max listen duration
        pauseFor: const Duration(seconds: 4), // Auto-stop after 4s silence
        partialResults: true, // Get intermediate results
        cancelOnError: true, // Stop listening on error
        listenMode:
            ListenMode.confirmation, // Confirmation mode might be suitable
      );
      setStateIfNotDisposed(() {
        _isListening = true;
        // Maybe add a temporary message?
        // _addMessageToList("Bot: Đang nghe...", temporary: true);
      });
    } catch (e) {
      _logger.e("Error starting speech recognition: $e");
      setStateIfNotDisposed(() {
        _isListening = false;
      });
    }
  }

  Future<void> _stopListening() async {
    if (!_speechToText.isListening) return;
    _logger.i("Manually stopping speech recognition...");
    try {
      await _speechToText.stop();
      // The onStatus callback should handle setting _isListening = false
      // and sending the result if _lastWords is not empty.
    } catch (e) {
      _logger.e("Error stopping speech recognition: $e");
      setStateIfNotDisposed(() {
        _isListening = false; // Ensure state is correct even if stop fails
        _lastWords = ''; // Clear words on manual stop error
      });
    }
  }

  // MODIFIED: Microphone tap handler
  void _handleMicTap() {
    if (!_speechEnabled) {
      _logger.w("Mic tapped but speech is not enabled/initialized.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Không thể khởi động nhận dạng giọng nói."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_speechToText.isListening) {
      _logger.i("Mic tapped: Stopping listening.");
      _stopListening();
    } else {
      _logger.i("Mic tapped: Starting listening.");
      _startListening();
    }
  }
  // ------------------------------------

  // --- NEW: Function to send text to chatbot ---
  Future<void> _sendToChatbot(String inputText) async {
    if (inputText.isEmpty || _isSendingToBot) {
      _logger.w("Skipping chatbot request: Empty input or already sending.");
      return;
    }

    setStateIfNotDisposed(() {
      _isSendingToBot = true; // Indicate bot processing
      // Optionally add a "Bot is thinking..." message
      // _addMessageToList("Bot: ...", temporary: true);
    });

    final String apiUrl = 'https://aitools.ptit.edu.vn/nho/chat';
    _logger.i("Sending to chatbot API: $apiUrl");
    _logger.i(
      "Payload: user_id=$_userId, session_id=$_sessionId, text=$inputText",
    );

    try {
      final uri = Uri.parse(apiUrl);
      var request = http.MultipartRequest('POST', uri);
      request.fields['user_id'] = _userId;
      request.fields['session_id'] = _sessionId;
      request.fields['text'] = inputText;

      // Add timeout to the send operation
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
      );

      _logger.i("Chatbot API response status: ${streamedResponse.statusCode}");

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(response.body);
          _logger.d(
            "Chatbot API response body: ${response.body}",
          ); // Log full response

          // Extract the response field
          final String? botReply = jsonResponse['response'] as String?;

          if (botReply != null && botReply.isNotEmpty) {
            _addMessageToList("Bot: $botReply");
          } else {
            _logger.w("Chatbot response field is missing or empty.");
            _addMessageToList("Bot: (Không nhận được phản hồi hợp lệ)");
          }
        } catch (e) {
          _logger.e("Error decoding chatbot JSON response: $e");
          _addMessageToList("Bot: (Lỗi xử lý phản hồi từ bot)");
        }
      } else {
        _logger.e(
          "Chatbot API request failed: ${response.statusCode}\nBody: ${response.body}",
        );
        _addMessageToList("Bot: (Lỗi ${response.statusCode} khi gọi bot)");
      }
    } on TimeoutException catch (e) {
      _logger.e("Chatbot API request timed out: $e");
      _addMessageToList("Bot: (Yêu cầu tới bot bị timeout)");
    } catch (e, s) {
      _logger.e("Error sending to chatbot API", error: e, stackTrace: s);
      _addMessageToList("Bot: (Lỗi kết nối tới bot)");
    } finally {
      setStateIfNotDisposed(() {
        _isSendingToBot = false; // Done processing
        // Remove any temporary "thinking" message if used
      });
    }
  }
  // ---------------------------------------------

  // --- NEW: Helper to add message and scroll ---
  void _addMessageToList(String message, {bool temporary = false}) {
    // TODO: Implement logic for temporary messages if needed
    // For now, all messages are added permanently
    setStateIfNotDisposed(() {
      _messages.add(message);
    });
    // Auto-scroll to bottom after adding a message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  // -------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Video Stream & Chat"),
        backgroundColor: Colors.blueGrey[800],
        actions: [
          // NEW: Add a status indicator for speech service
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              _speechEnabled ? Icons.check_circle : Icons.cancel,
              color: _speechEnabled ? Colors.greenAccent : Colors.redAccent,
              semanticLabel:
                  _speechEnabled
                      ? "Speech service available"
                      : "Speech service unavailable",
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- Phần trên: Video Stream ---
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueGrey, width: 2.0),
                    borderRadius: BorderRadius.circular(12.0),
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Video View
                        if (_renderer.textureId !=
                            null) // Ensure renderer is ready
                          RTCVideoView(
                            _renderer,
                            mirror: false,
                            objectFit:
                                RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitContain,
                          )
                        else
                          const Center(
                            child: Text(
                              "Initializing Renderer...",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),

                        // Loading Indicator for WHEP connection
                        if (_isLoading && _status.contains('Connecting'))
                          const CircularProgressIndicator(),

                        // Status Text Overlay
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
                        // NEW: Listening Indicator
                        if (_isListening)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mic,
                                color: Colors.white,
                                size: 18,
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
                      backgroundColor: Colors.green[700],
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed:
                        (_isLoading && _status == 'Disconnecting...') ||
                                _peerConnection == null
                            ? null
                            : _disconnect, // Disable while disconnecting
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
              flex: 2,
              child: Container(
                margin: const EdgeInsets.only(
                  left: 8.0,
                  right: 8.0,
                  bottom: 8.0,
                  top: 0,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
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
                        controller:
                            _scrollController, // NEW: Attach scroll controller
                        padding: const EdgeInsets.all(10.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isUserMessage = message.startsWith("You:");
                          final isUserVoiceMessage = message.startsWith(
                            "You (voice):",
                          );
                          final isBotMessage = message.startsWith("Bot:");

                          Alignment alignment;
                          Color bubbleColor;
                          Color textColor;
                          String displayMessage;

                          if (isUserVoiceMessage) {
                            alignment = Alignment.centerRight;
                            bubbleColor =
                                Colors
                                    .lightBlue[300]!; // Slightly different blue for voice
                            textColor = Colors.white;
                            displayMessage = message.substring(
                              "You (voice): ".length,
                            );
                          } else if (isUserMessage) {
                            alignment = Alignment.centerRight;
                            bubbleColor = Colors.blue[400]!;
                            textColor = Colors.white;
                            displayMessage = message.substring("You: ".length);
                          } else if (isBotMessage) {
                            alignment = Alignment.centerLeft;
                            bubbleColor = Colors.white;
                            textColor = Colors.black87;
                            displayMessage = message.substring("Bot: ".length);
                          } else {
                            // Default style for system messages like "Welcome..."
                            alignment = Alignment.center;
                            bubbleColor = Colors.grey[300]!;
                            textColor = Colors.black54;
                            displayMessage = message;
                          }

                          return Align(
                            alignment: alignment,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 8.0,
                              ),
                              decoration: BoxDecoration(
                                color: bubbleColor,
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
                                displayMessage,
                                style: TextStyle(color: textColor),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // NEW: Loading indicator for chatbot
                    if (_isSendingToBot)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Bot đang trả lời...",
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ],
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
                                  borderRadius: BorderRadius.circular(20.0),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15.0,
                                  vertical: 10.0,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
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
                              backgroundColor: Colors.white,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
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
        onPressed:
            (_speechEnabled &&
                    !_isSendingToBot) // Disable mic while bot is thinking
                ? _handleMicTap
                : null, // Disable if speech not enabled or bot is busy
        backgroundColor:
            _isListening
                ? Colors
                    .redAccent // Red when listening
                : (_speechEnabled
                    ? Colors.blueGrey[600]
                    : Colors.grey), // Grey if disabled
        tooltip: _isListening ? 'Dừng nói' : 'Nhấn để nói',
        child: Icon(
          _isListening ? Icons.mic_off : Icons.mic, // Toggle icon
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Thêm một BottomAppBar giả
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: Colors.blueGrey[800],
        child: Container(height: 40.0), // Height needed for the notch effect
      ),
    );
  }
}
