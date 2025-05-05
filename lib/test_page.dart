import 'package:flutter/material.dart';
import 'dart:convert'; // Import dart:convert for jsonEncode
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http; // Already imported
import 'package:logger/logger.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

// Chuyển thành StatefulWidget
class TestPage extends StatefulWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  State<TestPage> createState() => _TestPageState();
}

// Tạo State class tương ứng
class _TestPageState extends State<TestPage> {
  // --- State variables (unchanged) ---
  final Logger _logger = Logger();
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;
  bool _isLoading = false;
  String? _errorMessage;
  String _status = 'Disconnected';
  final String _whepUrl =
      'https://aitools.ptit.edu.vn/rtc/v1/whep/?app=live&stream=livestream';
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _messages = [
    "Welcome to the stream!",
    "This is a sample chat.",
    "Press the microphone button to speak.",
  ];
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  final String _userId = 'flutter_user_test_001';
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isSendingToBot = false;
  // ------------------------------------

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
    _initSpeech();
  }

  // --- _initializeRenderer, _initSpeech, dispose, _connect, _disconnect, setStateIfNotDisposed (unchanged) ---
  Future<void> _initializeRenderer() async {
    await _renderer.initialize();
  }

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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Speech recognition service is not available on this device.",
                ),
                duration: Duration(seconds: 3),
              ),
            );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error initializing speech recognition: $e"),
              duration: const Duration(seconds: 3),
            ),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _logger.i("Disposing TestPage...");
    _renderer.dispose();
    _remoteStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.dispose();
    _peerConnection?.close();
    _peerConnection?.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _speechToText.cancel();
    super.dispose();
  }

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
        'iceServers': [],
        'sdpSemantics': 'unified-plan',
      }, {});

      _remoteStream = await createLocalMediaStream(
        'remoteStream-${DateTime.now().millisecondsSinceEpoch}',
      );

      setStateIfNotDisposed(() {
        _renderer.srcObject = _remoteStream;
      });

      // --- PeerConnection event handlers (onTrack, onIceCandidate, onIceConnectionState, onConnectionState) ---
      // (Assume these are the same as in the previous version for brevity)
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        _logger.i(
          "Track received: kind=${event.track.kind}, id=${event.track.id}",
        );
        if (event.streams.isEmpty) {
          _logger.w("Track received but event.streams is empty!");
          if (_remoteStream != null &&
              !_remoteStream!.getTracks().any((t) => t.id == event.track.id)) {
            _logger.i(
              "Manually adding track ${event.track.id} to _remoteStream",
            );
            _remoteStream?.addTrack(event.track);
            setStateIfNotDisposed(() {
              _renderer.srcObject = _remoteStream;
            });
          }
          return;
        }

        final stream = event.streams[0];

        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          _logger.i(
            "--> Received ${event.track.kind?.toUpperCase()} track: ${event.track.id} for stream: ${stream.id}",
          );
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

        event.track.onUnMute = () {
          _logger.i("Track unmuted: ${event.track.id}");
          if (mounted && _remoteStream != null) {
            setState(() {
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
          );
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
      //----------------------------------------------------------------------

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
          .timeout(const Duration(seconds: 15));

      _logger.i("Received WHEP response: Status=${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final answerSdp = response.body;
        _logger.i("Received Answer SDP (length: ${answerSdp.length})");
        _logger.d("Answer SDP:\n$answerSdp");
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

  Future<void> _disconnect() async {
    _logger.i("Disconnecting...");
    if (_status == 'Disconnecting...' || _peerConnection == null) {
      _logger.w("Already disconnecting or not connected.");
      if (_peerConnection == null && _status != 'Disconnected') {
        setStateIfNotDisposed(() {
          _status = 'Disconnected';
          _isLoading = false;
          _errorMessage = null;
          _renderer.srcObject = null;
        });
      }
      return;
    }

    setStateIfNotDisposed(() {
      _status = 'Disconnecting...';
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

      if (_remoteStream != null) {
        try {
          await _remoteStream!.dispose();
          _logger.i("Remote stream disposed.");
        } catch (e) {
          _logger.w("Error disposing remote stream: $e");
        }
        _remoteStream = null;
      }

      if (_peerConnection != null) {
        try {
          await _peerConnection!.close();
          _logger.i("Peer connection closed.");
        } catch (e) {
          _logger.w("Error closing peer connection: $e");
        }
        try {
          await Future.delayed(const Duration(milliseconds: 100));
          await _peerConnection!.dispose();
          _logger.i("Peer connection disposed.");
        } catch (e) {
          _logger.w("Error disposing peer connection: $e");
        }
        _peerConnection = null;
      }

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
      setStateIfNotDisposed(() {
        _status = 'Disconnected';
        _isLoading = false;
        _errorMessage = null;
        if (mounted && _renderer.srcObject != null) {
          _renderer.srcObject = null;
        }
      });
    }
  }

  void setStateIfNotDisposed(Function() fn) {
    if (mounted) {
      setState(fn);
    } else {
      _logger.w("Tried to call setState on a disposed widget.");
    }
  }
  // ---------------------------------------------------------------------------

  // Hàm xử lý gửi tin nhắn (từ text input)
  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      _addMessageToList("You: $text");
      _chatController.clear();
      _sendToChatbot(text);
      _logger.i("Chat message sent via text input: $text");
    }
  }

  // --- Speech-to-Text methods (_onSpeechStatus, _onSpeechError, _onSpeechResult, _startListening, _stopListening, _handleMicTap) ---
  // (Assume these are the same as in the previous version for brevity)
  void _onSpeechStatus(String status) {
    _logger.i("Speech status changed: $status");
    bool listening = status == 'listening';
    if (_isListening != listening && mounted) {
      setStateIfNotDisposed(() {
        _isListening = listening;
        if (!_isListening && _lastWords.isNotEmpty) {
          _logger.i("Speech recognition finished. Recognized: $_lastWords");
          // Add recognized text to chat list
          _addMessageToList("You (voice): $_lastWords");
          // Send to chatbot
          _sendToChatbot(_lastWords);
          _lastWords = '';
        } else if (!_isListening) {
          _logger.i(
            "Speech recognition stopped without results or already processed.",
          );
          _lastWords = '';
        }
      });
    }
  }

  void _onSpeechError(dynamic errorNotification) {
    _logger.e("Speech error: ${errorNotification.errorMsg}");
    setStateIfNotDisposed(() {
      _isListening = false;
      _lastWords = '';
      _addMessageToList(
        "Bot: Speech recognition error: ${errorNotification.errorMsg}",
      );
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _logger.d(
      "Speech result: ${result.recognizedWords}, final: ${result.finalResult}",
    );
    setStateIfNotDisposed(() {
      _lastWords = result.recognizedWords;
    });
  }

  Future<void> _startListening() async {
    if (!_speechEnabled || _isListening) return;
    _logger.i("Starting speech recognition...");
    _lastWords = '';
    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: 'en_US', // English locale
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
      setStateIfNotDisposed(() {
        _isListening = true;
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
      // onStatus callback handles state and processing
    } catch (e) {
      _logger.e("Error stopping speech recognition: $e");
      setStateIfNotDisposed(() {
        _isListening = false;
        _lastWords = '';
      });
    }
  }

  void _handleMicTap() {
    if (!_speechEnabled) {
      _logger.w("Mic tapped but speech is not enabled/initialized.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Speech recognition is not available or not initialized.",
          ),
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
  // ---------------------------------------------------------------------------

  // --- Function to send text to chatbot API ---
  Future<void> _sendToChatbot(String inputText) async {
    if (inputText.isEmpty || _isSendingToBot) {
      _logger.w("Skipping chatbot request: Empty input or already sending.");
      return;
    }

    setStateIfNotDisposed(() {
      _isSendingToBot = true;
    });

    final String chatApiUrl =
        'https://aitools.ptit.edu.vn/nho/chat'; // Chatbot API
    _logger.i("Sending to chatbot API: $chatApiUrl");
    _logger.i(
      "Payload: user_id=$_userId, session_id=$_sessionId, text=$inputText",
    );

    try {
      final uri = Uri.parse(chatApiUrl);
      var request = http.MultipartRequest('POST', uri);
      request.fields['user_id'] = _userId;
      request.fields['session_id'] = _sessionId;
      request.fields['text'] = inputText;

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
      );

      _logger.i("Chatbot API response status: ${streamedResponse.statusCode}");

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(response.body);
          _logger.d("Chatbot API response body: ${response.body}");

          final String? botReply = jsonResponse['response'] as String?;

          if (botReply != null && botReply.isNotEmpty) {
            // Add the bot's reply to the UI first
            _addMessageToList("Bot: $botReply");

            // *******************************************************
            // * NEW: Call the second API with the bot's response    *
            // *******************************************************
            await _sendResponseToAldaBackend(botReply);
          } else {
            _logger.w("Chatbot response field is missing or empty.");
            _addMessageToList("Bot: (Received an empty or invalid response)");
          }
        } catch (e) {
          _logger.e("Error decoding chatbot JSON response: $e");
          _addMessageToList("Bot: (Error processing bot response)");
        }
      } else {
        _logger.e(
          "Chatbot API request failed: ${response.statusCode}\nBody: ${response.body}",
        );
        _addMessageToList("Bot: (Error ${response.statusCode} calling bot)");
      }
    } on TimeoutException catch (e) {
      _logger.e("Chatbot API request timed out: $e");
      _addMessageToList("Bot: (Request to bot timed out)");
    } catch (e, s) {
      _logger.e("Error sending to chatbot API", error: e, stackTrace: s);
      _addMessageToList("Bot: (Error connecting to bot)");
    } finally {
      setStateIfNotDisposed(() {
        _isSendingToBot = false;
      });
    }
  }
  // ---------------------------------------------

  // --- NEW: Function to send bot response to Alda Backend API ---
  Future<void> _sendResponseToAldaBackend(String botReplyText) async {
    final String aldaUrl =
        'https://aitools.ptit.edu.vn/alda_backend/human'; // Second API URL
    _logger.i("Sending bot response to Alda Backend: $aldaUrl");

    try {
      // Prepare JSON body
      final Map<String, String> requestBody = {
        'text': botReplyText, // The bot's answer
        'type': 'echo', // Fixed type as requested
      };
      final String encodedBody = jsonEncode(requestBody);

      _logger.d("Alda Backend Payload: $encodedBody"); // Log the payload

      // Make the POST request
      final response = await http
          .post(
            Uri.parse(aldaUrl),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
            }, // Set content type header
            body: encodedBody, // Send encoded JSON string
          )
          .timeout(const Duration(seconds: 15)); // Add a timeout

      // Check the response status from the second API
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.i(
          "Successfully sent response to Alda Backend. Status: ${response.statusCode}",
        );
        // You can log the response body if needed:
        // _logger.d("Alda Backend Response Body: ${response.body}");
      } else {
        _logger.e(
          "Failed to send response to Alda Backend. Status: ${response.statusCode}, Body: ${response.body}",
        );
        // No user-facing error message here, just logging the failure.
      }
    } on TimeoutException catch (e) {
      _logger.e("Timeout sending response to Alda Backend: $e");
      // Handle timeout specifically if needed
    } catch (e, s) {
      _logger.e(
        "Error sending response to Alda Backend",
        error: e,
        stackTrace: s,
      );
      // Handle other potential errors (network issues, etc.)
    }
    // This function doesn't update the UI directly.
  }
  // -------------------------------------------------------------

  // --- Helper to add message and scroll ---
  void _addMessageToList(String message, {bool temporary = false}) {
    setStateIfNotDisposed(() {
      _messages.add(message);
    });
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

  // --- Build method (Assume mostly unchanged from previous version) ---
  @override
  Widget build(BuildContext context) {
    // (Structure remains the same: Scaffold, AppBar, Column with Video/Controls/Chat)
    // (RTCVideoView, Buttons, ListView.builder, TextField, FAB etc. are kept as before)
    return Scaffold(
      appBar: AppBar(
        title: const Text("Video Stream & Chat"),
        backgroundColor: Colors.blueGrey[800],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Tooltip(
              message:
                  _speechEnabled
                      ? "Speech service available"
                      : "Speech service unavailable or error",
              child: Icon(
                _speechEnabled ? Icons.check_circle : Icons.cancel,
                color: _speechEnabled ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Video Stream Section
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
                        if (_renderer.textureId != null)
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
                        // Loading & Status Overlays
                        if (_isLoading && _status.contains('Connecting'))
                          const CircularProgressIndicator(),
                        if (!_isLoading &&
                            _status != 'Connected' &&
                            _status != 'Checking...' &&
                            _status != 'Negotiating...')
                          Positioned(
                            // Status text
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
                        if (_isListening) // Listening indicator
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
            // Control Buttons Section
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
                            : _disconnect,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
            // Chat Section
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
                    // Message List Area
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(10.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isUserVoiceMessage = message.startsWith(
                            "You (voice):",
                          );
                          final isUserMessage =
                              message.startsWith("You:") && !isUserVoiceMessage;
                          final isBotMessage = message.startsWith("Bot:");

                          Alignment alignment;
                          Color bubbleColor;
                          Color textColor;
                          String displayMessage;

                          if (isUserVoiceMessage) {
                            alignment = Alignment.centerRight;
                            bubbleColor = Colors.lightBlue[300]!;
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
                    // Bot thinking indicator
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
                              "Bot is replying...",
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Divider(height: 1, color: Colors.grey[400]),
                    // Message Input Area
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
                                hintText: "Type a message...",
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
      floatingActionButton: FloatingActionButton(
        onPressed: (_speechEnabled && !_isSendingToBot) ? _handleMicTap : null,
        backgroundColor:
            _isListening
                ? Colors.redAccent
                : (_speechEnabled ? Colors.blueGrey[600] : Colors.grey),
        tooltip: _isListening ? 'Stop listening' : 'Tap to speak',
        child: Icon(
          _isListening ? Icons.mic_off : Icons.mic,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: Colors.blueGrey[800],
        child: Container(height: 40.0),
      ),
    );
  }

  //--------------------------------------------------------------------
}
