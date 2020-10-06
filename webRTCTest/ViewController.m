//
//  ViewController.m
//  webRTCTest
//
//  Created by 吳尚霖 on 7/22/20.
//  Copyright © 2020 SamWu. All rights reserved.
//

#import "ViewController.h"
#import "SocketRTCManager.h"

#import <WebRTC/WebRTC.h>
#import <WebRTC/RTCIceServer.h>
#import <SocketIO-Swift.h>
#import <AVFoundation/AVFoundation.h>


#define STREAM     @"localStream"
#define AUDIOTRACK @"audioTest"

typedef enum : int{
    Caller = 0,
    Receiver = 1,
} Mode;

@interface ViewController ()<SocketRTCManagerDelegate,RTCPeerConnectionDelegate>
@property (strong, nonatomic) IBOutlet UILabel *socketStatus;
@property (strong, nonatomic) IBOutlet UIButton *createRoomBtn;
@property (strong, nonatomic) IBOutlet UITableView *roomTableView;

@property (strong,nonatomic) SocketRTCManager *socketRTCManager;

@property (strong,nonatomic) RTCPeerConnectionFactory *rtcFactory;
@property (strong,nonatomic) RTCPeerConnection *peerConnection;
@property (strong,nonatomic) RTCMediaStream *localStream;

@property (strong, nonatomic) IBOutlet UILabel *offerStatus;
@property (strong, nonatomic) IBOutlet UILabel *answerStatus;

@property (strong,nonatomic) NSMutableDictionary *remoteAudioTracks;
@property (strong,nonatomic) NSMutableDictionary *connectionDic;
@property (strong,nonatomic) NSMutableArray *roomMemberArray;

@property (strong,nonatomic) NSDictionary *startCallDic;

@property (strong,nonatomic) NSMutableArray<NSString*> *roomList;
@property (strong,nonatomic) NSString *socketRoom;
@property (strong,nonatomic) NSString *socketID;
@property (strong,nonatomic) NSString *targetID;
@property (strong,nonatomic) NSString *userID;
@property (strong,nonatomic) NSString *roomID;

@property (strong, nonatomic) IBOutlet UIButton *joinBtn1;

@property (assign,nonatomic) Mode *mode;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self initData];
    
    [self getMediaTrackWithFactoryInit];
    
    [self socketRTCManagerInit];

}

- (void)viewWillDisappear:(BOOL)animated{
    [self closeAll];
}

#pragma mark - Initialize
//initData
- (void)initData{
    
    _connectionDic = @{}.mutableCopy;
    _roomMemberArray = @[].mutableCopy;
    _remoteAudioTracks = @{}.mutableCopy;
    
    [_roomTableView registerNib:[UINib nibWithNibName:@"ViewController" bundle:nil] forCellReuseIdentifier:@"cell"];
    
    //keep the screen on
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
}

//getMediaTrackWithFactoryInit
- (void)getMediaTrackWithFactoryInit{
    if (!_rtcFactory)
        _rtcFactory = [[RTCPeerConnectionFactory alloc]init];
    
    if(!_localStream)
       [self createLocalStream];
    
}

//createLocalStream
- (void)createLocalStream{
    _localStream = [_rtcFactory mediaStreamWithStreamId:STREAM];
    
    [self checkMicroPhonePermission];
}

- (void)checkMicroPhonePermission{
    
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
                   
                   [_localStream addAudioTrack:[_rtcFactory audioTrackWithTrackId:AUDIOTRACK]];
                                      
                   NSLog(@"setLocalStream");
               }
           }
        }];
        
    }
    else{
        if (device) {
        
            [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:nil];

            [_localStream addAudioTrack:[_rtcFactory audioTrackWithTrackId:AUDIOTRACK]];
                        
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

#pragma mark - IBAction
- (IBAction)muteBtnClick:(UIButton*)sender {
    //init status is selected
    //1.擴音:喇叭圖(unselect)  2.不擴音:斜線喇叭圖(selected)
    bool isLoud = !sender.isSelected;
    AVAudioSession *session = [AVAudioSession sharedInstance];

    if (isLoud) {
        
        // Turn off the speaker
        sender.selected = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
        [sender setTitle:@"擴音" forState:UIControlStateNormal];
    }
    else {
        NSError *error = nil;
        // Turn on the speaker
        BOOL isSuccess = [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
        if (isSuccess) {
            sender.selected = !isSuccess;
            [sender setTitle:@"手持" forState:UIControlStateNormal];
        }else{
            NSLog(@"%@",error.description);
        }
    }
}

- (IBAction)createRoom:(id)sender {

    _userID = [[NSUUID new]UUIDString];
    _roomID = @"530TestRoom";
    
    [_socketRTCManager newRoomToStreamWithSocketID:_socketID roomID:_roomID];

}

- (IBAction)joinTestRoom:(UIButton *)sender {
    _socketRoom = [sender.titleLabel.text componentsSeparatedByString:@"+"].firstObject;
    
    BOOL isJoinSuccessed = [_socketRTCManager startCallToStreamWithSocketRoom:_socketRoom SocketID:_socketID];
    
    _socketStatus.text = (isJoinSuccessed)? @"正在建立房間" : @"Socket尚未連接，建立房間失敗";
    
}

- (IBAction)leaveRoom:(id)sender {
    if(!_socketID || !_socketRoom) return;
    NSDictionary *dic = @{@"socketID":_socketID,
                          @"socketRoom":_socketRoom
                         };
    
    [_socketRTCManager leaveRoomToStreamWithDic:dic];

    
}

#pragma mark - createPeerConnection
- (void)processLocalTask:(NSDictionary*)dic{
    
    /** Get all of socketRoomMember */
    _roomMemberArray = [dic[@"socketRoomMember"]allKeys].mutableCopy;
    
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"self == %@",dic[@"socketRoom"]];
    if(![pred evaluateWithObject:_roomMemberArray])
       [_roomMemberArray addObject:dic[@"socketRoom"]];
    
    /** set p2p object to connectionDic */
    [_roomMemberArray enumerateObjectsUsingBlock:^(NSString *connectionID, NSUInteger index, BOOL * _Nonnull stop) {
        if(![connectionID isEqualToString:_socketID]){
            //根据连接ID去初始化 RTCPeerConnection 连接对象
            RTCPeerConnection *peerConnection = [self createPeerConnection];
            
            //设置这个ID对应的 RTCPeerConnection对象
            _connectionDic[connectionID] = peerConnection;
        }
    }];
    
    //set local stream for each peerConnection
    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *connection, BOOL * _Nonnull stop) {
        if (!_localStream)
            [self createLocalStream];
        
        [connection addStream:_localStream];
    }];
    
}

