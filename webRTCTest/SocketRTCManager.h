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

- (void)streamReceiveStartCall:(NSArray *)data;

- (void)streamReceiveNewRoom:(NSArray *)data;

- (void)streamReceiveOffer:(NSArray *)data;

- (void)streamReceiveAnswer:(NSArray *)data;

- (void)streamReceiveCandidates:(NSArray *)data;

- (void)streamCancel;

@end


@interface SocketRTCManager : NSObject

@property (weak,nonatomic) id<SocketRTCManagerDelegate> delegate;

+ (SocketRTCManager *)getInstance;

- (instancetype)init;

- (void)connect;

- (void)killHandlerAndDisConnect;

- (BOOL)startCallToStreamWithRoomID:(NSString*)roomID targetID:(NSString*)targetID;

- (void)newRoomToStreamWithRoomID:(NSString*)roomID targetID:(NSString*)targetID;

- (void)sendOfferToStreamWithDic:(NSDictionary *)dic;

- (void)answerToStreamWithDic:(NSDictionary *)dic;

- (void)sendCandidatesToStreamWithDic:(NSDictionary *)dic;
@end

