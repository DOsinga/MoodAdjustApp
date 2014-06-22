/*******************************************************************************
 Copyright (c) 2013 Koninklijke Philips N.V.
 All Rights Reserved.
 ********************************************************************************/

#import "MoodAdjustViewController.h"
#import "MoodAdjustAppDelegate.h"

#import <HueSDK_iOS/HueSDK.h>
#import <AVFoundation/AVFoundation.h>

#define MAX_HUE 65535

@interface MoodAdjustViewController ()

@property (weak, nonatomic) IBOutlet UIView *imagePreview;

@property (nonatomic,weak) IBOutlet UILabel *bridgeMacLabel;
@property (nonatomic,weak) IBOutlet UILabel *bridgeIpLabel;
@property (nonatomic,weak) IBOutlet UILabel *bridgeLastHeartbeatLabel;
@property (nonatomic,weak) IBOutlet UIButton *randomLightsButton;
@property (weak, nonatomic) IBOutlet UIImageView *colorPreviewImage;
@property (weak, nonatomic) IBOutlet UISlider *brightnessSlider;
@property (weak, nonatomic) IBOutlet UISlider *saturationSlider;

@end


@implementation MoodAdjustViewController {
    AVCaptureStillImageOutput *stillImageOutput;
    BOOL _cameraIsRunning;
}

- (IBAction)brightnessChanged:(UISlider *)sender {
}


- (IBAction)saturationChanged:(UISlider *)sender {
    
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    PHNotificationManager *notificationManager = [PHNotificationManager defaultManager];
    // Register for the local heartbeat notifications
    [notificationManager registerObject:self withSelector:@selector(localConnection) forNotification:LOCAL_CONNECTION_NOTIFICATION];
    [notificationManager registerObject:self withSelector:@selector(noLocalConnection) forNotification:NO_LOCAL_CONNECTION_NOTIFICATION];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Find bridge" style:UIBarButtonItemStylePlain target:self action:@selector(findNewBridgeButtonAction)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"About" style:UIBarButtonItemStylePlain target:self action:@selector(showAbout)];
    
    self.navigationItem.title = @"ColorAdjust";

    self.brightnessSlider.value = 0.3;
    self.saturationSlider.value = 0.9;

    [self noLocalConnection];
}

- (void)showAbout {

}

- (UIRectEdge)edgesForExtendedLayout {
    return UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight;
}

- (void)viewWillAppear:(BOOL)animated {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
        target:self
        selector:@selector(captureImage:)
        userInfo:nil
        repeats:NO];
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    [super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


- (void)localConnection{
    
    [self loadConnectedBridgeValues];
    
}

- (void)noLocalConnection{
    self.bridgeLastHeartbeatLabel.text = @"Not connected";
    [self.bridgeLastHeartbeatLabel setEnabled:NO];
    self.bridgeIpLabel.text = @"Not connected";
    [self.bridgeIpLabel setEnabled:NO];
    self.bridgeMacLabel.text = @"Not connected";
    [self.bridgeMacLabel setEnabled:NO];
    
    [self.randomLightsButton setEnabled:NO];
}

- (void)loadConnectedBridgeValues{
    PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
    
    // Check if we have connected to a bridge before
    if (cache != nil && cache.bridgeConfiguration != nil && cache.bridgeConfiguration.ipaddress != nil){
        
        // Set the ip address of the bridge
        self.bridgeIpLabel.text = cache.bridgeConfiguration.ipaddress;
        
        // Set the mac adress of the bridge
        self.bridgeMacLabel.text = cache.bridgeConfiguration.mac;
        
        // Check if we are connected to the bridge right now
        if (UIAppDelegate.phHueSDK.localConnected) {
            
            // Show current time as last successful heartbeat time when we are connected to a bridge
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateStyle:NSDateFormatterNoStyle];
            [dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
            
            self.bridgeLastHeartbeatLabel.text = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:[NSDate date]]];
            
            [self.randomLightsButton setEnabled:YES];
            if (!_cameraIsRunning) {
                [self initializeCamera];
            }
        } else {
            self.bridgeLastHeartbeatLabel.text = @"Waiting...";
            [self.randomLightsButton setEnabled:NO];
        }
    }
}

- (IBAction)selectOtherBridge:(id)sender{
    [UIAppDelegate searchForBridgeLocal];
}

- (void)findNewBridgeButtonAction{
    [UIAppDelegate searchForBridgeLocal];
}