- (RTCPeerConnection*)createPeerConnection{
    if(!_rtcFactory) _rtcFactory = [[RTCPeerConnectionFactory alloc]init];
    
    RTCPeerConnection *peerConnection = [_rtcFactory peerConnectionWithConfiguration:[self setStunServerToICEServer]
                                                                         constraints:[self peerConnectionConstraints]
                                                                            delegate:self];
    return peerConnection;
}

- (RTCConfiguration*)setStunServerToICEServer{
    
    //@"stun:turn.quickblox.com",
    //@"turn:turn.quickblox.com:3478?transport=udp",
    //@"turn:turn.quickblox.com:3478?transport=tcp"
    //NSString *userName = [stunURL containsString:@"quickblox"] ? @"quickblox":@"";
    //NSString *password = [stunURL containsString:@"quickblox"] ? @"baccb97ba2d92d71e26eb9886da5f1e0":@"";
    
    NSArray *stunServers = @[
                            @"stun:stun.l.google.com:19302",
                            @"stun:stun1.l.google.com:19302",
                            @"stun:stun2.l.google.com:19302",
                            @"stun:stun3.l.google.com:19302",
                            @"stun:stun4.l.google.com:19302"
                           ];
    
    RTCConfiguration *rtcConfig = [[RTCConfiguration alloc]init];
    
    [rtcConfig setIceServers:@[[[RTCIceServer alloc]initWithURLStrings:stunServers]]];
    return rtcConfig;
}

- (RTCMediaConstraints *)peerConnectionConstraints {
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:@{@"DtlsSrtpKeyAgreement":@"true"}];
    
    return constraints;
}

/** Generate an SDP offer to Set Local Description for each peerConnection */
- (void)createOfferAndSetSDP{
    
    _mode = 0;
    
    __weak typeof(self) weakSelf = self;

    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *connection, BOOL * _Nonnull stop) {
    
            [connection offerForConstraints:[self offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
                if(error){ NSLog(@"%@",error); return; }
                
                [connection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                    if(error){ NSLog(@"%@",error); return; }
                    
                    NSDictionary *dic = @{@"sdp":sdp.sdp,
                                          @"type":@(sdp.type),
                                          @"roomName":weakSelf.roomID,
                                          @"sender":weakSelf.socketID,
                                          @"receiver":key,
                                          @"socketRoom":weakSelf.socketRoom
                                         };
                    
                    [weakSelf.socketRTCManager sendOfferToStreamWithDic:dic];
                    NSLog(@"===========Send Offer : %@ \nTo : %@\n%@\n===========",weakSelf.socketID,key,dic);
                }];
            }];
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        weakSelf.offerStatus.text = @"Offer emmitted";
        weakSelf.socketStatus.text = @"房間已建立";
    });
    
}

- (RTCMediaConstraints *)offerOranswerConstraint {
    
//    [self unusedFunc];
    
    NSDictionary *dic = @{@"VoiceActivityDetection":@"false"};
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{@"OfferToReceiveAudio":@"true",@"VoiceActivityDetection":@"false"} optionalConstraints:dic];
}

#pragma mark - SocketRTCManagerDelegate
- (void)socketConnected:(NSArray*)data{
    _socketStatus.text = @"Socket Connected : 連線成功";
}

//socket connect and get self socketID
- (void)streamConnectedData:(NSArray *)data{
    
    _socketID = data.firstObject[@"socketID"];
    
    [_createRoomBtn setHidden:false];
}

//加入房間
- (void)streamReceiveStartCall:(NSArray *)data{
    NSLog(@"%s",__func__);
    [self processLocalTask:data.firstObject];
    [self createOfferAndSetSDP];
}

- (void)streamReceiveNewRoom:(NSArray *)data{
    _roomList = data.firstObject[@"roomList"];
    if(_roomList.count>0){
//        _roomID = [_roomList.firstObject componentsSeparatedByString:@"+"].lastObject;
        for(NSString *str in _roomList){
            if([[str componentsSeparatedByString:@"+"].firstObject isEqualToString:_socketID]){
                _socketRoom = _socketID;
                break;
            }
        }
        
        [_roomTableView reloadData];
        
        NSString *roomName = _roomList.firstObject;
        if([roomName containsString:@"530Test"]){
            [_joinBtn1 setTitle:roomName forState:UIControlStateNormal] ;
            _joinBtn1.hidden = false;
            
        }
    }
}

- (NSMutableArray *)getRoomMemberArr:(NSArray *)data {
    NSMutableArray<NSString*> *arr = [data.lastObject[@"socketRoomMember"]allKeys].mutableCopy;

    for(int i=0; i<arr.count; i++){
        if([arr[i] isEqualToString:_socketID]){
            [arr removeObjectAtIndex:i];
            return arr;
        }
    }
    
    return arr;
}

