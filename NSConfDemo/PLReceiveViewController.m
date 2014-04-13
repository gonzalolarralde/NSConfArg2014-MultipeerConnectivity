//
//  PLReceiveViewController.m
//  NSConfDemo
//
//  Created by Gonzalo Larralde on 4/6/14.
//  Copyright (c) 2014 Pickly. All rights reserved.
//

#import "PLReceiveViewController.h"

@interface PLReceiveViewController ()

@end

@implementation PLReceiveViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setUpScreenConnectionNotificationHandlers];
    [self checkForExistingScreenAndInitializeIfPresent];
    
    [self initPhotoFrame];
    [self initMultipeerConnectivity];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscapeLeft;
}

- (BOOL)shouldAutorotate {
    return NO;
}

#pragma mark - External Display

- (void)checkForExistingScreenAndInitializeIfPresent {
    if ([[UIScreen screens] count] > 1) {
        // Get the screen object that represents the external display.
        UIScreen *secondScreen = [[UIScreen screens] objectAtIndex:1];
        // Get the screen's bounds so that you can create a window of the correct size.
        CGRect screenBounds = secondScreen.bounds;

        secondWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        secondWindow.screen = secondScreen;
        secondWindow.hidden = NO;

        // Set up initial content to display...
        // Show the window.
        
        [self setUpSecondaryWindow];
    }
}

- (void)setUpScreenConnectionNotificationHandlers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver:self selector:@selector(handleScreenDidConnectNotification:)
                   name:UIScreenDidConnectNotification object:nil];
    [center addObserver:self selector:@selector(handleScreenDidDisconnectNotification:)
                   name:UIScreenDidDisconnectNotification object:nil];
}

- (void)handleScreenDidConnectNotification:(NSNotification*)aNotification {
    UIScreen *newScreen = [aNotification object];
    CGRect screenBounds = newScreen.bounds;

    if (!secondWindow) {
        secondWindow = [[UIWindow alloc] initWithFrame:screenBounds];
        secondWindow.screen = newScreen;
        secondWindow.hidden = NO;
        
        [self setUpSecondaryWindow];
    }
}

- (void)handleScreenDidDisconnectNotification:(NSNotification*)aNotification {
  if (secondWindow) {
      // Hide and then delete the window.
      secondWindow.hidden = YES;
      secondWindow = nil;
      
      [self tearDownSecondaryWindow];
  }
}

- (void)setUpSecondaryWindow {
    // Setea un image view para mostrar la imagen en la pantalla
    externalPhotoFrame = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, secondWindow.frame.size.height, secondWindow.frame.size.width)];
    externalPhotoFrame.center = secondWindow.center;
    externalPhotoFrame.transform = CGAffineTransformMakeRotation(M_PI_2*3.0);
    externalPhotoFrame.contentMode = UIViewContentModeScaleAspectFill;
    
    [secondWindow addSubview:externalPhotoFrame];
    
    // Muestra en el external photoFrame la imagen del primary photoFrame.
    // Luego pisa la imagen del photoFrame con la del secondaryPhotoFrame y vacía el secondary.
    externalPhotoFrame.image = photoFrame.image;
    photoFrame.image = secondaryPhotoFrame.image;
    secondaryPhotoFrame.image = nil;
}

- (void)tearDownSecondaryWindow {
    // Vuelve al estado orignal las fotos del secondary y primary photoFrame
    secondaryPhotoFrame.image = photoFrame.image;
    photoFrame.image = externalPhotoFrame.image;
    [externalPhotoFrame removeFromSuperview], externalPhotoFrame = nil;
}

#pragma mark - Photo Frame

- (void)initPhotoFrame {
    photos = [NSMutableArray arrayWithCapacity:0];
    
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    photosBaseURL = [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:@"photos"]
                               isDirectory:YES];
    
    // Creamos el diccionario en caso que sea la primer ejecución
    [[NSFileManager defaultManager] createDirectoryAtURL:photosBaseURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    
    // Obtenemos todas las fotos almacenadas en sesiones anteriores
    NSArray *photoBundles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:photosBaseURL
                                                          includingPropertiesForKeys:nil
                                                                             options:(NSDirectoryEnumerationSkipsSubdirectoryDescendants|
                                                                                      NSDirectoryEnumerationSkipsPackageDescendants|
                                                                                      NSDirectoryEnumerationSkipsHiddenFiles)
                                                                               error:nil];
    
    // Las últimas fotos van al tope
    photoBundles = [photoBundles sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return -[[(NSURL*)obj1 lastPathComponent] compare:[(NSURL*)obj2 lastPathComponent] options:(NSNumericSearch)];
    }];
    
    @synchronized(photos) {
        [photos addObjectsFromArray:photoBundles];
    }
    
    [NSTimer scheduledTimerWithTimeInterval:3
                                     target:self
                                   selector:@selector(changePhotoFrame)
                                   userInfo:nil
                                    repeats:YES];
}

