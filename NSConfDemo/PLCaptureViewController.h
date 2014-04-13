//
//  PLCaptureViewController.h
//  NSConfDemo
//
//  Created by Gonzalo Larralde on 4/5/14.
//  Copyright (c) 2014 Pickly. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GPUImage/GPUImage.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface PLCaptureViewController : UIViewController<MCNearbyServiceBrowserDelegate, MCSessionDelegate> {
    // UI outlets
    IBOutlet GPUImageView *gpuView;
    IBOutlet UILabel *statusLabel;
    IBOutlet UIActivityIndicatorView *activityIndicator;
    IBOutlet UIProgressView *progressView;
    
    // Photo vars
    GPUImageStillCamera *stillCamera;
    GPUImageCropFilter *cropFilter;
    GPUImageSmoothToonFilter *toonFilter;
    NSURL *savedImageFront;
    NSURL *savedImageBack;
    
    // MultipeerConnectivity vars
    MCNearbyServiceBrowser *browser;
    MCPeerID *lastFoundAdvertiser;
    NSDictionary *discoveryInfo;
    BOOL tryingToCreateSession;
    
    MCPeerID *me;
    MCSession *session;
    
    NSProgress *progressFront;
    NSProgress *progressBack;
    
    NSTimer *browsingTimeoutTimer;
}

- (IBAction)takePhoto;

@end