- (void)streamReceiveOffer:(NSArray *)data{

    NSDictionary *dic = data.firstObject[@"data"];

    NSString *sender = dic[@"sender"];

    if([_socketID isEqualToString:sender] && ![_socketID isEqualToString:dic[@"receiver"]]) return;
    
    NSLog(@"%s\nSocketID : %@\ntargetSocket : %@",__func__,_socketID,sender);

    _socketRoom = dic[@"socketRoom"];
    
    _offerStatus.text = [NSString stringWithFormat:@"Offer received\n\n%@",sender];
    
    __weak typeof(self) weakSelf = self;
    
    if (!_localStream)
        [self createLocalStream];
    
     RTCPeerConnection __weak *connection = _connectionDic[sender];
       
       if(!connection){
           connection = [self createPeerConnection];
           [connection addStream:_localStream];
           _connectionDic[sender] = connection;
       }
    
    RTCSessionDescription *sdp = [[RTCSessionDescription alloc]initWithType:[dic[@"type"]integerValue] sdp:dic[@"sdp"]];
    
    NSLog(@"===========Receive Offer From : %@\nsdpType : %ld\n%@\n===========",sender,(long)[dic[@"type"]integerValue],dic[@"sdp"]);
    
    [connection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
        if(error){
            NSLog(@"%@",error);
            return;
        }
        [connection answerForConstraints:[weakSelf offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            if(error){
                NSLog(@"%@",error);
                return;
            }
            
            [connection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                if(error){
                    NSLog(@"%@",error);
                    return;
                }
                
                NSDictionary *dic = @{@"sdp":sdp.sdp,
                                      @"type":@(sdp.type),
                                      @"sender":weakSelf.socketID,
                                      @"receiver":sender,
                                      @"socketRoom":weakSelf.socketRoom
                                     };
                
                [weakSelf.socketRTCManager answerToStreamWithDic:dic];
                NSLog(@"===========Send Answer From : %@ \n%@\n===========",weakSelf.socketID,dic);
                
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    weakSelf.answerStatus.text = @"Answer emitted";
                    weakSelf.socketStatus.text = [NSString stringWithFormat:@"於%@房間中",weakSelf.roomID];
                });
                
            }];
        }];
    }];
}

- (void)streamReceiveAnswer:(NSArray *)data{

    NSDictionary *dic = data.firstObject[@"data"];

    NSString *sender = dic[@"sender"];
    
    if([_socketID isEqualToString:sender] && ![_socketID isEqualToString:dic[@"receiver"]]) return;
    
    __weak typeof(self) weakSelf = self;
        
    RTCPeerConnection *connection = _connectionDic[sender];
    
    if(!connection){
        connection = [self createPeerConnection];
        [connection addStream:_localStream];
        _connectionDic[sender] = connection;
    }
    
    RTCSessionDescription *sdp = [[RTCSessionDescription alloc]initWithType:[dic[@"type"]integerValue] sdp:dic[@"sdp"]];
    
    NSLog(@"===========Receive Answer From: %@\nsdpType : %ld\n%@\n===========",sender,(long)[dic[@"type"]integerValue],dic[@"sdp"]);

    if(connection.remoteDescription) return;
    
    NSLog(@"%s\nSocketID : %@\ntargetSocket : %@",__func__,_socketID,sender);

    _answerStatus.text = [NSString stringWithFormat:@"Answer received\n\n%@",sender];
    
    [connection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(error){
                NSLog(@"%@",error);
                weakSelf.socketStatus.text = [NSString stringWithFormat:@"於%@房間中發生錯誤\n%@",weakSelf.roomID,error];
            }else
                weakSelf.socketStatus.text = [NSString stringWithFormat:@"於%@房間中",weakSelf.roomID];

        });
    }];
}

- (void)streamReceiveCandidates:(NSArray *)data{

    NSDictionary *dic = data.firstObject[@"data"];

    NSString *sender = dic[@"sender"];
    
    if([_socketID isEqualToString:sender] && ![_socketID isEqualToString:dic[@"receiver"]]) return;

    NSLog(@"%s\nSocketID : %@\ntargetSocket : %@",__func__,_socketID,sender);

    RTCIceCandidate *candidate = [[RTCIceCandidate alloc]initWithSdp:dic[@"candidateSdp"] sdpMLineIndex:[dic[@"sdpMLineIndex"]intValue] sdpMid:dic[@"sdpMid"]];
    
    NSLog(@"init candidate done !");
    
    RTCPeerConnection *connection = _connectionDic[sender];
    
    NSLog(@"get connection !");
    
    [connection addIceCandidate:candidate];
    
    NSLog(@"addIceCandidate !");
}

- (void)socketDisConnected{
    
}

- (void)socketError{
    _socketStatus.text = @"Socket Error : 連線失敗";
    [self closeAll];
}

- (void)streamLeaveRoom:(NSArray*)data{
    NSDictionary *dic = data.firstObject;
    NSString *socketRoom = dic[@"socketRoom"];
    NSString *socketID = dic[@"socketID"];
        
    if([socketID isEqualToString:socketRoom]){
        _localStream = nil;
        _connectionDic = nil;
        _roomMemberArray = nil;
        
        for(int i=0; i<_roomList.count; i++){
            if([_roomList[i] containsString:socketRoom]){
                [_roomList removeObjectAtIndex:i];
                break;
            }
        }
        
        [_joinBtn1 setHidden:true];
    }else{
        [_connectionDic removeObjectForKey:socketID];
        
        [_roomMemberArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            if([obj isEqualToString:socketID]){
                [_roomMemberArray removeObjectAtIndex:idx];
                return;
            }
        }];
    }
    
    _socketStatus.text = @"Socket Connected : 連線成功";

    [_roomTableView reloadData];
}

#pragma mark - RTCPeerConnectionDelegate
/** Called when media is received on a new stream from remote peer. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream{
    NSLog(@"%s",__func__);
    
    NSString *connectionID = [self getKeyFromConnectionDic:peerConnection];

    dispatch_async(dispatch_get_main_queue(), ^{
        //缓存起来
        _remoteAudioTracks[connectionID] = stream.audioTracks.lastObject;
                
        NSLog(@"connectionID : %@",connectionID);
        
        NSLog(@"remoteAudioTracks : %@",_remoteAudioTracks);
        
        NSLog(@"_remoteAudioTracks set audioTracks !");
        
        //speaker default is closed
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    });
    
    NSLog(@"addRemoteStream");
}

/** New ice candidate has been found. */
//创建peerConnection之后，从server得到响应后调用，得到ICE 候选地址
- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate{
    NSLog(@"%s",__func__);
        
    NSString *connectionID = [self getKeyFromConnectionDic:peerConnection];
    
    [_socketRTCManager sendCandidatesToStreamWithDic:@{@"sdpMid":candidate.sdpMid,
                                                                  @"sdpMLineIndex": @(candidate.sdpMLineIndex),
                                                                  @"candidateSdp": candidate.sdp,
                                                                  @"sender": _socketID,
                                                                  @"receiver":connectionID,
                                                                  @"socketRoom": _socketRoom
                                                                 
                                                      }];
}


