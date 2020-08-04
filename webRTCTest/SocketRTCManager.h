//
//  SocketRTCManager.h
//  webRTCTest
//
//  Created by 吳尚霖 on 7/23/20.
//  Copyright © 2020 SamWu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SocketRTCManagerDelegate

/**
 
 joined     
 otherJoin (createPeerConnection)
 full      (socket disConnect / remove localStream)
 leaved    (socket disConnect)
 disconnect(remove localStream)
 
 
 offer     (setRemoteDescription/sendAnswer)
 answer
 candidates
 
 */



- (void)socketConnected:(NSArray*)data;

- (void)socketDisConnected;

- (void)socketError;

//stream callback

- (void)streamConnectedData:(NSArray *)data;

- (void)streamReceiveStartCall:(NSArray *)data;

- (void)streamReceiveNewRoom:(NSArray *)data;

- (void)streamReceiveOffer:(NSArray *)data;

- (void)streamReceiveAnswer:(NSArray *)data;

- (void)streamReceiveCandidates:(NSArray *)data;

- (void)streamLeaveRoom:(NSArray *)data;

@end


@interface SocketRTCManager : NSObject

@property (weak,nonatomic) id<SocketRTCManagerDelegate> delegate;

+ (SocketRTCManager *)getInstance;

- (instancetype)init;

- (void)connect;

- (void)killHandlerAndDisConnect;

- (void)newRoomToStreamWithSocketID:(NSString*)socketID roomID:(NSString *)roomID;

- (BOOL)startCallToStreamWithSocketRoom:(NSString*)socketRoom SocketID:(NSString *)socketID;

- (void)sendOfferToStreamWithDic:(NSDictionary *)dic;

- (void)answerToStreamWithDic:(NSDictionary *)dic;

- (void)sendCandidatesToStreamWithDic:(NSDictionary *)dic;

- (void)leaveRoomToStreamWithDic:(NSDictionary *)dic;

@end

