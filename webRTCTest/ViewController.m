//
//  ViewController.m
//  webRTCTest
//
//  Created by 吳尚霖 on 7/22/20.
//  Copyright © 2020 SamWu. All rights reserved.
//

#import "ViewController.h"
#import "SocketRTCManager.h"

#import <RTCPair.h>
#import <RTCICEServer.h>
#import <WebRTC/WebRTC.h>
#import <SocketIO-Swift.h>
#import <AVFoundation/AVFoundation.h>

typedef enum : int{
    Caller = 0,
    Receiver = 1,
} Mode;

@interface ViewController ()<SocketRTCManagerDelegate,RTCPeerConnectionDelegate>
@property (strong, nonatomic) IBOutlet UILabel *socketStatus;

@property (strong,nonatomic) SocketRTCManager *socketRTCManager;

@property (strong,nonatomic) RTCPeerConnectionFactory *rtcFactory;
//@property (strong,nonatomic) RTCPeerConnection *peerConnection;
@property (strong,nonatomic) RTCMediaStream *localStream;

@property (strong,nonatomic) NSMutableDictionary *remoteAudioTracks;
@property (strong,nonatomic) NSMutableDictionary *connectionDic;
@property (strong,nonatomic) NSMutableArray *connectionIdArray;
@property (strong,nonatomic) NSMutableArray *ICEServers;

@property (assign,nonatomic) Mode *mode;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self initData];
    
    [self getMediaTrackWithFactoryInit];
    
    [self socketRTCManagerInit];

}

#pragma mark - Initialize
//initData
- (void)initData{
    
    _connectionDic = @{}.mutableCopy;
    _connectionIdArray = @[].mutableCopy;
    _remoteAudioTracks = @{}.mutableCopy;
    
    //keep the screen on
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
}

//getMediaTrackWithFactoryInit
- (void)getMediaTrackWithFactoryInit{
    [RTCPeerConnectionFactory initialize];
        
    if (!_rtcFactory)
        _rtcFactory = [[RTCPeerConnectionFactory alloc]init];
    
    if(!_localStream)
       [self createLocalStreaming];
    
}

//createLocalStreaming
- (void)createLocalStreaming{
    _localStream = [_rtcFactory mediaStreamWithStreamId:@"localStream"];
    
    [self checkMicroPhonePermission];
}

- (void)checkMicroPhonePermission{
    
    AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession
                                                      discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone]
                                                      mediaType:AVMediaTypeAudio position:0];
    
    AVCaptureDevice *device = [deviceSession.devices firstObject];
    
    
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (authStatus == AVAuthorizationStatusDenied || authStatus == AVAuthorizationStatusRestricted)
        NSLog(@"Microphone permission denied.");
    else{
        if (device) {
            
            RTCAudioTrack *audioTrack = [_rtcFactory audioTrackWithTrackId:@"audioTest"];
            [_localStream addAudioTrack:audioTrack];
            
            NSLog(@"setLocalStream");
            
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

- (void)socketRTCManagerInit{
    _socketRTCManager = [SocketRTCManager getInstance];
    _socketRTCManager.delegate = self;
    [_socketRTCManager connect];
}

- (void)exitRoom{
    _localStream = nil;
}

- (void)createPeerConnection{
 
//    _peerConnection = [RTCPeerConnection init];
    
    
}

#pragma mark - IBAction
- (IBAction)muteBtnClick:(UIButton*)sender {
    //init status is selected
    //1.擴音:喇叭圖(unselect)  2.不擴音:斜線喇叭圖(selected)
    bool isLoud = !sender.isSelected;
    
    if (isLoud) {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        // Turn off the speaker
        sender.selected = [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
//            [self.view makeToast:@"關閉擴音"];
    }
    else {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        // Turn on the speaker
        BOOL isSuccess = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        if (isSuccess) {
            sender.selected = !isSuccess;
//            [self.view makeToast:@"開啟擴音"];
        }else{
            NSLog(@"%@",error.description);
        }
    }
}

- (IBAction)joinRoom:(id)sender {

}

#pragma mark - SocketRTCManagerDelegate
- (void)socketConnected:(NSArray*)data{
    _socketStatus.text = @"Socket Connected : 連線成功";
    
    BOOL isJoinSuccessed = [_socketRTCManager createToStreamWithRoomID:@"3345678" targetID:@"530Dev"];
    _socketStatus.text = (isJoinSuccessed)? @"正在加入房間" : @"Socket尚未連接，加入房間失敗";
    
    NSDictionary *dic = data.firstObject;
    
    //get data
    NSDictionary *dataDic = dic[@"data"];
    //get all of connections
    NSArray *connections = dataDic[@"connections"];
    
    //add all of connection to array
    [_connectionIdArray addObjectsFromArray:connections];
    
    //拿到给自己分配的ID
//    _userId = dataDic[@"you"];
    
    //create p2p object base on connectionIDArray
    [_connectionIdArray enumerateObjectsUsingBlock:^(NSString *connectionID, NSUInteger index, BOOL * _Nonnull stop) {
        
        //根据连接ID去初始化 RTCPeerConnection 连接对象
        RTCPeerConnection *connection = [self createPeerConnection:connectionID];
        
        //设置这个ID对应的 RTCPeerConnection对象
        _connectionDic[connectionID] = connection;
    }];
    
    //给每一个点对点连接，都加上本地流
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *connection, BOOL * _Nonnull stop) {
        if (!_localStream)
        {
            [self createLocalStreaming];
        }
        [connection addStream:_localStream];
    }];
    
    //给每一个点对点连接，都去创建offer
    __weak typeof(self) weakSelf = self;
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *connection, BOOL * _Nonnull stop) {
        _mode = 0;
        //添加代理
        connection.delegate = weakSelf;
        [connection offerForConstraints :[self offerOranswerConstraint] completionHandler:nil];
        [connection answerForConstraints:[self offerOranswerConstraint] completionHandler:nil];
    }];
    
}