#pragma mark - TableView delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _roomList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    
    NSArray *result = [_roomList[indexPath.row] componentsSeparatedByString:@"+"];
    NSString *owner = result.firstObject;
    NSString *roomName = result.lastObject;
    
    cell.textLabel.text = roomName;
    cell.detailTextLabel.text = owner;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    _socketRoom = [_roomList[indexPath.row] componentsSeparatedByString:@"+"].firstObject;
    _roomID = [_roomList[indexPath.row] componentsSeparatedByString:@"+"].lastObject;
    
    BOOL isJoinSuccessed = [_socketRTCManager startCallToStreamWithSocketRoom:_socketRoom SocketID:_socketID];
    
    _socketStatus.text = (isJoinSuccessed)? @"正在建立房間" : @"Socket尚未連接，建立房間失敗";
}

#pragma mark - Function
- (NSString *)getKeyFromConnectionDic:(RTCPeerConnection *)peerConnection{

    //find socketID by peerConnection
    static NSString *socketId;

    [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
        if ([obj isEqual:peerConnection])
        {
            NSLog(@"%@",key);
            socketId = key;
        }
    }];
    return socketId;
}

- (void)closePeerConnection:(NSString *)connectionID{
    RTCPeerConnection *connection = _connectionDic[connectionID];

    if (connection)
        [connection close];

    [_roomMemberArray removeObject:connectionID];
    [_connectionDic removeObjectForKey:connectionID];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        //移除語音追踪
        [_remoteAudioTracks removeObjectForKey:connectionID];
    });
}

- (void)exitRoom{
    [self closeAll];
}

- (void)closeVC{
    [self exitRoom];
    
    [self dismissViewControllerAnimated:true completion:^{
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    }];
}

- (void)closeAll{
    _localStream = nil;
    
    [_roomMemberArray enumerateObjectsUsingBlock:^(NSString *connectionID, NSUInteger idx, BOOL * _Nonnull stop) {
        [self closePeerConnection:connectionID];
    }];
    
    [_socketRTCManager killHandlerAndDisConnect];
}

- (void)unusedFunc{
    //    NSMutableArray *audioArr = @[].mutableCopy;
    //    RTCPair *receiveAudio = [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"];
    //    [audioArr addObject:receiveAudio];
        
    //    NSString *video = @"true";
    //    RTCPair *receiveVideo = [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:video];
    //    [array addObject:receiveVideo];
        
        //回音消除
    //    RTCPair *echoCancellation = [[RTCPair alloc] initWithKey:@"VoiceActivityDetection" value:@"false"];
    //    [audioArr addObject:echoCancellation];
}

/** Called when the SignalingState changed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged{
    NSLog(@"%s",__func__);
    NSLog(@"stateChanged = %ld", (long)stateChanged);
}

/** Called when a remote peer closes a stream. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream{
    NSLog(@"%s",__func__);
}

/** Called when negotiation is needed, for example ICE has restarted. */
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection{
    NSLog(@"%s",__func__);
}

