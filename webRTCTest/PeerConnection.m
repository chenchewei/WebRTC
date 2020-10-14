//
//  PeerConnection.m
//  webRTCTest
//
//  Created by 吳尚霖 on 10/14/20.
//  Copyright © 2020 SamWu. All rights reserved.
//

#import "PeerConnection.h"
#import <WebRTC/WebRTC.h>
#import <WebRTC/RTCIceServer.h>
#import <SocketIO-Swift.h>
#import <AVFoundation/AVFoundation.h>

@interface PeerConnection()

@property (strong,nonatomic) RTCPeerConnection *peerConnection;
@property (strong,nonatomic) RTCMediaStream *localStream;

@end

@implementation PeerConnection

static RTCPeerConnectionFactory *rtcFactory = nil;

+ (RTCMediaStream *)createLocalStream {
    if(!rtcFactory) {
        rtcFactory = [[RTCPeerConnectionFactory alloc]init];
    }
    
    RTCMediaStream *localStream = [rtcFactory mediaStreamWithStreamId:[NSString stringWithFormat:@"localStream_%@",[NSUUID UUID]]];
    
    return localStream;
}

- (void)checkMicroPhonePermission:(RTCMediaStream *)localStream{
    
    AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession
                                                      discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone]
                                                      mediaType:AVMediaTypeAudio position:0];
    
    AVCaptureDevice *device = [deviceSession.devices firstObject];
    
    
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (authStatus == AVAuthorizationStatusDenied || authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
           if(!granted)
               NSLog(@"Microphone permission denied.");
           else{
               if (device) {
                   
                   [[AVAudioSession sharedInstance]setActive:false error:nil];
                   [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionMixWithOthers error:nil];
                   
                   [localStream addAudioTrack:[rtcFactory audioTrackWithTrackId:[NSString stringWithFormat:@"AudioTrack_%@",[NSUUID UUID]]]];
                                      
                   //NSLog(@"setLocalStream");
               }
           }
        }];
        
    }
    else{
        if (device) {
        
            [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:nil];

            [localStream addAudioTrack:[rtcFactory audioTrackWithTrackId:[NSString stringWithFormat:@"AudioTrack_%@",[NSUUID UUID]]]];
                        
            //NSLog(@"setLocalStream");
            
        }else
            NSLog(@"Microphone cannot open in this device.");
    }

    //Video
                   /*
                   RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:device.localizedName];
                   RTCVideoSource *videoSource = [_factory videoSourceWithCapturer:capturer constraints:[self localVideoConstraints]];
                    */
                   
    //               RTCAVFoundationVideoSource *videoSource = [[RTCAVFoundationVideoSource alloc] initWithFactory:_factory constraints:[self localVideoConstraints]];
    //               _localVideoSource = videoSource;
    //               RTCVideoTrack *videoTrack = [_factory videoTrackWithID:@"ARDAMSv0" source:videoSource];
    //               [_localStream addVideoTrack:videoTrack];
                   
                   
    //               //显示本地流
    //               RTCEAGLVideoView *localVideoView = [[RTCEAGLVideoView alloc] init];
    //               localVideoView.frame = CGRectMake(0, 60, 375/2.0, 375/2.0*1.3);
    //               //标记摄像头
    //               localVideoView.tag = 100;
    //               //摄像头旋转
    //               localVideoView.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    //               _localVideoTrack = [_localStream.videoTracks lastObject];
    //               [_localVideoTrack addRenderer:localVideoView];
    //               [self.view addSubview:localVideoView];
                   
    
    
}

+ (RTCMediaConstraints *)offerOranswerConstraint {
    
//    [self unusedFunc];
    
//    NSDictionary *dic = @{@"VoiceActivityDetection":@"true"};
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{@"OfferToReceiveAudio":@"true",@"VoiceActivityDetection":@"true",@"VoiceActivityDetection":@"false"} optionalConstraints:@{@"DtlsSrtpKeyAgreement":@"true"}];
}

+ (RTCConfiguration*)setStunServerToICEServer{
    
    //@"stun:turn.quickblox.com"
    //@"stun:turn.quickblox.com",
    //@"turn:turn.quickblox.com:3478?transport=udp",
    //@"turn:turn.quickblox.com:3478?transport=tcp"
    //NSString *userName = [stunURL containsString:@"quickblox"] ? @"quickblox":@"";
    //NSString *password = [stunURL containsString:@"quickblox"] ? @"baccb97ba2d92d71e26eb9886da5f1e0":@"";
    
    NSArray *stunServers = @[
                            @"stun:stun.l.google.com:19302",
                            @"stun:stun1.l.google.com:19302",
                            @"stun:stun2.l.google.com:19302"
//                            @"stun:stun3.l.google.com:19302",
//                            @"stun:stun4.l.google.com:19302"
                           ];
    
    RTCConfiguration *rtcConfig = [[RTCConfiguration alloc]init];
    
    RTCIceServer *iceServer = [[RTCIceServer alloc]initWithURLStrings:@[@"turn:turn.quickblox.com:3478?transport=tcp"] username:@"quickblox" credential:@"baccb97ba2d92d71e26eb9886da5f1e0"];
    
//    RTCIceServer *iceServer = [[RTCIceServer alloc]initWithURLStrings:@[@"turn:relay.backups.cz"] username:@"webrtc" credential:@"webrtc"];
    
    [rtcConfig setIceServers:@[[[RTCIceServer alloc]initWithURLStrings:stunServers],iceServer]];
    return rtcConfig;
}

@end
