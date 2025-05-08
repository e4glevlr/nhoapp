import 'package:flutter/material.dart';
import 'dart:convert'; // Import dart:convert for jsonEncode
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class TestPage extends StatefulWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
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
  String _lastWords = ''; // Sẽ lưu trữ kết quả nhận dạng gần nhất
  final String _userId = 'flutter_user_test_001';
  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isSendingToBot = false;

  // Cờ mới để quản lý việc xử lý kết quả cuối cùng
  bool _hasProcessedFinalWords = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
    _initSpeech();
  }

  Future<void> _initializeRenderer() async {
    await _renderer.initialize();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging:
            true, // Bật debug logging của plugin để xem thêm thông tin
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
    _speechToText.cancel(); // Đảm bảo speech_to_text được dừng và hủy
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
        'iceServers': [], // Add STUN/TURN servers if needed
        'sdpSemantics': 'unified-plan',
      }, {});

      _remoteStream = await createLocalMediaStream(
        'remoteStream-${DateTime.now().millisecondsSinceEpoch}',
      );

      setStateIfNotDisposed(() {
        _renderer.srcObject = _remoteStream;
      });

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        _logger.i(
          "Track received: kind=${event.track.kind}, id=${event.track.id}, streamIds: ${event.streams.map((s) => s.id).join(', ')}",
        );
        if (event.streams.isEmpty) {
          _logger.w(
            "Track received but event.streams is empty! Manually adding to _remoteStream.",
          );
          if (_remoteStream != null && mounted) {
            _remoteStream?.addTrack(event.track);
            setStateIfNotDisposed(() => _renderer.srcObject = _remoteStream);
          }
          return;
        }

        final stream = event.streams[0];
        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          _logger.i(
            "--> Received ${event.track.kind?.toUpperCase()} track: ${event.track.id} for stream: ${stream.id}",
          );
          if (_remoteStream != null) {
            // Check if track already exists to prevent duplicates if onTrack is called multiple times for the same track
            if (!_remoteStream!.getTracks().any(
              (t) => t.id == event.track.id,
            )) {
              _remoteStream?.addTrack(event.track);
            }
            if (mounted) {
              setStateIfNotDisposed(() {
                _renderer.srcObject = _remoteStream;
              });
            }
          }
        }
        event.track.onUnMute = () {
          _logger.i("Track unmuted: ${event.track.id}");
          if (mounted && _remoteStream != null) {
            setState(() => _renderer.srcObject = _remoteStream);
          }
        };
        event.track.onEnded = () {
          _logger.w("Track ended: ${event.track.id}");
          if (_remoteStream != null) {
            _remoteStream!.removeTrack(event.track);
            if (mounted) {
              setState(() => _renderer.srcObject = _remoteStream);
            }
          }
        };
        event.track.onMute = () => _logger.w("Track muted: ${event.track.id}");
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
              // Consider if a disconnect here should also trigger _disconnect()
              // _disconnect();
              break;
            case RTCIceConnectionState.RTCIceConnectionStateClosed:
              _status = 'Closed';
              // _disconnect();
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
          // This might be too optimistic if setRemoteDescription hasn't completed successfully yet
          // _status = 'Negotiating...'; // Status will be updated by ICE/PeerConnection states
        }
      });
    }
  }

  Future<void> _disconnect() async {
    _logger.i("Disconnecting...");
    if ((_status == 'Disconnecting...' || _status == 'Disconnected') &&
        _peerConnection == null) {
      _logger.w("Already disconnected or not connected.");
      // Ensure UI is consistent
      if (_status != 'Disconnected') {
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
      _isLoading = true; // Can set to true to show an indicator during cleanup
    });

    try {
      // Stop speech recognition if it's active
      if (_isListening || _speechToText.isListening) {
        await _speechToText.stop();
        _logger.i("Speech recognition stopped during disconnect.");
      }

      if (_remoteStream != null) {
        for (var track in _remoteStream!.getTracks()) {
          try {
            _logger.i("Stopping track: ${track.id} (${track.kind})");
            await track.stop();
            _logger.i("Track ${track.id} stopped.");
          } catch (e) {
            _logger.w("Error stopping track ${track.id}: $e");
          }
        }
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
        // Add a small delay before disposing, sometimes helpful
        await Future.delayed(const Duration(milliseconds: 100));
        try {
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
      }
    } catch (e, s) {
      _logger.e("Error during disconnection steps", error: e, stackTrace: s);
    } finally {
      setStateIfNotDisposed(() {
        _status = 'Disconnected';
        _isLoading = false;
        _errorMessage = null;
        _isListening = false; // Ensure listening state is false
        _hasProcessedFinalWords = false; // Reset for next potential connection
        if (mounted && _renderer.srcObject != null) {
          _renderer.srcObject = null; // Ensure renderer is cleared
        }
      });
      _logger.i("Disconnected process finished.");
    }
  }

  void setStateIfNotDisposed(Function() fn) {
    if (mounted) {
      setState(fn);
    } else {
      _logger.w("Tried to call setState on a disposed widget.");
    }
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      _addMessageToList("You: $text");
      _chatController.clear();
      _sendToChatbot(text);
      _logger.i("Chat message sent via text input: $text");
    }
  }

  // --- Speech-to-Text methods ---
  void _onSpeechStatus(String status) {
    _logger.i(
      "Speech status: '$status'. Widget _isListening: $_isListening. Plugin.isListening: ${_speechToText.isListening}. _lastWords: '$_lastWords'. _hasProcessedFinalWords: $_hasProcessedFinalWords",
    );

    if (!mounted) {
      _logger.w("onSpeechStatus: Widget not mounted. Status: $status");
      return;
    }

    bool pluginIsActuallyListening = _speechToText.isListening;

    // Fallback: Nếu listening dừng lại VÀ chưa xử lý từ final trong onResult VÀ _lastWords có nội dung
    // This can happen if listening stops abruptly or if finalResult=true was missed.
    if (!pluginIsActuallyListening &&
        !_hasProcessedFinalWords &&
        _lastWords.isNotEmpty) {
      _logger.w(
        "FALLBACK in onSpeechStatus: Listening stopped (status: $status), final words were NOT processed via onResult. Processing _lastWords ('$_lastWords') now.",
      );
      String wordsToProcess = _lastWords; // Capture before clearing
      _hasProcessedFinalWords = true; // Mark as processed to prevent duplicates
      _lastWords = ''; // Clear immediately

      _addMessageToList("You (voice): $wordsToProcess");
      _sendToChatbot(wordsToProcess);
    }

    // Luôn đồng bộ trạng thái _isListening của widget với plugin
    if (_isListening != pluginIsActuallyListening) {
      setStateIfNotDisposed(() {
        _isListening = pluginIsActuallyListening;
        _logger.i(
          "Widget _isListening state synced to $pluginIsActuallyListening.",
        );
      });
    }

    // Clean up _lastWords if listening has stopped and words were already processed.
    if (!pluginIsActuallyListening &&
        _hasProcessedFinalWords &&
        _lastWords.isNotEmpty) {
      _logger.d(
        "onSpeechStatus: Listening stopped, final words were processed. Clearing residual _lastWords ('$_lastWords').",
      );
      _lastWords = '';
    }
  }

  void _onSpeechError(dynamic errorNotification) {
    _logger.e(
      "Speech error: ${errorNotification.errorMsg} - permanent: ${errorNotification.permanent}",
    );
    if (mounted) {
      setStateIfNotDisposed(() {
        _isListening = false; // Ensure listening state is false
        _addMessageToList(
          "Bot: Speech recognition error: ${errorNotification.errorMsg}",
        );
        // Reset flags if error is permanent, allowing a fresh start for next attempt
        if (errorNotification.permanent ?? true) {
          _hasProcessedFinalWords = false;
          _lastWords = '';
        }
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _logger.d(
      "Speech result: '${result.recognizedWords}', final: ${result.finalResult}, current _hasProcessedFinalWords: $_hasProcessedFinalWords",
    );

    // Always update _lastWords with the latest recognized words from the plugin.
    // This is important for the fallback logic in _onSpeechStatus.
    _lastWords = result.recognizedWords;

    // If this is the final result AND it has content AND it hasn't been processed yet
    if (result.finalResult &&
        result.recognizedWords.isNotEmpty &&
        !_hasProcessedFinalWords) {
      _logger.i(
        "PRIMARY PROCESSING in onResult: Final recognized words: '${result.recognizedWords}'. Processing now.",
      );

      String finalWords = result.recognizedWords;
      _hasProcessedFinalWords =
          true; // Mark as processed IMMEDIATELY to prevent re-entry

      _addMessageToList("You (voice): $finalWords");
      _sendToChatbot(finalWords);

      // Clear _lastWords after processing, as 'finalWords' holds the definitive text for this utterance.
      // This is a secondary safety measure; _hasProcessedFinalWords is the primary guard.
      _lastWords = '';
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled || _isListening) {
      _logger.i(
        "Start listening called but speech not enabled or already listening (widget state: $_isListening, plugin state: ${_speechToText.isListening}).",
      );
      // If widget state is true but plugin is not, sync it.
      if (_isListening && !_speechToText.isListening && mounted) {
        setStateIfNotDisposed(() {
          _isListening = false;
        });
      }
      return;
    }
    _logger.i("Attempting to start speech recognition...");

    _lastWords = ''; // Clear any stale words from previous sessions
    _hasProcessedFinalWords = false; // Reset flag for the new speaking session

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: 'en_US', // Or use a specific locale like 'vi_VN'
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(
          seconds: 3,
        ), // Consider adjusting this based on testing
        partialResults: true,
        cancelOnError: true, // Stop listening on error
        listenMode:
            ListenMode.confirmation, // Or other modes like ListenMode.search
      );
      setStateIfNotDisposed(() {
        _isListening = true; // Reflect that we've initiated listening
      });
      _logger.i("Speech recognition started listening.");
    } catch (e, s) {
      _logger.e("Error starting speech recognition", error: e, stackTrace: s);
      if (mounted) {
        setStateIfNotDisposed(() {
          _isListening = false;
          _hasProcessedFinalWords =
              false; // Ensure flag is reset on failed start
        });
      }
    }
  }

  Future<void> _stopListening() async {
    if (!_speechEnabled) {
      _logger.w("Attempted to stop listening, but speech is not enabled.");
      return;
    }

    // Check the plugin's actual listening state
    if (!_speechToText.isListening) {
      _logger.i(
        "Stop listening called, but plugin reports it's already not listening.",
      );
      if (_isListening && mounted) {
        // If widget state is out of sync
        setStateIfNotDisposed(() {
          _isListening = false; // Sync widget state
        });
      }
      // Fallback in _onSpeechStatus might handle any pending _lastWords if a 'done' status comes.
      // Or if _lastWords has content and _hasProcessedFinalWords is false.
      // Consider if a manual check/process is needed here if no further status update is guaranteed.
      // For now, rely on onStatus.
      return;
    }

    _logger.i(
      "Manually stopping speech recognition via _speechToText.stop()...",
    );
    try {
      await _speechToText.stop();
      _logger.i(
        "speechToText.stop() successfully called. Waiting for _onSpeechStatus callback to finalize.",
      );
      // _onSpeechStatus will be triggered by the plugin, which should then update _isListening
      // and handle any final processing via its fallback logic if needed.
    } catch (e, s) {
      _logger.e("Error calling _speechToText.stop()", error: e, stackTrace: s);
      if (mounted) {
        setStateIfNotDisposed(() {
          _isListening = false; // Ensure UI reflects not listening
          // Check if there are unprocessed words on error
          if (!_hasProcessedFinalWords && _lastWords.isNotEmpty) {
            _addMessageToList("Bot: Error stopping. Partial: $_lastWords");
            _hasProcessedFinalWords =
                true; // Mark as "handled" (via error message)
          } else {
            _addMessageToList("Bot: Error stopping speech recognition.");
          }
          _lastWords = ''; // Clear any remnants
        });
      }
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

    // Use the plugin's state as the source of truth for toggling
    if (_speechToText.isListening) {
      _logger.i("Mic tapped: Stopping listening (plugin is active).");
      _stopListening();
    } else {
      _logger.i("Mic tapped: Starting listening (plugin is not active).");
      _startListening();
    }
  }

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
            _addMessageToList("Bot: $botReply");
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

  Future<void> _sendResponseToAldaBackend(String botReplyText) async {
    final String aldaUrl =
        'https://aitools.ptit.edu.vn/alda_backend/human'; // Second API URL
    _logger.i("Sending bot response to Alda Backend: $aldaUrl");

    try {
      final Map<String, String> requestBody = {
        'text': botReplyText,
        'type': 'echo',
      };
      final String encodedBody = jsonEncode(requestBody);

      _logger.d("Alda Backend Payload: $encodedBody");

      final response = await http
          .post(
            Uri.parse(aldaUrl),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: encodedBody,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.i(
          "Successfully sent response to Alda Backend. Status: ${response.statusCode}",
        );
      } else {
        _logger.e(
          "Failed to send response to Alda Backend. Status: ${response.statusCode}, Body: ${response.body}",
        );
      }
    } on TimeoutException catch (e) {
      _logger.e("Timeout sending response to Alda Backend: $e");
    } catch (e, s) {
      _logger.e(
        "Error sending response to Alda Backend",
        error: e,
        stackTrace: s,
      );
    }
  }

  void _addMessageToList(String message, {bool temporary = false}) {
    setStateIfNotDisposed(() {
      _messages.add(message);
    });
    // Scroll to the bottom after a short delay to allow the ListView to update
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

  @override
  Widget build(BuildContext context) {
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
                        if (_renderer.textureId != null &&
                            _renderer.srcObject?.active == true)
                          RTCVideoView(
                            _renderer,
                            mirror: false,
                            objectFit:
                                RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitContain,
                          )
                        else
                          Center(
                            child: Text(
                              _renderer.textureId == null
                                  ? "Initializing Renderer..."
                                  : "Stream not active or ended",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        if (_isLoading &&
                            (_status.contains('Connecting') ||
                                _status.contains('Negotiating')))
                          const CircularProgressIndicator(),
                        if (!_isLoading &&
                            _status != 'Connected' &&
                            _status != 'Checking...' &&
                            !_status.contains('Connecting') && // Added this
                            !_status.contains('Negotiating')) // Added this
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
                    label: const Text('Start to call'),
                    onPressed:
                        (_isLoading ||
                                (_peerConnection != null &&
                                    _status != 'Disconnected' &&
                                    _status != 'Failed' &&
                                    _status != 'Error' &&
                                    _status !=
                                        'Closed')) // More precise condition
                            ? null
                            : _connect,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green[700],
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    icon:
                        _isLoading && _status == 'Disconnecting...'
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed:
                        (_isLoading && _status == 'Disconnecting...') ||
                                _peerConnection == null ||
                                _status == 'Disconnected' ||
                                _status == 'Closed'
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
                            // System or initial messages
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
            _isListening // Use widget's _isListening for FAB color
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
        child: Container(height: 40.0), // Consistent height
      ),
    );
  }
}