- (void)socketDisConnected{
    
}

- (void)socketError{
    _socketStatus.text = @"Socket Error : 連線失敗";
}

//stream callback
- (void)streamBusy{
    
}

- (void)streamNoReply{
    
}

- (void)streamStart{
    
}

- (void)streamFinish{
    
}

- (void)streamForceFinish{
    
}

- (void)streamReject{
    
}

- (void)streamRejected{
    
}

- (void)streamCreated{
    
}

- (void)streamJoined{
    
}

- (void)streamCancel{
    
}

#pragma mark - Function
- (RTCPeerConnection*)createPeerConnection:(NSString*)connectionID{
    if(!_rtcFactory){
        [RTCPeerConnectionFactory initialize];
        _rtcFactory = [[RTCPeerConnectionFactory alloc]init];
    }
    
    if(!_ICEServers){
        _ICEServers = @[].mutableCopy;
    }
    
    NSArray *stunServer = @[
                            @"stun:turn.quickblox.com",
                            @"turn:turn.quickblox.com:3478?transport=udp",
                            @"turn:turn.quickblox.com:3478?transport=tcp"
                           ];
    for (NSString *url  in stunServer) {
        [_ICEServers addObject:[self defaultSTUNServer:url]];
        
    }
    
    //用工厂来创建连接
    RTCConfiguration *rtcConfig = [[RTCConfiguration alloc]init];
    [rtcConfig setIceServers:_ICEServers];
    RTCPeerConnection *connection = [_rtcFactory peerConnectionWithConfiguration:rtcConfig constraints:[self peerConnectionConstraints] delegate:self];
    return connection;
    
}

- (RTCMediaConstraints *)peerConnectionConstraints {
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:@{@"DtlsSrtpKeyAgreement":@"true"}];
}

- (RTCICEServer *)defaultSTUNServer:(NSString *)stunURL {
    NSString *userName = [stunURL containsString:@"quickblox"] ? @"quickblox":@"";
    NSString *password = [stunURL containsString:@"quickblox"] ? @"baccb97ba2d92d71e26eb9886da5f1e0":@"";
    return [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:stunURL]
                                    username:userName
                                    password:password];
}

- (RTCMediaConstraints *)offerOranswerConstraint {
    
//    NSMutableArray *audioArr = @[].mutableCopy;
//    RTCPair *receiveAudio = [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"];
//    [audioArr addObject:receiveAudio];
    
//    NSString *video = @"true";
//    RTCPair *receiveVideo = [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:video];
//    [array addObject:receiveVideo];
    
    //回音消除
//    RTCPair *echoCancellation = [[RTCPair alloc] initWithKey:@"VoiceActivityDetection" value:@"false"];
//    [audioArr addObject:echoCancellation];
    
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{@"OfferToReceiveAudio":@"true",@"VoiceActivityDetection":@"false"} optionalConstraints:nil];
}

- (void)closePeerConnection:(NSString *)connectionID{
    RTCPeerConnection *peerConnection = _connectionDic[connectionID];
    
    if (peerConnection)
        [peerConnection close];
    
    [_connectionIdArray removeObject:connectionID];
    [_connectionDic removeObjectForKey:connectionID];
    dispatch_async(dispatch_get_main_queue(), ^{
        //移除对方語音追踪
        [_remoteAudioTracks removeObjectForKey:connectionID];
    });
}

- (void)closeVC{
    [self exitRoom];
    
    [self dismissViewControllerAnimated:true completion:^{
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    }];
}


@end
