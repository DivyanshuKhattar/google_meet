import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class Signaling {

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  StreamStateCallback? onAddRemoteStream;
  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302'
        ]
      }
    ]
  };

  /// function to create room id
  Future<String> createRoom(RTCVideoRenderer remoteRenderer) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('rooms').doc();
    peerConnection = await createPeerConnection(configuration);
    registerPeerConnectionListeners();
    // adding track in peer connection
    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });
    // creating collection in firebase
    var callerCandidatesCollection = roomRef.collection('creator');
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      callerCandidatesCollection.add(candidate.toMap());
    };
    // creating room id
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    Map<String, dynamic> roomWithOffer = {'offer': offer.toMap()};
    await roomRef.set(roomWithOffer);
    var roomId = roomRef.id;
    // setting room
    peerConnection?.onTrack = (RTCTrackEvent event) {
      event.streams[0].getTracks().forEach((track) {
        remoteStream?.addTrack(track);
      });
    };
    // listening remote stream
    roomRef.snapshots().listen((snapshot) async {
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      if (peerConnection?.getRemoteDescription() != null && data['answer'] != null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await peerConnection?.setRemoteDescription(answer);
      }
    });
    // listening ice candidates
    roomRef.collection('joiner').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
          peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
    return roomId;
  }

  /// function to join room
  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteVideo) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('rooms').doc(roomId);
    var roomSnapshot = await roomRef.get();
    if (roomSnapshot.exists) {
      peerConnection = await createPeerConnection(configuration);
      registerPeerConnectionListeners();
      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });
      // fetching remote candidates
      var remoteCandidatesCollection = roomRef.collection('joiner');
      peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
        if (candidate == null) {
          return;
        }
        remoteCandidatesCollection.add(candidate.toMap());
      };
      peerConnection?.onTrack = (RTCTrackEvent event) {
        event.streams[0].getTracks().forEach((track) {
          remoteStream?.addTrack(track);
        });
      };
      // creating SDP
      var data = roomSnapshot.data() as Map<String, dynamic>;
      var offer = data['offer'];
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      var answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);
      Map<String, dynamic> roomWithAnswer = {
        'answer': {'type': answer.type, 'sdp': answer.sdp}
      };
      await roomRef.update(roomWithAnswer);
      // listening remote stream
      roomRef.collection('creator').snapshots().listen((snapshot) {
        for (var document in snapshot.docChanges) {
          var data = document.doc.data() as Map<String, dynamic>;
          peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      });
    }
  }

  /// function to open user camera and mic
  Future<void> openUserMedia(RTCVideoRenderer localVideo, RTCVideoRenderer remoteVideo) async {
    var stream = await navigator.mediaDevices.getUserMedia({'video': true, 'audio': true});
    localVideo.srcObject = stream;
    localStream = stream;
    remoteVideo.srcObject = await createLocalMediaStream('key');
  }

  /// function to hang up
  Future<void> hangUp(RTCVideoRenderer localVideo) async {
    List<MediaStreamTrack> tracks = localVideo.srcObject!.getTracks();
    for (var track in tracks) {
      track.stop();
    }
    if (remoteStream != null) {
      remoteStream!.getTracks().forEach((track) => track.stop());
    }
    if (peerConnection != null) peerConnection!.close();
    if (roomId != null) {
      var db = FirebaseFirestore.instance;
      var roomRef = db.collection('rooms').doc(roomId);
      // delete remote candidate
      var remoteCandidates = await roomRef.collection('joiner').get();
      for (var document in remoteCandidates.docs) {
        document.reference.delete();
      }
      // delete creator candidate
      var creatorCandidates = await roomRef.collection('creator').get();
      for (var document in creatorCandidates.docs) {
        document.reference.delete();
      }
      await roomRef.delete();
    }
    localStream!.dispose();
    remoteStream?.dispose();
  }

  /// function to register connection
  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {};
    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {};
    peerConnection?.onSignalingState = (RTCSignalingState state) {};
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {};
    peerConnection?.onAddStream = (MediaStream stream) {
      onAddRemoteStream?.call(stream);
      remoteStream = stream;
    };
  }
}