/** Called any time the IceConnectionState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState{
    NSLog(@"%s : %ld",__func__,(long)newState);
}

/** Called any time the IceGatheringState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState{
    NSLog(@"%s : %ld",__func__,(long)newState);
}

/** Called when a group of local Ice candidates have been removed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates{
    NSLog(@"%s : %@",__func__,candidates);
}

/** New data channel has been opened. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel{
    NSLog(@"%s",__func__);
}

@end
//
// //
// //  ViewController.m
// //  webRTCTest
// //
// //  Created by 吳尚霖 on 7/22/20.
// //  Copyright © 2020 SamWu. All rights reserved.
// //
//
// #import "ViewController.h"
// #import "SocketRTCManager.h"
//
// #import <WebRTC/WebRTC.h>
// #import <WebRTC/RTCIceServer.h>
// #import <SocketIO-Swift.h>
// #import <AVFoundation/AVFoundation.h>
//
//
// #define STREAM     @"localStream"
// #define AUDIOTRACK @"audioTest"
//
// typedef enum : int{
//     Caller = 0,
//     Receiver = 1,
// } Mode;
//
// @interface ViewController ()<SocketRTCManagerDelegate,RTCPeerConnectionDelegate>
// @property (strong, nonatomic) IBOutlet UILabel *socketStatus;
// @property (strong, nonatomic) IBOutlet UIButton *createRoomBtn;
// @property (strong, nonatomic) IBOutlet UITableView *roomTableView;
//
// @property (strong,nonatomic) SocketRTCManager *socketRTCManager;
//
// @property (strong,nonatomic) RTCPeerConnectionFactory *rtcFactory;
// @property (strong,nonatomic) RTCPeerConnection *peerConnection;
// @property (strong,nonatomic) RTCMediaStream *localStream;
//
// @property (strong, nonatomic) IBOutlet UILabel *offerStatus;
// @property (strong, nonatomic) IBOutlet UILabel *answerStatus;
//
// @property (strong,nonatomic) NSMutableDictionary *remoteAudioTracks;
// @property (strong,nonatomic) NSMutableDictionary *connectionDic;
// @property (strong,nonatomic) NSMutableArray *roomMemberArray;
//
// @property (strong,nonatomic) NSDictionary *startCallDic;
//
// @property (strong,nonatomic) NSMutableArray<NSString*> *roomList;
// @property (strong,nonatomic) NSString *socketRoom;
// @property (strong,nonatomic) NSString *socketID;
// @property (strong,nonatomic) NSString *targetID;
// @property (strong,nonatomic) NSString *userID;
// @property (strong,nonatomic) NSString *roomID;
//
// @property (strong, nonatomic) IBOutlet UIButton *joinBtn1;
//
// @property (assign,nonatomic) Mode *mode;
//
// @end
//
// @implementation ViewController
//
// - (void)viewDidLoad {
//     [super viewDidLoad];
//
//     [self initData];
//
//     [self getMediaTrackWithFactoryInit];
//
//     [self socketRTCManagerInit];
//
// }
//
// - (void)viewWillDisappear:(BOOL)animated{
//     [self closeAll];
// }
//
// #pragma mark - Initialize
// //initData
// - (void)initData{
//
//     _connectionDic = @{}.mutableCopy;
//     _roomMemberArray = @[].mutableCopy;
//     _remoteAudioTracks = @{}.mutableCopy;
//
//     [_roomTableView registerNib:[UINib nibWithNibName:@"ViewController" bundle:nil] forCellReuseIdentifier:@"cell"];
//
//     //keep the screen on
//     [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
//
// }
//
// //getMediaTrackWithFactoryInit
// - (void)getMediaTrackWithFactoryInit{
//     if (!_rtcFactory)
//         _rtcFactory = [[RTCPeerConnectionFactory alloc]init];
//
//     if(!_localStream)
//        [self createLocalStream];
//
// }
//
// //createLocalStream
// - (void)createLocalStream{
//     _localStream = [_rtcFactory mediaStreamWithStreamId:STREAM];
//
//     [self checkMicroPhonePermission];
// }
//
// - (void)checkMicroPhonePermission{
//
//     AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession
//                                                       discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone]
//                                                       mediaType:AVMediaTypeAudio position:0];
//
//     AVCaptureDevice *device = [deviceSession.devices firstObject];
//
//
//     AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
//     if (authStatus == AVAuthorizationStatusDenied || authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusNotDetermined){
//         [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
//            if(!granted)
//                NSLog(@"Microphone permission denied.");
//            else{
//                if (device) {
//
//                    [[AVAudioSession sharedInstance]setActive:false error:nil];
//                    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionMixWithOthers error:nil];
//
//                    [_localStream addAudioTrack:[_rtcFactory audioTrackWithTrackId:AUDIOTRACK]];
//
//                    NSLog(@"setLocalStream");
//                }
//            }
//         }];
//
//     }
//     else{
//         if (device) {
//
//             [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:nil];
//
//             [_localStream addAudioTrack:[_rtcFactory audioTrackWithTrackId:AUDIOTRACK]];
//
//             NSLog(@"setLocalStream");
//
//         }else
//             NSLog(@"Microphone cannot open in this device.");
//     }
//
//     //Video
//                    /*
//                    RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:device.localizedName];
//                    RTCVideoSource *videoSource = [_factory videoSourceWithCapturer:capturer constraints:[self localVideoConstraints]];
//                     */
//
//     //               RTCAVFoundationVideoSource *videoSource = [[RTCAVFoundationVideoSource alloc] initWithFactory:_factory constraints:[self localVideoConstraints]];
//     //               _localVideoSource = videoSource;
//     //               RTCVideoTrack *videoTrack = [_factory videoTrackWithID:@"ARDAMSv0" source:videoSource];
//     //               [_localStream addVideoTrack:videoTrack];
//
//
//     //               //显示本地流
//     //               RTCEAGLVideoView *localVideoView = [[RTCEAGLVideoView alloc] init];
//     //               localVideoView.frame = CGRectMake(0, 60, 375/2.0, 375/2.0*1.3);
//     //               //标记摄像头
//     //               localVideoView.tag = 100;
//     //               //摄像头旋转
//     //               localVideoView.transform = CGAffineTransformMakeScale(-1.0, 1.0);
//     //               _localVideoTrack = [_localStream.videoTracks lastObject];
//     //               [_localVideoTrack addRenderer:localVideoView];
//     //               [self.view addSubview:localVideoView];
//
//
//    /**/
// }
//
// - (void)socketRTCManagerInit{
//     _socketRTCManager = [SocketRTCManager getInstance];
//     _socketRTCManager.delegate = self;
//     [_socketRTCManager connect];
// }
//
// #pragma mark - IBAction
// - (IBAction)muteBtnClick:(UIButton*)sender {
//     //init status is selected
//     //1.擴音:喇叭圖(unselect)  2.不擴音:斜線喇叭圖(selected)
//     bool isLoud = !sender.isSelected;
//     AVAudioSession *session = [AVAudioSession sharedInstance];
//
//     if (isLoud) {
//
//         // Turn off the speaker
//         sender.selected = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
//         [sender setTitle:@"擴音" forState:UIControlStateNormal];
//     }
//     else {
//         NSError *error = nil;
//         // Turn on the speaker
//         BOOL isSuccess = [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
//         if (isSuccess) {
//             sender.selected = !isSuccess;
//             [sender setTitle:@"手持" forState:UIControlStateNormal];
//         }else{
//             NSLog(@"%@",error.description);
//         }
//     }
// }
//
// - (IBAction)createRoom:(id)sender {
//
//     _userID = [[NSUUID new]UUIDString];
//     _roomID = @"530TestRoom";
//
//     [_socketRTCManager newRoomToStreamWithSocketID:_socketID roomID:_roomID];
//
// }
//
// - (IBAction)joinTestRoom:(UIButton *)sender {
//     _socketRoom = [sender.titleLabel.text componentsSeparatedByString:@"+"].firstObject;
//
//     BOOL isJoinSuccessed = [_socketRTCManager startCallToStreamWithSocketRoom:_socketRoom SocketID:_socketID];
//
//     _socketStatus.text = (isJoinSuccessed)? @"正在建立房間" : @"Socket尚未連接，建立房間失敗";
//
// }
//
// - (IBAction)leaveRoom:(id)sender {
//     if(!_socketID || !_socketRoom) return;
//     NSDictionary *dic = @{@"socketID":_socketID,
//                           @"socketRoom":_socketRoom
//                          };
//
//     [_socketRTCManager leaveRoomToStreamWithDic:dic];
//
//
// }
//
// #pragma mark - createPeerConnection
// // 2.
// - (void)processLocalTask:(NSDictionary*)dic{
//
//     /** Get all of socketRoomMember */
//     _roomMemberArray = [dic[@"socketRoomMember"]allKeys].mutableCopy;
//
//     NSPredicate *pred = [NSPredicate predicateWithFormat:@"self == %@",dic[@"socketRoom"]];
//     if(![pred evaluateWithObject:_roomMemberArray])
//        [_roomMemberArray addObject:dic[@"socketRoom"]];
//
//     /** set p2p object to connectionDic */
//     [_roomMemberArray enumerateObjectsUsingBlock:^(NSString *connectionID, NSUInteger index, BOOL * _Nonnull stop) {
//         if(![connectionID isEqualToString:_socketID]){
//             //根据连接ID去初始化 RTCPeerConnection 连接对象
//             RTCPeerConnection *peerConnection = [self createPeerConnection];
//
//             //设置这个ID对应的 RTCPeerConnection对象
//             _connectionDic[connectionID] = peerConnection;
//         }
//     }];
//
//     //3.
//     //set local stream for each peerConnection
//     [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *connection, BOOL * _Nonnull stop) {
//         if (!_localStream)
//             [self createLocalStream];
//
//         [connection addStream:_localStream];
//     }];
//
// }
//
// // 6.
// - (RTCPeerConnection*)createPeerConnection{
//     if(!_rtcFactory) _rtcFactory = [[RTCPeerConnectionFactory alloc]init];
//
//     RTCPeerConnection *peerConnection = [_rtcFactory peerConnectionWithConfiguration:[self setStunServerToICEServer]
//                                                                          constraints:[self peerConnectionConstraints]
//                                                                             delegate:self];
//     return peerConnection;
// }
//
// - (RTCConfiguration*)setStunServerToICEServer{
//
//     //@"stun:turn.quickblox.com",
//     //@"turn:turn.quickblox.com:3478?transport=udp",
//     //@"turn:turn.quickblox.com:3478?transport=tcp"
//     //NSString *userName = [stunURL containsString:@"quickblox"] ? @"quickblox":@"";
//     //NSString *password = [stunURL containsString:@"quickblox"] ? @"baccb97ba2d92d71e26eb9886da5f1e0":@"";
//
//     NSArray *stunServers = @[
//                             @"stun:stun.l.google.com:19302",
//                             @"stun:stun1.l.google.com:19302",
//                             @"stun:stun2.l.google.com:19302",
//                             @"stun:stun3.l.google.com:19302",
//                             @"stun:stun4.l.google.com:19302"
//                            ];
//
//     RTCConfiguration *rtcConfig = [[RTCConfiguration alloc]init];
//
//     [rtcConfig setIceServers:@[[[RTCIceServer alloc]initWithURLStrings:stunServers]]];
//     return rtcConfig;
// }
//
// - (RTCMediaConstraints *)peerConnectionConstraints {
//     RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:@{@"DtlsSrtpKeyAgreement":@"true"}];
//
//     return constraints;
// }
//
// // 4.
// /** Generate an SDP offer to Set Local Description for each peerConnection */
// - (void)createOfferAndSetSDP{
//
//     _mode = 0;
//
//     __weak typeof(self) weakSelf = self;
//
//     [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *connection, BOOL * _Nonnull stop) {
//
//             [connection offerForConstraints:[self offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
//                 if(error){ NSLog(@"%@",error); return; }
//
//                 // 5.
//                 [connection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
//                     if(error){ NSLog(@"%@",error); return; }
//
//                     NSDictionary *dic = @{@"sdp":sdp.sdp,
//                                           @"type":@(sdp.type),
//                                           @"roomName":weakSelf.roomID,
//                                           @"sender":weakSelf.socketID,
//                                           @"receiver":key,
//                                           @"socketRoom":weakSelf.socketRoom
//                                          };
//
//                     // 7.
//                     [weakSelf.socketRTCManager sendOfferToStreamWithDic:dic];
//                     NSLog(@"===========Send Offer : %@ \nTo : %@\n%@\n===========",weakSelf.socketID,key,dic);
//                 }];
//             }];
//     }];
//
//     dispatch_async(dispatch_get_main_queue(), ^{
//         weakSelf.offerStatus.text = @"Offer emmitted";
//         weakSelf.socketStatus.text = @"房間已建立";
//     });
//
// }
//
// - (RTCMediaConstraints *)offerOranswerConstraint {
//
// //    [self unusedFunc];
//
//     NSDictionary *dic = @{@"VoiceActivityDetection":@"false"};
//     return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{@"OfferToReceiveAudio":@"true",@"VoiceActivityDetection":@"false"} optionalConstraints:dic];
// }
//
// #pragma mark - SocketRTCManagerDelegate
// // 1.
// - (void)socketConnected:(NSArray*)data{
//     _socketStatus.text = @"Socket Connected : 連線成功";
// }
//
// // socket connect and get self socketID
// - (void)streamConnectedData:(NSArray *)data{
//
//     _socketID = data.firstObject[@"socketID"];
//
//     [_createRoomBtn setHidden:false];
// }
//
// // 加入房間
// - (void)streamReceiveStartCall:(NSArray *)data{
//     NSLog(@"%s",__func__);
//     [self processLocalTask:data.firstObject];
//     [self createOfferAndSetSDP];
// }
//
// // 有新房間時刷新tableView
// - (void)streamReceiveNewRoom:(NSArray *)data{
//     _roomList = data.firstObject[@"roomList"];
//     if(_roomList.count>0){
// //        _roomID = [_roomList.firstObject componentsSeparatedByString:@"+"].lastObject;
//         for(NSString *str in _roomList){
//             if([[str componentsSeparatedByString:@"+"].firstObject isEqualToString:_socketID]){
//                 _socketRoom = _socketID;
//                 break;
//             }
//         }
//
//         [_roomTableView reloadData];
//
//         NSString *roomName = _roomList.firstObject;
//         if([roomName containsString:@"530Test"]){
//             [_joinBtn1 setTitle:roomName forState:UIControlStateNormal] ;
//             _joinBtn1.hidden = false;
//
//         }
//     }
// }
//
// - (NSMutableArray *)getRoomMemberArr:(NSArray *)data {
//     NSMutableArray<NSString*> *arr = [data.lastObject[@"socketRoomMember"]allKeys].mutableCopy;
//
//     for(int i=0; i<arr.count; i++){
//         if([arr[i] isEqualToString:_socketID]){
//             [arr removeObjectAtIndex:i];
//             return arr;
//         }
//     }
//
//     return arr;
// }
//
// // 收到其他人offer
// - (void)streamReceiveOffer:(NSArray *)data{
//
//     NSDictionary *dic = data.firstObject[@"data"];
//
//     NSString *sender = dic[@"sender"];
//
//     if([_socketID isEqualToString:sender] && ![_socketID isEqualToString:dic[@"receiver"]]) return;
//
//     NSLog(@"%s\nSocketID : %@\ntargetSocket : %@",__func__,_socketID,sender);
//
//     _socketRoom = dic[@"socketRoom"];
//
//     _offerStatus.text = [NSString stringWithFormat:@"Offer received\n\n%@",sender];
//
//     __weak typeof(self) weakSelf = self;
//
//     if (!_localStream)
//         [self createLocalStream];
//
//      RTCPeerConnection __weak *connection = _connectionDic[sender];
//
//        if(!connection){
//            connection = [self createPeerConnection];
//            [connection addStream:_localStream];
//            _connectionDic[sender] = connection;
//        }
//
//     RTCSessionDescription *sdp = [[RTCSessionDescription alloc]initWithType:[dic[@"type"]integerValue] sdp:dic[@"sdp"]];
//
//     NSLog(@"===========Receive Offer From : %@\nsdpType : %ld\n%@\n===========",sender,(long)[dic[@"type"]integerValue],dic[@"sdp"]);
//
//     [connection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
//         if(error){
//             NSLog(@"%@",error);
//             return;
//         }
//         [connection answerForConstraints:[weakSelf offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
//             if(error){
//                 NSLog(@"%@",error);
//                 return;
//             }
//
//             [connection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
//                 if(error){
//                     NSLog(@"%@",error);
//                     return;
//                 }
//
//                 NSDictionary *dic = @{@"sdp":sdp.sdp,
//                                       @"type":@(sdp.type),
//                                       @"sender":weakSelf.socketID,
//                                       @"receiver":sender,
//                                       @"socketRoom":weakSelf.socketRoom
//                                      };
//
//                 [weakSelf.socketRTCManager answerToStreamWithDic:dic];
//                 NSLog(@"===========Send Answer From : %@ \n%@\n===========",weakSelf.socketID,dic);
//
//
//                 dispatch_async(dispatch_get_main_queue(), ^{
//                     weakSelf.answerStatus.text = @"Answer emitted";
//                     weakSelf.socketStatus.text = [NSString stringWithFormat:@"於%@房間中",weakSelf.roomID];
//                 });
//
//             }];
//         }];
//     }];
// }
//
// - (void)streamReceiveAnswer:(NSArray *)data{
//
//     NSDictionary *dic = data.firstObject[@"data"];
//
//     NSString *sender = dic[@"sender"];
//
//     if([_socketID isEqualToString:sender] && ![_socketID isEqualToString:dic[@"receiver"]]) return;
//
//     __weak typeof(self) weakSelf = self;
//
//     RTCPeerConnection *connection = _connectionDic[sender];
//
//     if(!connection){
//         connection = [self createPeerConnection];
//         [connection addStream:_localStream];
//         _connectionDic[sender] = connection;
//     }
//
//     RTCSessionDescription *sdp = [[RTCSessionDescription alloc]initWithType:[dic[@"type"]integerValue] sdp:dic[@"sdp"]];
//
//     NSLog(@"===========Receive Answer From: %@\nsdpType : %ld\n%@\n===========",sender,(long)[dic[@"type"]integerValue],dic[@"sdp"]);
//
//     if(connection.remoteDescription) return;
//
//     NSLog(@"%s\nSocketID : %@\ntargetSocket : %@",__func__,_socketID,sender);
//
//     _answerStatus.text = [NSString stringWithFormat:@"Answer received\n\n%@",sender];
//
//     [connection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
//         dispatch_async(dispatch_get_main_queue(), ^{
//             if(error){
//                 NSLog(@"%@",error);
//                 weakSelf.socketStatus.text = [NSString stringWithFormat:@"於%@房間中發生錯誤\n%@",weakSelf.roomID,error];
//             }else
//                 weakSelf.socketStatus.text = [NSString stringWithFormat:@"於%@房間中",weakSelf.roomID];
//
//         });
//     }];
// }
//
// - (void)streamReceiveCandidates:(NSArray *)data{
//
//     NSDictionary *dic = data.firstObject[@"data"];
//
//     NSString *sender = dic[@"sender"];
//
//     if([_socketID isEqualToString:sender] && ![_socketID isEqualToString:dic[@"receiver"]]) return;
//
//     NSLog(@"%s\nSocketID : %@\ntargetSocket : %@",__func__,_socketID,sender);
//
//     RTCIceCandidate *candidate = [[RTCIceCandidate alloc]initWithSdp:dic[@"candidateSdp"] sdpMLineIndex:[dic[@"sdpMLineIndex"]intValue] sdpMid:dic[@"sdpMid"]];
//
//     NSLog(@"init candidate done !");
//
//     RTCPeerConnection *connection = _connectionDic[sender];
//
//     NSLog(@"get connection !");
//
//     [connection addIceCandidate:candidate];
//
//     NSLog(@"addIceCandidate !");
// }
//
// - (void)socketDisConnected{
//
// }
//
// - (void)socketError{
//     _socketStatus.text = @"Socket Error : 連線失敗";
//     [self closeAll];
// }
//
// - (void)streamLeaveRoom:(NSArray*)data{
//     NSDictionary *dic = data.firstObject;
//     NSString *socketRoom = dic[@"socketRoom"];
//     NSString *socketID = dic[@"socketID"];
//
//     if([socketID isEqualToString:socketRoom]){
//         _localStream = nil;
//         _connectionDic = nil;
//         _roomMemberArray = nil;
//
//         for(int i=0; i<_roomList.count; i++){
//             if([_roomList[i] containsString:socketRoom]){
//                 [_roomList removeObjectAtIndex:i];
//                 break;
//             }
//         }
//
//         [_joinBtn1 setHidden:true];
//     }else{
//         [_connectionDic removeObjectForKey:socketID];
//
//         [_roomMemberArray enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
//             if([obj isEqualToString:socketID]){
//                 [_roomMemberArray removeObjectAtIndex:idx];
//                 return;
//             }
//         }];
//     }
//
//     _socketStatus.text = @"Socket Connected : 連線成功";
//
//     [_roomTableView reloadData];
// }
//
// #pragma mark - RTCPeerConnectionDelegate
// /** Called when media is received on a new stream from remote peer. */
// - (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream{
//     NSLog(@"%s",__func__);
//
//     NSString *connectionID = [self getKeyFromConnectionDic:peerConnection];
//
//     dispatch_async(dispatch_get_main_queue(), ^{
//         //缓存起来
//         _remoteAudioTracks[connectionID] = stream.audioTracks.lastObject;
//
//         NSLog(@"connectionID : %@",connectionID);
//
//         NSLog(@"remoteAudioTracks : %@",_remoteAudioTracks);
//
//         NSLog(@"_remoteAudioTracks set audioTracks !");
//
//         //speaker default is closed
//         [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
//     });
//
//     NSLog(@"addRemoteStream");
// }
//
// /** New ice candidate has been found. */
// //创建peerConnection之后，从server得到响应后调用，得到ICE 候选地址
// - (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate{
//     NSLog(@"%s",__func__);
//
//     NSString *connectionID = [self getKeyFromConnectionDic:peerConnection];
//
//     [_socketRTCManager sendCandidatesToStreamWithDic:@{@"sdpMid":candidate.sdpMid,
//                                                                   @"sdpMLineIndex": @(candidate.sdpMLineIndex),
//                                                                   @"candidateSdp": candidate.sdp,
//                                                                   @"sender": _socketID,
//                                                                   @"receiver":connectionID,
//                                                                   @"socketRoom": _socketRoom
//
//                                                       }];
// }
//
//
// #pragma mark - TableView delegate
// - (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
//     return _roomList.count;
// }
//
// - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
//     UITableViewCell *cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
//
//     NSArray *result = [_roomList[indexPath.row] componentsSeparatedByString:@"+"];
//     NSString *owner = result.firstObject;
//     NSString *roomName = result.lastObject;
//
//     cell.textLabel.text = roomName;
//     cell.detailTextLabel.text = owner;
//
//     return cell;
// }
//
// - (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
//
//     _socketRoom = [_roomList[indexPath.row] componentsSeparatedByString:@"+"].firstObject;
//     _roomID = [_roomList[indexPath.row] componentsSeparatedByString:@"+"].lastObject;
//
//     BOOL isJoinSuccessed = [_socketRTCManager startCallToStreamWithSocketRoom:_socketRoom SocketID:_socketID];
//
//     _socketStatus.text = (isJoinSuccessed)? @"正在建立房間" : @"Socket尚未連接，建立房間失敗";
// }
//
// #pragma mark - Function
// - (NSString *)getKeyFromConnectionDic:(RTCPeerConnection *)peerConnection{
//
//     //find socketID by peerConnection
//     static NSString *socketId;
//
//     [_connectionDic enumerateKeysAndObjectsUsingBlock:^(NSString *key, RTCPeerConnection *obj, BOOL * _Nonnull stop) {
//         if ([obj isEqual:peerConnection])
//         {
//             NSLog(@"%@",key);
//             socketId = key;
//         }
//     }];
//     return socketId;
// }
//
// - (void)closePeerConnection:(NSString *)connectionID{
//     RTCPeerConnection *connection = _connectionDic[connectionID];
//
//     if (connection)
//         [connection close];
//
//     [_roomMemberArray removeObject:connectionID];
//     [_connectionDic removeObjectForKey:connectionID];
//
//     dispatch_async(dispatch_get_main_queue(), ^{
//         //移除語音追踪
//         [_remoteAudioTracks removeObjectForKey:connectionID];
//     });
// }
//
// - (void)exitRoom{
//     [self closeAll];
// }
//
// - (void)closeVC{
//     [self exitRoom];
//
//     [self dismissViewControllerAnimated:true completion:^{
//         [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
//         [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
//     }];
// }
//
// - (void)closeAll{
//     _localStream = nil;
//
//     [_roomMemberArray enumerateObjectsUsingBlock:^(NSString *connectionID, NSUInteger idx, BOOL * _Nonnull stop) {
//         [self closePeerConnection:connectionID];
//     }];
//
//     [_socketRTCManager killHandlerAndDisConnect];
// }
//
// - (void)unusedFunc{
//     //    NSMutableArray *audioArr = @[].mutableCopy;
//     //    RTCPair *receiveAudio = [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"];
//     //    [audioArr addObject:receiveAudio];
//
//     //    NSString *video = @"true";
//     //    RTCPair *receiveVideo = [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:video];
//     //    [array addObject:receiveVideo];
//
//         //回音消除
//     //    RTCPair *echoCancellation = [[RTCPair alloc] initWithKey:@"VoiceActivityDetection" value:@"false"];
//     //    [audioArr addObject:echoCancellation];
// }
//
// /** Called when the SignalingState changed. */
// - (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged{
//     NSLog(@"%s",__func__);
//     NSLog(@"stateChanged = %ld", (long)stateChanged);
// }
//
// /** Called when a remote peer closes a stream. */
// - (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream{
//     NSLog(@"%s",__func__);
// }
//
// /** Called when negotiation is needed, for example ICE has restarted. */
// - (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection{
//     NSLog(@"%s",__func__);
// }
//
// /** Called any time the IceConnectionState changes. */
// - (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState{
//     NSLog(@"%s : %ld",__func__,(long)newState);
// }
//
// /** Called any time the IceGatheringState changes. */
// - (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState{
//     NSLog(@"%s : %ld",__func__,(long)newState);
// }
//
// /** Called when a group of local Ice candidates have been removed. */
// - (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates{
//     NSLog(@"%s : %@",__func__,candidates);
// }
//
// /** New data channel has been opened. */
// - (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel{
//     NSLog(@"%s",__func__);
// }
//
// @end

 
 
