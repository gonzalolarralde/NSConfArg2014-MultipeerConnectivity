//
//  PLCaptureViewController.m
//  NSConfDemo
//
//  Created by Gonzalo Larralde on 4/5/14.
//  Copyright (c) 2014 Pickly. All rights reserved.
//

#import "PLCaptureViewController.h"

@interface PLCaptureViewController ()

@end

@implementation PLCaptureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self initPhotoCapture];
    [self initMultipeerConnectivity];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscapeLeft;
}

- (BOOL)shouldAutorotate {
    return NO;
}

#pragma mark - UI Refresh

// Las llamadas a los delegates de MC no ocurren en el main thread.
// Para actualizar UI tenemos que pasar la llamada al mismo.

- (void)uiReadyToTakePhoto:(BOOL)isReady {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.navigationItem.leftBarButtonItem.enabled = isReady;
        gpuView.enabled = isReady;
        if(isReady) {
            [stillCamera resumeCameraCapture];
            
            statusLabel.text = @"Sacá una foto";
            statusLabel.hidden = NO;
            progressView.hidden = YES;
            [activityIndicator stopAnimating];
        }
    });
}

- (void)uiTextState:(NSString*)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [activityIndicator startAnimating];
        progressView.hidden = YES;
        statusLabel.text = message;
        statusLabel.hidden = NO;
    });
}

- (void)uiProgressState:(float)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        [activityIndicator stopAnimating];
        statusLabel.hidden = YES;
        [progressView setProgress:progress animated:(progress > 0)];
        progressView.hidden = NO;
    });
}

- (void)uiShowError:(NSError*)error fromSource:(NSString*)source {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[UIAlertView alloc] initWithTitle:source
                                    message:error.localizedDescription
                                   delegate:nil cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    });
    
    [self tearDown];
}

#pragma mark - Photo Capture

- (void)initPhotoCapture {
    stillCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPresetMedium
                                                      cameraPosition:AVCaptureDevicePositionBack];
    
    stillCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
    
    // Inicializamos los filtros que vamos a usar para la captura
    cropFilter = [[GPUImageCropFilter alloc] initWithCropRegion:CGRectMake(0.1,0.1,0.9,0.9)];
    
    toonFilter = [[GPUImageSmoothToonFilter alloc] init];
    toonFilter.threshold = 0.1;
    toonFilter.quantizationLevels = 4;
    
    // Asociamos la camara a la vista preview
    [stillCamera addTarget:gpuView];
    
    [stillCamera startCameraCapture];
    
    [self uiReadyToTakePhoto:YES];
}

- (IBAction)takePhoto {
    [self uiReadyToTakePhoto:NO];
    [self uiTextState:@"Capturando..."];
  
    [stillCamera addTarget:cropFilter];
  
    // Captura la foto posterior
    [stillCamera capturePhotoAsImageProcessedUpToFilter:cropFilter
                                  withCompletionHandler:^(UIImage *processedImage_back, NSError *error) {
        
        [stillCamera removeTarget:cropFilter];
                                      
        if(!error) {
            // Guarda la foto tomada con la cámara posterior para luego enviarla
            savedImageBack = [self savePhoto:processedImage_back withSuffix:@"back"];
            processedImage_back = nil; // Liberamos memoria cuando la imagen ya fue guardada.
            
            // Gira la camara (^_^')
            [stillCamera rotateCamera];
            // No tenemos forma de saber cuando la rotación de camara y el white-balancing están listos.
            // Esperamos un tiempo prudencial en su lugar.
            [self performSelector:@selector(takePhotoFront) withObject:nil afterDelay:1];
        } else {
            [self uiShowError:error fromSource:@"Error de Captura"];
        }
    }];
}

- (void)takePhotoFront {
    
    [stillCamera addTarget:toonFilter];
    
    // Captura la foto frontal y aplica filtro de caricatura
    [stillCamera capturePhotoAsImageProcessedUpToFilter:toonFilter
                                  withCompletionHandler:^(UIImage *processedImage_front, NSError *error) {
        
        [stillCamera removeTarget:toonFilter];
        
        // Reposiciona la camara a su ubicación original
        [stillCamera rotateCamera];
        [stillCamera pauseCameraCapture];

        if(!error) {
            // Guarda la foto tomada con la cámara frontal para luego enviarla
            savedImageFront = [self savePhoto:processedImage_front withSuffix:@"front"];
            processedImage_front = nil; // Liberamos memoria cuando la imagen ya fue guardada.

            // Comienza el proceso de publicación de las fotos
            [self publishPhotos];
        } else {
            [self uiShowError:error fromSource:@"Error de Captura 2"];
        }
    }];

}

- (NSURL*)savePhoto:(UIImage*)photo withSuffix:(NSString*)suffix {
    // Guarda la información en un archivo para poder ser enviado como recurso
    NSString *fileName = [NSString stringWithFormat:@"photo_%@.jpg", suffix];
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath
                                               error:nil];
    [[NSFileManager defaultManager] createFileAtPath:filePath
                                            contents:UIImageJPEGRepresentation(photo, 0.9)
                                          attributes:nil];
    
    return [NSURL fileURLWithPath:filePath];
}

- (void)tearDownPhotoCapture {
    [[NSFileManager defaultManager] removeItemAtURL:savedImageBack error:nil], savedImageBack = nil;
    [[NSFileManager defaultManager] removeItemAtURL:savedImageFront error:nil], savedImageFront = nil;
}