- (NSURL*)createPhotoBundleWithName:(NSString*)name infoDict:(NSDictionary*)photoInfo backURL:(NSURL*)backURL frontURL:(NSURL*)frontURL {
    NSURL *photoBundleURL   = [photosBaseURL URLByAppendingPathComponent:name];
    
    NSURL *photoInfoDictURL = [photoBundleURL URLByAppendingPathComponent:@"info.plist"];
    NSURL *photoBackURL     = [photoBundleURL URLByAppendingPathComponent:@"back.jpg"];
    NSURL *photoFrontURL    = [photoBundleURL URLByAppendingPathComponent:@"front.jpg"];
    
    NSError *error = nil;
    
    // Creamos el diccionario del bundle
    [[NSFileManager defaultManager] createDirectoryAtURL:photoBundleURL
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    
    if(error)
        return nil;
    
    // Escribimos el infoDict
    if(![photoInfo writeToURL:photoInfoDictURL atomically:YES])
        return nil;
    
    // Escribimos la foto posterior
    [[NSFileManager defaultManager] copyItemAtURL:backURL
                                            toURL:photoBackURL
                                            error:&error];
    
    if(error)
        return nil;
    
    // Escribimos la foto frontal
    [[NSFileManager defaultManager] copyItemAtURL:frontURL
                                            toURL:photoFrontURL
                                            error:&error];
    
    if(error)
        return nil;
    
    return photoBundleURL;
}

- (void)registerPhoto:(NSURL*)photoBundleURL {
    @synchronized(photos) {
        [photos insertObject:photoBundleURL atIndex:0];
    }
}

- (void)changePhotoFrame {
    NSURL *photoToShow;
    
    if(photos.count == 0)
        return;
    
    @synchronized(photos) {
        photoToShow = [photos firstObject];
        [photos removeObjectAtIndex:0];
        [photos addObject:photoToShow];
    }
    
    UIImage *back = [UIImage imageWithContentsOfFile:[[photoToShow path] stringByAppendingPathComponent:@"back.jpg"]];
    UIImage *front = [UIImage imageWithContentsOfFile:[[photoToShow path] stringByAppendingPathComponent:@"front.jpg"]];
    if(!secondWindow) {
        photoFrame.image = back;
        secondaryPhotoFrame.image = front;
    } else {
        externalPhotoFrame.image = back;
        photoFrame.image = front;
    }
}

#pragma mark - Multipeer Connectivity
#pragma mark -

- (void)initMultipeerConnectivity {
    // Este es el nombre que le vamos a dar al host de la sesión.
    me = [[MCPeerID alloc] initWithDisplayName:@"NSConf Arg 2014"];
    
    // Hacemos lugar par almacenar las sesiones, a fines de juntar ambas imagenes al final.
    sessions = [[NSMutableSet alloc] initWithCapacity:0];
    sessionsFiles = [[NSMutableDictionary alloc] initWithCapacity:0];
    
    // Comienza a anunciar el servicio.
    advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:me
                                                   discoveryInfo:nil
                                                     serviceType:kPLMultipeerConnectivityServiceType];
    advertiser.delegate = self;
    [advertiser startAdvertisingPeer];
}

#pragma mark - > MCNearbyServiceAdvertiserDelegate

// Incoming invitation request.  Call the invitationHandler block with YES and a valid session to connect the inviting peer to the session.
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID
                                                                            withContext:(NSData *)context
                                                                      invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler {
    MCSession *session = [[MCSession alloc] initWithPeer:me
                                        securityIdentity:nil
                                    encryptionPreference:MCEncryptionNone];
    
    [sessions addObject:session];
    @synchronized(sessionsFiles) {
        sessionsFiles[[NSValue valueWithNonretainedObject:session]] = [NSMutableDictionary dictionaryWithCapacity:2];
    }
    
    session.delegate = self;
    
    invitationHandler(YES, session);
}

// Advertising did not start due to an error
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    
}

#pragma mark - > MCSessionDelegate

// Remote peer changed state
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {

}

// Received data from remote peer
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    
}

// Received a byte stream from remote peer
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    
}

// Start receiving a resource from remote peer
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    NSLog(@"Comienzo a recibir %@ de %@", resourceName, peerID.displayName);
}

// Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    if(error)
        return; // deberia descartar la sesion aca
    
    NSLog(@"Recibí %@ en %@ de %@", resourceName, localURL, peerID.displayName);
    
    NSMutableDictionary *sessionFiles = sessionsFiles[[NSValue valueWithNonretainedObject:session]];
    @synchronized(sessionFiles) {
        sessionFiles[resourceName] = localURL;
        
        if(sessionFiles[@"back.jpg"] && sessionFiles[@"front.jpg"]) {
            
            NSURL *photoBundle = [self createPhotoBundleWithName:[@( mach_absolute_time() ) stringValue] infoDict:@{@"from":peerID.displayName} backURL:sessionFiles[@"back.jpg"] frontURL:sessionFiles[@"front.jpg"]];
            if(photoBundle) {
                [self registerPhoto:photoBundle];
            }
        } else {
            NSLog(@"sessionFiles: %@", sessionFiles);
        }
    }

}

#pragma mark -


@end
