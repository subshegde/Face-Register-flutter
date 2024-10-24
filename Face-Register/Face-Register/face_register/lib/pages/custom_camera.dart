import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class FacesList{
  int? id;
  String? imagePath;
FacesList({this.id,this.imagePath});

}

class CustomCameraScreen extends StatefulWidget {
  @override
  _CustomCameraScreenState createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen>with SingleTickerProviderStateMixin  {
  final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector();
  bool isProcessing = false;

  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;
  String? imagePath; 
  List<FacesList> imagePaths = [];

  final ScrollController _scrollController = ScrollController();

  bool showLoadingGif = true;
  static int _currentId = 0;


  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  
  static int generateUniqueId() {
    return ++_currentId;
  }


   Future<void> _startLoading() async {
    await Future.delayed(Duration(milliseconds: 1900)); 
    setState(() {
      showLoadingGif = false;
    });
  }


  Future<void> _initializeCamera() async {
    // Get the list of available cameras
    cameras = await availableCameras();
    final frontCamera = cameras!.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front);

    // Initialize the camera controller
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize(); // Ensure the controller is initialized
    setState(() {
      isCameraInitialized = true;
    });

    // Start detecting faces once the camera is initialized
    _startFaceDetection();
  }

  void _startFaceDetection() async {
    // Continuously detect faces while the camera is active
    while (isCameraInitialized && _controller != null && _controller!.value.isInitialized) {
      bool detected = await _detectFaces();
      if (detected) {
        await _captureImage();
      }
      await Future.delayed(Duration(seconds: 1)); // Delay to avoid rapid firing
    }
  }

  Future<bool> _detectFaces() async {
    if (isProcessing) return false; // Return false if already processing
    isProcessing = true;

    try {
      // Capture image and process for faces
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await faceDetector.processImage(inputImage);
      return faces.isNotEmpty; // Return true if faces detected, else false
    } catch (e) {
      print('Error detecting faces: $e');
      return false; // In case of error, return false
    } finally {
      isProcessing = false; // Reset processing state
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final newImagePath = join(directory.path, '${DateTime.now()}.png');
      XFile image = await _controller!.takePicture();
      await image.saveTo(newImagePath);
      setState(() {
        if (imagePath == null) {
          imagePath = newImagePath;
        } else if (imagePaths.length < 3) {
          imagePaths.add(FacesList(imagePath: newImagePath,id: generateUniqueId()));
        }

        if (imagePaths.length == 2) {
          _disposeCamera();
           _startLoading();

        }
      });
      print('Image saved to: $newImagePath');
    } catch (e) {
      print('Error capturing image: $e');
    }
  }

  Future<void> _disposeCamera() async {
    if (_controller != null) {
      await _controller!.dispose();
      setState(() {
        isCameraInitialized = false;
      });
    }
  }

  @override
  void dispose() {
    _disposeCamera();
    faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Stack(
        children: [
          // Show loading GIF if 5 images are taken
          if (imagePaths.length >= 2 && showLoadingGif) ...[
              Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 150.0),
                child:  Image.asset(
                'assets/gifs/loading.gif',
                height: 200,
              ),
              ),
            ),
          ] else if (!showLoadingGif) ...[
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 180.0),
                child: Image.asset(
                  'assets/icons/check.png',
                  scale: 5.5,
                ),
              ),
            ),

            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 290.0),
                child: Container(child: Text('Added successfully',textAlign: TextAlign.center,style: TextStyle(color: Colors.white,fontSize: 29,),),)
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 340.0),
                child:  Container(child: const Text('You can unlock this device using your face data now.',
                textAlign: TextAlign.center,style: TextStyle(color: Colors.grey,fontSize: 13,),),)
              ),
            ),
             Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 355.0),
                child: Container(child: const Text('Continue to access additional settings.',
                textAlign: TextAlign.center,style: TextStyle(color: Colors.grey,fontSize: 13,),),)
              ),
            ),
          ],
        
          // Display CameraPreview if the camera is initialized
          if (_controller != null && isCameraInitialized)
            if (imagePath == null) ...[
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center, 
                  children: [
                    const Text(
                      "Keep your face inside the frame",
                      style:  TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    Container(
                      height: 400,
                      width: double.infinity,
                      child: CameraPreview(_controller!),
                    ),
                  ],
                ),
              ),
            ] else if (imagePath != null) ...[

               Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 150.0),
                child:Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2196F3), width: 4),
                  ),
                  child: ClipOval(
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            ),
            ],

            if(!showLoadingGif)...[
              if(imagePaths.isNotEmpty)...[
             Padding(
             padding: const EdgeInsets.symmetric(horizontal: 15.0),
               child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 585.0),
                  child: ListView.builder(
                                    controller: _scrollController,
                                    itemCount: 1,
                                    itemBuilder: (context, index) {
                                    var list = imagePaths[imagePaths.length - 1 - index];                                    return GestureDetector(
                                        onTap: () {
               
                                        },
                                        child: ImageClass(
                                          id: list.id,
                                          imagePath:list.imagePath??"",
onTrash: (id) {
  int itemIndex = imagePaths.indexWhere((list) => list.id == id);
  if (itemIndex != -1) {
    setState(() {
      imagePaths.removeAt(itemIndex);
    });
  }
},

                                        ),
                                      );
                                    },
                                  ),
                ),
                           ),
             ),],

Positioned(
  bottom: 20,
  left: 0,
  right: 0,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20.0),
    child: ElevatedButton(
      onPressed: () {
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:const  Color(0xFF2196F3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(double.infinity, 45), 
      ),
      child: const Text(
        'Done',
        style: TextStyle(fontSize: 18,color: Colors.white),
      ),
    ),
  ),
),],
        ],
      ),
    ),
  );
}
}



class ImageClass extends StatefulWidget {
  final int? id;
  final String imagePath;
  final Function(int?)? onTrash; 

  const ImageClass({
    Key? key,
    required this.imagePath,
    required this.id,
    required this.onTrash,
  }) : super(key: key);

  @override
  _ImageClassState createState() => _ImageClassState();
}

class _ImageClassState extends State<ImageClass> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 70, 70, 70),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.grey,
            blurRadius: .2,
            spreadRadius: 0.1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          ClipOval(
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.fitWidth,
              width: 35,
              height: 35,
            ),
          ),
          GestureDetector(
            onTap: () {
              if (widget.onTrash != null) {
                widget.onTrash!(widget.id);
              }
            },
            child: Container(
              child: Image.asset(
                'assets/icons/trash.png',
                scale: 25,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
