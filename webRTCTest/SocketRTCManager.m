//
//  SocketRTCManager.m
//  webRTCTest
//
//  Created by 吳尚霖 on 7/23/20.
//  Copyright © 2020 SamWu. All rights reserved.
//

#define DEVELOP_SocketURL @"https://630cc1a2ffd9.ngrok.io"

#import "SocketRTCManager.h"

#import <SocketIO-Swift.h>
#import <WebRTC/RTCSessionDescription.h>

@interface SocketRTCManager()

@property (strong, nonatomic)NSString *userID;

@end

@implementation SocketRTCManager

SocketManager *socketManager;
SocketIOClient *socketClient;
SocketIOStatus *status;
static SocketRTCManager *socketRTCManager = nil;

+ (SocketRTCManager *)getInstance{
    if(!socketRTCManager)
        socketRTCManager = [[SocketRTCManager alloc] init];
    return socketRTCManager;
}

- (instancetype)init{
    if(self = [super init]){
        
        NSURL *url = [[NSURL alloc]initWithString:DEVELOP_SocketURL];
        socketManager = [[SocketManager alloc] initWithSocketURL:url config:@{@"log": @NO , @"compress": @YES}];
        socketClient = socketManager.defaultSocket;
        NSLog(@"%@",socketClient.manager.socketURL);
    }
    return self;
}

- (void)connect{
    
    [socketClient connectWithTimeoutAfter:5.0 withHandler:^{
        NSLog(@"[RTCSocket] [on] Connect timeout");
        [self connect];
    }];
    
    [socketClient on:@"startCall" callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        NSLog(@"[RTCSocket] [on] startCall");
        [_delegate streamReceiveStartCall:data];
        
    }];
    
    [socketClient on:@"connectedData" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
       
        NSLog(@"[RTCSocket] [on] connectedData\n==>%@",data);
        [_delegate streamConnectedData:data];
        
    }];
    
    [socketClient on:@"newRoom" callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        NSLog(@"[RTCSocket] [on] newRoom");
        [_delegate streamReceiveNewRoom:data];
        
    }];
    
    [socketClient on:@"connect" callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        NSLog(@"[RTCSocket] [on] connect");
        [_delegate socketConnected:data];
        
    }];
    
    [socketClient on:@"offer" callback:^(NSArray *data, SocketAckEmitter *ack) {

        NSLog(@"[RTCSocket] [on] offer");
        [_delegate streamReceiveOffer:data];

    }];
    
    [socketClient on:@"answer" callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        NSLog(@"[RTCSocket] [on] answer");
        [_delegate streamReceiveAnswer:data];
        
    }];
    
    [socketClient on:@"ice_candidates" callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        NSLog(@"[RTCSocket] [on] ice_candidates");
        [_delegate streamReceiveCandidates:data];
        
    }];
    
    [socketClient on:@"disconnect" callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        NSLog(@"[RTCSocket] [on] disconnect");
        [_delegate socketDisConnected];
        
    }];
    
    [socketClient on:@"error" callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        NSLog(@"[RTCSocket] [on] error");
        
        [self killHandlerAndDisConnect];
        
        [_delegate socketError];
        
    }];
    
    [socketClient on:@"leaveRoom" callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        NSLog(@"[RTCSocket] [on] leaveRoom");
                
        [_delegate streamLeaveRoom:data];
        
    }];
    
}

- (void)killHandlerAndDisConnect{
    if(socketClient.status == SocketIOStatusConnected){
        [socketManager disconnect];
        [socketClient removeAllHandlers];
    }
}

- (void)newRoomToStreamWithSocketID:(NSString*)socketID roomID:(NSString *)roomID{
    NSDictionary *dic = @{@"socketID"   :socketID,
                          @"roomID"     :roomID};
    
    [socketClient emit:@"newRoom" with:@[dic]];
}

- (BOOL)startCallToStreamWithSocketRoom:(NSString*)socketRoom SocketID:(NSString *)socketID{
    if(socketClient.status == SocketIOStatusConnected){
        NSLog(@"[RTCSocket] [emit] startCall");
        
        NSDictionary *dic = @{@"socketRoom":socketRoom,
                              @"socketID":socketID
                              };
        
        [socketClient emit:@"startCall" with:@[dic]];
    }
    return (socketClient.status == SocketIOStatusConnected);
}

- (void)sendOfferToStreamWithDic:(NSDictionary *)dic{
        NSLog(@"[RTCSocket] [emit] offer");
        [socketClient emit:@"offer" with:@[dic]];
}

- (void)answerToStreamWithDic:(NSDictionary *)dic{
    NSLog(@"[RTCSocket] [emit] answer");
        
    [socketClient emit:@"answer" with:@[dic]];
}

- (void)sendCandidatesToStreamWithDic:(NSDictionary *)dic{
    NSLog(@"[RTCSocket] [emit] ice_candidates");
    [socketClient emit:@"ice_candidates" with:@[dic]];
}

- (void)leaveRoomToStreamWithDic:(NSDictionary *)dic{
    NSLog(@"[RTCSocket] [emit] leaveRoom");
    [socketClient emit:@"leaveRoom" with:@[dic]];
}

@end
