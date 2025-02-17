import 'package:socket_io_client/socket_io_client.dart' as IO;

class _PainViewState extends State<PainView> {
  IO.Socket? socket;
  bool _isTracking = false;
  double _gazeLeftX = 0.0;
  double _gazeLeftY = 0.0;
  double _gazeRightX = 0.0;
  double _gazeRightY = 0.0;
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    socket = IO.io('http://172.20.10.14:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket!.connect();
    socket!.on('connect', (_) => print('Connected to server'));
    socket!.on('gaze_data', (data) => _handleGazeData(data));
  }

  void _handleGazeData(dynamic data) {
    setState(() {
      _gazeLeftX = data['gaze_left_x'] ?? 0.0;
      _gazeLeftY = data['gaze_left_y'] ?? 0.0;
      _gazeRightX = data['gaze_right_x'] ?? 0.0;
      _gazeRightY = data['gaze_right_y'] ?? 0.0;
    });
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      print("No cameras available!");
      return;
    }
    _controller = CameraController(cameras[1], ResolutionPreset.medium);

    try {
      await _controller!.initialize();
      _controller!.startImageStream((CameraImage image) {
        _sendFrameToServer(image);
      });
      setState(() {
        _isTracking = true;
      });
    } catch (e) {
      print("Error initializing camera: $e");
    }
  }

  void _sendFrameToServer(CameraImage image) async {
    if (!_isTracking) return;
    try {
      final bytes = await _convertImageToBytes(image);
      socket!.emit('handle_frame', bytes);
    } catch (e) {
      print('Error sending frame: $e');
    }
  }

  Future<Uint8List> _convertImageToBytes(CameraImage image) async {
    final img.Image capturedImage = img.Image.fromBytes(
      image.width,
      image.height,
      image.planes[0].bytes,
      format: img.Format.bgra,
    );
    img.Image resizedImage = img.copyResize(capturedImage, width: 320, height: 240);
    return Uint8List.fromList(img.encodeJpg(resizedImage, quality: 70));
  }

  void _closeAll() {
    setState(() {
      _isTracking = false;
    });
    _stopCamera();
  }

  Future<void> _stopCamera() async {
    if (_controller != null) {
      await _controller!.stopImageStream();
      await _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _closeAll();
    socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Eye Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Eye Tracking'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('Voulez-vous activer ou désactiver le eye tracking?')
                      ],
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: Text('Désactiver'),
                        onPressed: () {
                          _closeAll();
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text('Activer'),
                        onPressed: () {
                          _initializeCamera();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _isTracking
            ? Text('Eye tracking actif\nGaze gauche: (${_gazeLeftX.toStringAsFixed(2)}, ${_gazeLeftY.toStringAsFixed(2)})\nGaze droit: (${_gazeRightX.toStringAsFixed(2)}, ${_gazeRightY.toStringAsFixed(2)})')
            : Text('Eye tracking inactif'),
      ),
    );
  }
}