- (void)captureImage:(id)o {
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in stillImageOutput.connections) {

        for (AVCaptureInputPort *port in [connection inputPorts]) {

            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }

        if (videoConnection) {
            break;
        }
    }

    NSLog(@"about to request a capture from: %@", stillImageOutput);
    [stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {

        if (imageSampleBuffer != NULL) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
            UIImage *image = [UIImage imageWithData:imageData];
            self.colorPreviewImage.image = image;

            UIColor *averageColor = [self averageColor:image];
            CGFloat hue;
            CGFloat saturation;
            CGFloat brightness;
            CGFloat alpha;

            [averageColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

            brightness = self.brightnessSlider.value;
            saturation = self.saturationSlider.value;

            UIColor *targetColor = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0];

            CGRect rect = CGRectMake(0, 0, 1, 1);
            UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
            [targetColor setFill];
            UIRectFill(rect);
            self.colorPreviewImage.image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            PHBridgeResourcesCache *cache = [PHBridgeResourcesReader readBridgeResourcesCache];
            id<PHBridgeSendAPI> bridgeSendAPI = [[[PHOverallFactory alloc] init] bridgeSendAPI];

            for (PHLight *light in cache.lights.allValues) {

                PHLightState *lightState = [[PHLightState alloc] init];

                [lightState setHue:[NSNumber numberWithInt:(int) (65535 * hue)]];
                [lightState setBrightness:[NSNumber numberWithInt:(int) (254 * self.brightnessSlider.value)]];
                [lightState setSaturation:[NSNumber numberWithInt:(int) (254 * self.saturationSlider.value)]];

                // Send lightstate to light
                [bridgeSendAPI updateLightStateForId:light.identifier withLighState:lightState completionHandler:^(NSArray *errors) {
                    if (errors != nil) {
                        NSString *message = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Errors", @""), errors != nil ? errors : NSLocalizedString(@"none", @"")];

                        NSLog(@"Response: %@",message);
                    }

                    [self.randomLightsButton setEnabled:YES];
                }];
            }
            self.timer = [NSTimer scheduledTimerWithTimeInterval:0.3
                target:self
                selector:@selector(captureImage:)
                userInfo:nil
                repeats:NO];
        }
    }];
}

- (UIColor *)averageColor:(UIImage *)image {
    // First get the image into your data buffer
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                    bitsPerComponent, bytesPerRow, colorSpace,
                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);


    int pixelCount = 0;
    int redSum = 0;
    int greenSum = 0;
    int blueSum = 0;

    for (int i = 0; i < height * width * 4; i += 4) {
        pixelCount += 1;
        redSum += rawData[i];
        greenSum += rawData[i + 1];
        blueSum += rawData[i + 2];
    }
    free(rawData);

    pixelCount *= 255;

    return [UIColor colorWithRed:(((CGFloat) redSum) / pixelCount)
                           green:(((CGFloat) greenSum) / pixelCount)
                            blue:(((CGFloat) blueSum) / pixelCount)
                           alpha:1];
}


//AVCaptureSession to show live video feed in view
- (void) initializeCamera {
    _cameraIsRunning = TRUE;
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
	session.sessionPreset = AVCaptureSessionPresetLow;
    
	AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
	captureVideoPreviewLayer.frame = self.imagePreview.bounds;
	[self.imagePreview.layer addSublayer:captureVideoPreviewLayer];
    
    UIView *view = [self imagePreview];
    CALayer *viewLayer = [view layer];
    [viewLayer setMasksToBounds:YES];
    
    CGRect bounds = [view bounds];
    [captureVideoPreviewLayer setFrame:bounds];
    
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    
    for (AVCaptureDevice *device in devices) {
        
        NSLog(@"Device name: %@", [device localizedName]);
        
        if ([device hasMediaType:AVMediaTypeVideo]) {
            
            if ([device position] == AVCaptureDevicePositionBack) {
                NSLog(@"Device position : back");
                backCamera = device;
            }
            else {
                NSLog(@"Device position : front");
                frontCamera = device;
            }
        }
    }
    
    if (backCamera) {
        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!input) {
            NSLog(@"ERROR: trying to open camera: %@", error);
        }
        [session addInput:input];
    } else if (frontCamera) {
        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (!input) {
            NSLog(@"ERROR: trying to open camera: %@", error);
        }
        [session addInput:input];
    }
    
    stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [stillImageOutput setOutputSettings:outputSettings];
    
    [session addOutput:stillImageOutput];
    
	[session startRunning];
    [NSTimer scheduledTimerWithTimeInterval:2.0
        target:self
        selector:@selector(captureImage:)
        userInfo:nil
        repeats:NO];
}

- (UIImage *)resizedImage:(UIImage *)image newSize:(CGSize)newSize interpolationQuality:(CGInterpolationQuality)quality {
    CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
    CGRect transposedRect = CGRectMake(0, 0, newRect.size.height, newRect.size.width);
    CGImageRef imageRef = image.CGImage;

    // Build a context that's the same dimensions as the new size
    CGContextRef bitmap = CGBitmapContextCreate(NULL,
                                                newRect.size.width,
                                                newRect.size.height,
                                                CGImageGetBitsPerComponent(imageRef),
                                                0,
                                                CGImageGetColorSpace(imageRef),
                                                CGImageGetBitmapInfo(imageRef));

    // Set the quality level to use when rescaling
    CGContextSetInterpolationQuality(bitmap, quality);

    // Get the resized image from the context and a UIImage
    CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];

    // Clean up
    CGContextRelease(bitmap);
    CGImageRelease(newImageRef);

    return newImage;
}


@end