#pragma mark - Multipeer Connectivity
#pragma mark -

- (void)initMultipeerConnectivity {
    me = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
}

- (void)publishPhotos {
    [self uiTextState:@"Buscando Advertiser..."];
    
    me = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
    
    // Preinicializa la sesion que se va a iniciar con un potencial advertiser
    session = [[MCSession alloc] initWithPeer:me
                             securityIdentity:nil
                         encryptionPreference:MCEncryptionNone];
    session.delegate = self;
    
    // Instancia browser que va a encargarse de buscar un advertiser
    browser = [[MCNearbyServiceBrowser alloc] initWithPeer:me
                                               serviceType:kPLMultipeerConnectivityServiceType];
    browser.delegate = self;
    [browser startBrowsingForPeers];
    
    // Setea un timeout al minuto
    browsingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:60.0
                                                            target:self
                                                          selector:@selector(browsingTimeout)
                                                          userInfo:nil
                                                           repeats:NO];
}

- (void)browsingTimeout {
    [self tearDown];
}

#pragma mark - > MCNearbyServiceBrowserDelegate

// Found a nearby advertising peer
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
    [self createSessionWithPeer:peerID];
}

// A nearby peer has stopped advertising
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    
}

// Browsing did not start due to an error
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    [self uiShowError:error fromSource:@"Error de Búsqueda"];
}

#pragma mark -

- (void)createSessionWithPeer:(MCPeerID*)remotePeer {
    [self uiTextState:@"Invitando al Advertiser..."];
    
    [browsingTimeoutTimer invalidate];
    [browser invitePeer:remotePeer toSession:session withContext:nil timeout:60];
}

#pragma mark - > MCSessionDelegate

// Remote peer changed state
- (void)session:(MCSession *)_session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch(state) {
        case MCSessionStateConnecting: {
            [self uiTextState:@"Conectando..."];
        } break;
        
        case MCSessionStateConnected: {
            [self sendPhotos:peerID];
        } break;
        
        case MCSessionStateNotConnected: {
            [self tearDown];
        } break;
    }
}

// Received data from remote peer
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    
}

// Received a byte stream from remote peer
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    
}

// Start receiving a resource from remote peer
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    
}

// Finished receiving a resource from remote peer and saved the content in a temporary location - the app is responsible for moving the file to a permanent location within its sandbox
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    
}


#pragma mark -

- (void)sendPhotos:(MCPeerID*)peerID {
    [self uiTextState:@"Enviando..."];
    
    // Comienza envío de la imagen posterior
    progressBack = [session sendResourceAtURL:savedImageBack
                                     withName:@"back.jpg"
                                       toPeer:peerID
                        withCompletionHandler:^(NSError *error) {
                            [progressBack removeObserver:self forKeyPath:@"fractionCompleted"];
                            progressBack = nil;
                            
                            if(!error) {
                                [self checkIfCompleted];
                            } else {
                                [self uiShowError:error fromSource:@"Error Enviando 1"];
                            }
                        }];
    
    // Y al mismo tiempo de la imagen frontal
    progressFront = [session sendResourceAtURL:savedImageFront
                                      withName:@"front.jpg"
                                        toPeer:peerID
                         withCompletionHandler:^(NSError *error) {
                             [progressFront removeObserver:self forKeyPath:@"fractionCompleted"];
                             progressFront = nil;
                             
                             if(!error) {
                                 [self checkIfCompleted];
                             } else {
                                 [self uiShowError:error fromSource:@"Error Enviando 2"];
                             }
                         }];
    
    // Reporta el progreso en 0 para mostrar progressView
    [self uiProgressState:0];
    
    // Y luego comienza a observar los valores correspondientes
    [progressBack addObserver:self
                   forKeyPath:@"fractionCompleted"
                      options:NSKeyValueObservingOptionNew
                      context:(void*)savedImageBack];
    
    [progressFront addObserver:self
                    forKeyPath:@"fractionCompleted"
                       options:NSKeyValueObservingOptionNew
                       context:(void*)savedImageFront];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(object == progressBack || object == progressFront) {
        [self updateProgress];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateProgress {
    float totalProgress;
    
    totalProgress += progressBack == nil ? 0.5 : (progressBack.fractionCompleted / 2.0);
    totalProgress += progressFront == nil ? 0.5 : (progressFront.fractionCompleted / 2.0);
    
    [self uiProgressState:totalProgress];
}

- (void)checkIfCompleted {
    if(progressBack == nil && progressFront == nil) {
        [self tearDown];
    }
}

- (void)tearDownMultipeerConnectivity {
    [browser stopBrowsingForPeers], browser = nil;
    [session disconnect], session = nil;
    
    if(progressBack)
        [progressBack removeObserver:self forKeyPath:@"fractionCompleted"], progressBack = nil;
    if(progressFront)
        [progressFront removeObserver:self forKeyPath:@"fractionCompleted"], progressFront = nil;
    
    [browsingTimeoutTimer invalidate], browsingTimeoutTimer = nil;
}

#pragma mark -

- (void)tearDown {
    [self tearDownPhotoCapture];
    [self tearDownMultipeerConnectivity];
    
    [self uiReadyToTakePhoto:YES];
}

@end
