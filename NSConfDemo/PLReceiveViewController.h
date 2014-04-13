//
//  PLReceiveViewController.h
//  NSConfDemo
//
//  Created by Gonzalo Larralde on 4/6/14.
//  Copyright (c) 2014 Pickly. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <mach/mach.h>

#import <GPUImage/GPUImage.h>

@interface PLReceiveViewController : UIViewController<MCNearbyServiceAdvertiserDelegate, MCSessionDelegate> {
    // External Display
    UIWindow *secondWindow;
    UIImageView *externalPhotoFrame;
  
    // Photo Frame vars
    NSMutableArray *photos;
    NSURL *photosBaseURL;
    NSTimeInterval *photoFrameRotationInterval;
    
    IBOutlet UIImageView *photoFrame;
    IBOutlet UIImageView *secondaryPhotoFrame;
    
    // MultipeerConnectivity vars
    MCPeerID *me;
    MCNearbyServiceAdvertiser *advertiser;
    NSMutableSet *sessions;
    NSMutableDictionary *sessionsFiles;
}

@end
