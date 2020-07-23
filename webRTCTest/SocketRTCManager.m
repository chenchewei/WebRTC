//
//  SocketRTCManager.m
//  webRTCTest
//
//  Created by 吳尚霖 on 7/23/20.
//  Copyright © 2020 SamWu. All rights reserved.
//

#define DEVELOP_SocketURL @"https://b7f3e8cc091a.ngrok.io"

#import "SocketRTCManager.h"

#import <SocketIO-Swift.h>

//typedef enum {
//    
//}socketStatus;

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
        
        NSURL *url = [[NSURL alloc]initWithString:@"ws://ipURL:port"];
        socketManager = [[SocketManager alloc] initWithSocketURL:url config:@{@"log": @NO , @"compress": @YES}];
        socketClient = socketManager.defaultSocket;
    }
    return self;
}

- (void)connect{
    
    if(socketClient.status != SocketIOStatusConnected){
        
        [socketClient connectWithTimeoutAfter:5.0 withHandler:^{
            NSLog(@"[RTCSocket] [on] connect timeout");
        }];
        
        [socketClient on:@"connect" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] connect");
            [_delegate socketConnected:data];
            
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
        
        [socketClient on:@"busy" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] busy");
            
            [self killHandlerAndDisConnect];
            
            [_delegate streamBusy];
            
        }];
        
        [socketClient on:@"noReply" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] noReply");
            
            [self killHandlerAndDisConnect];
            
            [_delegate streamNoReply];
            
        }];
        
        [socketClient on:@"start" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] start");
            [_delegate streamStart];
            
        }];
        
        [socketClient on:@"finish" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] finish");
            
            [self killHandlerAndDisConnect];
            
            [_delegate streamFinish];
            
        }];
        
        [socketClient on:@"forceFinish" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] forceFinish");
            
            [self killHandlerAndDisConnect];
            
            [_delegate streamForceFinish];
            
        }];
        
        [socketClient on:@"reject" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] reject");
            
            [self killHandlerAndDisConnect];
            
            [_delegate streamReject];
            
        }];
        
        [socketClient on:@"rejected" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] rejected");
            
            [self killHandlerAndDisConnect];
            
            [_delegate streamRejected];
            
        }];
        
        [socketClient on:@"joined" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] joined");
            
            [self killHandlerAndDisConnect];
            
            [_delegate streamJoined];
            
        }];
        
        [socketClient on:@"created" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] created");
            
            [self killHandlerAndDisConnect];
            
            [_delegate streamCreated];
            
        }];
        
        [socketClient on:@"cancel" callback:^(NSArray *data, SocketAckEmitter *ack) {
            
            NSLog(@"[RTCSocket] [on] cancel");
            
            [self killHandlerAndDisConnect];
            
            [_delegate streamCancel];
            
        }];
        
        
    }else{
        [_delegate socketConnected];
    }
}

- (void)killHandlerAndDisConnect{
    if(socketClient.status == SocketIOStatusConnected){
        [socketManager disconnect];
        [socketClient removeAllHandlers];
    }
}

- (BOOL)createToStreamWithRoomID:(NSString*)roomID targetID:(NSString*)targetID{
    if(socketClient.status == SocketIOStatusConnected){
        NSLog(@"[RTCSocket] [emit] create");
        
        NSDictionary *dic = @{@"roomID"   :roomID,
                              @"targetID" :targetID};
        
        [socketClient emit:@"create" with:@[dic]];
    }
    return (socketClient.status == SocketIOStatusConnected);
}

- (void)signToStreamWithRoomType:(int)roomType isVideo:(BOOL)isVideo roomID:(NSString*)roomID targetID:(NSString*)targetID{
    NSLog(@"[RTCSocket] [emit] sign");
    
    NSDictionary *dic = @{@"accessKey":@"",
                          @"userID"   :_userID,
                          @"roomType" :@(roomType),
                          @"isVideo"  :@(isVideo),
                          @"roomID"   :roomID,
                          @"targetID" :targetID};
    
    [socketClient emit:@"sign" with:@[dic]];
}

- (void)joinToStreamWithRoomID:(NSString*)roomID{
    NSLog(@"[RTCSocket] [emit] join");
    
    NSDictionary *dic = @{@"roomID":roomID, @"userID":_userID};
    
    [socketClient emit:@"join" with:@[dic]];
}

- (void)cancelToStreamWithRoomID:(NSString*)roomID isNoReply:(BOOL)isNoReply{
    NSLog(@"[RTCSocket] [emit] cancel");
    
    NSDictionary *dic = @{@"roomID":roomID, @"userID":_userID, @"isNoReply":@(isNoReply)};
       
    [socketClient emit:@"cancel" with:@[dic]];
}

- (void)rejectToStreamWithRoomID:(NSString*)roomID{
    NSLog(@"[RTCSocket] [emit] reject");
    
    NSDictionary *dic = @{@"roomID":roomID, @"userID":_userID};
    
    [socketClient emit:@"reject" with:@[dic]];
}

- (void)finishToStreamWithRoomID:(NSString*)roomID{
    NSLog(@"[RTCSocket] [emit] finish");
    
    NSDictionary *dic = @{@"roomID":roomID, @"userID":_userID};
    
    [socketClient emit:@"finish" with:@[dic]];
}

- (void)noReplyToStreamWithRoomID:(NSString*)roomID{
    NSLog(@"[RTCSocket] [emit] noReply");
    
    NSDictionary *dic = @{@"roomID":roomID, @"userID":_userID};
    
    [socketClient emit:@"noReply" with:@[dic]];
}

@end
