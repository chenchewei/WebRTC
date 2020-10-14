//
//  PeerConnection.h
//  webRTCTest
//
//  Created by 吳尚霖 on 10/14/20.
//  Copyright © 2020 SamWu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

@interface PeerConnection : NSObject

+ (RTCMediaStream *)createLocalStream;
+ (RTCMediaConstraints *)offerOranswerConstraint;
+ (RTCConfiguration*)setStunServerToICEServer;

@end

