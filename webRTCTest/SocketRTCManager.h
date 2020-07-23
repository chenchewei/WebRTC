//
//  SocketRTCManager.h
//  webRTCTest
//
//  Created by 吳尚霖 on 7/23/20.
//  Copyright © 2020 SamWu. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SocketRTCManagerDelegate

- (void)socketConnected:(NSArray*)data;

- (void)socketDisConnected;

- (void)socketError;

//stream callback
- (void)streamBusy;

- (void)streamNoReply;

- (void)streamStart;

- (void)streamFinish;

- (void)streamForceFinish;

- (void)streamReject;

- (void)streamRejected;

- (void)streamCreated;

- (void)streamJoined;

- (void)streamCancel;

@end


@interface SocketRTCManager : NSObject

@property (weak,nonatomic) id<SocketRTCManagerDelegate> delegate;

+ (SocketRTCManager *)getInstance;

- (instancetype)init;

- (void)connect;

- (void)killHandlerAndDisConnect;

- (BOOL)createToStreamWithRoomID:(NSString*)roomID targetID:(NSString*)targetID;

- (void)signToStreamWithRoomType:(int)roomType isVideo:(BOOL)isVideo roomID:(NSString*)roomID targetID:(NSString*)targetID;

- (void)joinToStreamWithRoomID:(NSString*)roomID;

- (void)cancelToStreamWithRoomID:(NSString*)roomID isNoReply:(BOOL)isNoReply;

- (void)rejectToStreamWithRoomID:(NSString*)roomID;

- (void)finishToStreamWithRoomID:(NSString*)roomID;

- (void)noReplyToStreamWithRoomID:(NSString*)roomID;

@end

