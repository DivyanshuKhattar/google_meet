import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_meet/Resources/signal_functions.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key,}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double deviceHeight = 0;
  double deviceWidth = 0;
  Signaling signaling = Signaling();
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  String? roomId;
  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    try{
      localRenderer.initialize();
      remoteRenderer.initialize();
      signaling.onAddRemoteStream = ((stream) {
        remoteRenderer.srcObject = stream;
      });
      signaling.openUserMedia(localRenderer, remoteRenderer).then((value) {
        setState(() {});
      });
    }
    catch(e){
      debugPrint("update user");
    }
    super.initState();
  }

  @override
  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    deviceHeight = MediaQuery.of(context).size.height;
    deviceWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: deviceHeight*0.4,
                  width: deviceWidth*0.6,
                  child: RTCVideoView(remoteRenderer),
                ),

                SizedBox(
                  height: deviceHeight*0.2,
                  width: deviceWidth*0.2,
                  child: RTCVideoView(localRenderer, mirror: true),
                ),

                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: textEditingController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.2),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try{
                          roomId = await signaling.createRoom(remoteRenderer);
                          textEditingController.text = roomId!;
                          setState(() {});
                        }
                        catch(e){
                          debugPrint(e.toString());
                        }
                      },
                      child: const Text("Create room"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        try{
                          signaling.joinRoom(
                            textEditingController.text.trim(),
                            remoteRenderer,
                          );
                          setState(() {});
                        }
                        catch(e){
                          debugPrint(e.toString());
                        }
                      },
                      child: const Text("Join room"),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                IconButton(
                  onPressed: (){
                    try{
                      signaling.hangUp(localRenderer);
                    }
                    catch(e){
                      debugPrint(e.toString());
                    }
                  },
                  icon: const Icon(Icons.call_end, color: Colors.red,),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}