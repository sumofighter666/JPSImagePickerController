//
//  JPSImagePickerController.m
//  JPSImagePickerController
//
//  Created by JP Simard on 1/31/2014.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

#import "JPSImagePickerController.h"
#import "JPSCameraButton.h"
#import <AVFoundation/AVFoundation.h>
#import "JPSVolumeButtonHandler.h"
#import "NSLayoutConstraint+BNRMatchingSuperviewAdditions.h"
#import "JPSAVCaptureVideoPreviewLayerHostingView.h"

static AVCaptureVideoOrientation AVCaptureVideoOrientationFromUIDeviceOrientation(UIInterfaceOrientation deviceOrientation);

static CGFloat JPSImagePickerControllerButtonInset = 15.5;

typedef NS_ENUM(NSInteger, JPSImagePickerControllerState) {
    JPSImagePickerControllerStateError = -1,
    JPSImagePickerControllerStateUnknown = 0,
    JPSImagePickerControllerStateBeginningCapture,
    JPSImagePickerControllerStateCapturing,
    JPSImagePickerControllerStateCaptured,
};

@interface JPSImagePickerController (/*Lifetime State: Views*/)
@property (nonatomic) UIImageView *previewImageView;
@property (nonatomic) JPSAVCaptureVideoPreviewLayerHostingView *capturePreviewView;

@property (nonatomic) UIView *capturingToolbarView;
@property (nonatomic) UIView *editingToolbarView;
@property (nonatomic) UIButton *cameraButton;
@property (nonatomic) UIButton *cancelButton;
@property (nonatomic) UIButton *flashButton;
@property (nonatomic) UIButton *cameraSwitchButton;
@property (nonatomic) UIButton *retakeButton;
@property (nonatomic) UIButton *retakeOverlayButton;
@property (nonatomic) UIButton *useButton;
@property (nonatomic) UIButton *useOverlayButton;
@end

@interface JPSImagePickerController (/*Lifetime State*/)
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureStillImageOutput *captureStillImageOutput;
@property (nonatomic) NSOperationQueue *captureQueue;
@property (nonatomic) JPSVolumeButtonHandler *volumeButtonHandler;
@end

@interface JPSImagePickerController (/*State*/)
@property (nonatomic) JPSImagePickerControllerState state;

@property (nonatomic) UIImage *previewImage;
@property (nonatomic) UIImageOrientation imageOrientation;
@end

@implementation JPSImagePickerController

#pragma mark - Lifecycle

- (id)init {
    self = [super init];
    if (self) {
        _captureQueue = ^{
            NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
            
            operationQueue.maxConcurrentOperationCount = 1;
            
            return operationQueue;
        }();
        
        _editingEnabled = YES;
        _volumeButtonTakesPicture = YES;
    }
    return self;
}

- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    view.tintColor = [UIColor whiteColor];
    view.backgroundColor = [UIColor blackColor];
    self.view = view;
    
    [self addSubviews];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setupSession];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self teardownVolumeButtonHandler];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self teardownVolumeButtonHandler];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self teardownSession];
}

#pragma mark - Accessors

- (void)setSession:(AVCaptureSession *)session
{
    _session = session;
    
    self.capturePreviewView.layer.session = session;
    [self updateCapturePreviewViewLayerConnectionVideoOrientationFromInterfaceOrientation];
}

- (void)setPreviewImage:(UIImage *)previewImage
{
    _previewImage = previewImage;
    
    self.previewImageView.image = previewImage;
}

#pragma mark - Accessors: Capture Devices

- (AVCaptureDevice *)frontCamera
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *)currentDevice
{
    return [(AVCaptureDeviceInput *)self.session.inputs.firstObject device];
}

- (AVCaptureDevice *)captureDeviceForCaptureDevicePosition:(AVCaptureDevicePosition)position
{
    AVCaptureDevice *result = nil;
    
    switch (position) {
        case AVCaptureDevicePositionBack: {
            result = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        } break;
        case AVCaptureDevicePositionFront: {
            result = [self frontCamera];
        } break;
        case AVCaptureDevicePositionUnspecified: {
            result = nil;
        } break;
    }
    
    return result;
}

- (AVCaptureDevicePosition)captureDevicePositionAfterCaptureDevicePosition:(AVCaptureDevicePosition)currentPosition
{
    AVCaptureDevicePosition result = AVCaptureDevicePositionUnspecified;
    
    switch (currentPosition) {
        case AVCaptureDevicePositionFront: {
            result = AVCaptureDevicePositionBack;
        } break;
        case AVCaptureDevicePositionBack: {
            result = AVCaptureDevicePositionFront;
        } break;
        case AVCaptureDevicePositionUnspecified: {
            result = AVCaptureDevicePositionUnspecified;
        } break;
    }
    
    return result;
}

#pragma mark - UIViewController Overrides

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
}

#pragma mark - Setup UI

- (void)addSubviews
{
    [self addPreviewImageView];
    [self addCapturePreviewView];
    
    [self addCapturingToolbarView];
    [self addEditingToolbarView];
    
    [self addCameraButton];
    [self addCancelButton];
    [self addFlashButton];
    [self addCameraSwitchButton];
    [self addUseButton];
    [self addUseOverlayButton];
    [self addRetakeButton];
    [self addRetakeOverlayButton];
    
    [self updateSubviewsHiddenFromState];
}

- (void)addCapturingToolbarView
{
    UIView *view = self.view;
    
    // View
    UIView *capturingToolbarView = [[UIView alloc] initWithFrame:view.bounds];
    capturingToolbarView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    
    [view addSubview:capturingToolbarView];
    self.capturingToolbarView = capturingToolbarView;
    
    // Constraints
    capturingToolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:capturingToolbarView
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:view
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0
                                                                      constant:0.0];
    NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:capturingToolbarView
                                                                       attribute:NSLayoutAttributeRight
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:view
                                                                       attribute:NSLayoutAttributeRight
                                                                      multiplier:1.0
                                                                        constant:0.0];
    NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:capturingToolbarView
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:view
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0
                                                                         constant:0.0];
    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:capturingToolbarView
                                                                       attribute:NSLayoutAttributeWidth
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:nil
                                                                       attribute:NSLayoutAttributeNotAnAttribute
                                                                      multiplier:1.0
                                                                        constant:89.0];
    [view addConstraints:@[topConstraint, rightConstraint, bottomConstraint, widthConstraint]];
}

- (void)addEditingToolbarView
{
    UIView *view = self.view;
    
    // View
    UIView *editingToolbarView = [[UIView alloc] initWithFrame:view.bounds];
    editingToolbarView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    
    [view addSubview:editingToolbarView];
    self.editingToolbarView = editingToolbarView;
    
    // Constraints
    editingToolbarView.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:editingToolbarView
                                                                      attribute:NSLayoutAttributeLeft
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:view
                                                                      attribute:NSLayoutAttributeLeft
                                                                     multiplier:1.0
                                                                       constant:0.0];
    NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:editingToolbarView
                                                                       attribute:NSLayoutAttributeRight
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:view
                                                                       attribute:NSLayoutAttributeRight
                                                                      multiplier:1.0
                                                                        constant:0.0];
    NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:editingToolbarView
                                                                        attribute:NSLayoutAttributeBottom
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:view
                                                                        attribute:NSLayoutAttributeBottom
                                                                       multiplier:1.0
                                                                         constant:0.0];
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:editingToolbarView
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:nil
                                                                        attribute:NSLayoutAttributeNotAnAttribute
                                                                       multiplier:1.0
                                                                         constant:89.0];
    [view addConstraints:@[leftConstraint, rightConstraint, bottomConstraint, heightConstraint]];
}

- (void)addCameraButton
{
    UIView *view = self.view;
    UIView *capturingToolbarView = self.capturingToolbarView;
    
    // View
    UIButton *cameraButton = [JPSCameraButton button];
    [cameraButton addTarget:self action:@selector(takePicture:) forControlEvents:UIControlEventTouchUpInside];
    
    [view addSubview:cameraButton];
    self.cameraButton = cameraButton;
    
    // Constraints
    cameraButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *vertical = [NSLayoutConstraint constraintWithItem:cameraButton
                                                                attribute:NSLayoutAttributeCenterY
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:view
                                                                attribute:NSLayoutAttributeCenterY
                                                               multiplier:1.0f
                                                                 constant:0];
    NSLayoutConstraint *horizontal = [NSLayoutConstraint constraintWithItem:cameraButton
                                                                  attribute:NSLayoutAttributeCenterX
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:capturingToolbarView
                                                                  attribute:NSLayoutAttributeCenterX
                                                                 multiplier:1.0
                                                                   constant:0.0];
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:cameraButton
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1.0f
                                                              constant:66.0f];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:cameraButton
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1.0f
                                                               constant:66.0f];
    [view addConstraints:@[vertical, horizontal, width, height]];
}

- (void)addCancelButton
{
    UIView *view = self.view;
    UIView *capturingToolbarView = self.capturingToolbarView;
    
    // View
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelButton.titleLabel.font = [UIFont systemFontOfSize:18.0f];
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    [view addSubview:cancelButton];
    self.cancelButton = cancelButton;
    
    // Constraints
    NSLayoutConstraint *horizontal = [NSLayoutConstraint constraintWithItem:cancelButton
                                                             attribute:NSLayoutAttributeCenterX
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:capturingToolbarView
                                                             attribute:NSLayoutAttributeCenterX
                                                            multiplier:1.0f
                                                              constant:0.0f];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:cancelButton
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0f
                                                               constant:-19.5f];
    [view addConstraints:@[horizontal, bottom]];
}

- (void)addFlashButton
{
    UIView *view = self.view;
    
    // View
    UIButton *flashButton = [UIButton buttonWithType:UIButtonTypeSystem];
    flashButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *flashButtonImage = [[UIImage imageNamed:@"JPSImagePickerController.bundle/flash_button"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    [flashButton setImage:flashButtonImage forState:UIControlStateNormal];
    [flashButton setTitle:@" On" forState:UIControlStateNormal];
    [flashButton addTarget:self action:@selector(didPressFlashButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [view addSubview:flashButton];
    self.flashButton = flashButton;
    
    // Constraints
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:flashButton
                                                            attribute:NSLayoutAttributeLeft
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:view
                                                            attribute:NSLayoutAttributeLeft
                                                           multiplier:1.0f
                                                             constant:8.0f];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:flashButton
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:view
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1.0f
                                                            constant:9.5f];
    [view addConstraints:@[left, top]];
}

- (void)addCameraSwitchButton
{
    UIView *view = self.view;
    UIView *capturingToolbarView = self.capturingToolbarView;
    
    // View
    UIButton *cameraSwitchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    cameraSwitchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [cameraSwitchButton setBackgroundImage:[UIImage imageNamed:@"JPSImagePickerController.bundle/camera_switch_button"] forState:UIControlStateNormal];
    [cameraSwitchButton addTarget:self action:@selector(didPressCameraSwitchButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [view addSubview:cameraSwitchButton];
    self.cameraSwitchButton = cameraSwitchButton;
    
    // Constraints
    NSLayoutConstraint *horizontal = [NSLayoutConstraint constraintWithItem:cameraSwitchButton
                                                                  attribute:NSLayoutAttributeCenterX
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:capturingToolbarView
                                                                  attribute:NSLayoutAttributeCenterX
                                                                 multiplier:1.0
                                                                   constant:0.0];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:cameraSwitchButton
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:capturingToolbarView
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1.0
                                                            constant:JPSImagePickerControllerButtonInset];
    [view addConstraints:@[horizontal, top]];
}

- (void)addPreviewImageView
{
    UIView *view = self.view;
    
    // View
    UIImageView *previewImageView = [[UIImageView alloc] initWithFrame:view.bounds];
    previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    [view addSubview:previewImageView];
    self.previewImageView = previewImageView;

    // Constraints
    previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray *constraints = [NSLayoutConstraint bnr_constraintsForView:previewImageView toMatchFrameOfView:view];
    [view addConstraints:constraints];
}

- (void)addCapturePreviewView
{
    UIView *view = self.view;
    
    // View
    JPSAVCaptureVideoPreviewLayerHostingView *capturePreviewView = [[JPSAVCaptureVideoPreviewLayerHostingView alloc] initWithFrame:view.bounds];
    capturePreviewView.layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    self.capturePreviewView = capturePreviewView;
    [view insertSubview:capturePreviewView atIndex:0];
    
    // Constraints
    capturePreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray *constraints = [NSLayoutConstraint bnr_constraintsForView:capturePreviewView toMatchFrameOfView:view];
    [view addConstraints:constraints];
}

- (void)addRetakeButton
{
    UIView *view = self.view;
    UIView *editingToolbarView = self.editingToolbarView;
    
    // View
    UIButton *retakeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UILabel *titleLabel = retakeButton.titleLabel;
    titleLabel.font = [UIFont systemFontOfSize:18.0f];
    titleLabel.textColor = [UIColor whiteColor];
    [retakeButton setTitle:@"Retake" forState:UIControlStateNormal];
    
    [view addSubview:retakeButton];
    self.retakeButton = retakeButton;
    
    // Constraints
    retakeButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:retakeButton
                                                            attribute:NSLayoutAttributeLeft
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:editingToolbarView
                                                            attribute:NSLayoutAttributeLeft
                                                           multiplier:1.0
                                                             constant:JPSImagePickerControllerButtonInset];
    NSLayoutConstraint *vertical = [NSLayoutConstraint constraintWithItem:retakeButton
                                                                attribute:NSLayoutAttributeCenterY
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:editingToolbarView
                                                                attribute:NSLayoutAttributeCenterY
                                                               multiplier:1.0
                                                                 constant:0.0];
    [view addConstraints:@[left, vertical]];
}

- (void)addRetakeOverlayButton
{
    UIView *view = self.view;
    UIView *editingToolbarView = self.editingToolbarView;
    UIButton *retakeButton = self.retakeButton;
    
    // View
    UIButton *retakeOverlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [retakeOverlayButton addTarget:self action:@selector(retake:) forControlEvents:UIControlEventTouchUpInside];
    
    [view addSubview:retakeOverlayButton];
    self.retakeOverlayButton = retakeOverlayButton;
    
    // Constraints
    retakeOverlayButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:retakeOverlayButton
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:editingToolbarView
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1.0
                                                            constant:0.0];
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:retakeOverlayButton
                                                            attribute:NSLayoutAttributeLeft
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:editingToolbarView
                                                            attribute:NSLayoutAttributeLeft
                                                           multiplier:1.0
                                                             constant:0.0];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:retakeOverlayButton
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:editingToolbarView
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0
                                                               constant:0.0];
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:retakeOverlayButton
                                                             attribute:NSLayoutAttributeTrailing
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:retakeButton
                                                             attribute:NSLayoutAttributeTrailing
                                                            multiplier:1.0
                                                              constant:0.0];
    [view addConstraints:@[top, right, bottom, left]];
}

- (void)addUseButton
{
    UIView *view = self.view;
    UIView *editingToolbarView = self.editingToolbarView;
    
    // View
    UIButton *useButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UILabel *titleLabel = useButton.titleLabel;
    titleLabel.font = [UIFont systemFontOfSize:18.0f];
    titleLabel.textColor = [UIColor whiteColor];
    [useButton setTitle:@"Use Photo" forState:UIControlStateNormal];
    
    [view addSubview:useButton];
    self.useButton = useButton;
    
    // Constraints
    useButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:useButton
                                                             attribute:NSLayoutAttributeRight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:editingToolbarView
                                                             attribute:NSLayoutAttributeRight
                                                            multiplier:1.0
                                                              constant:-JPSImagePickerControllerButtonInset];
    NSLayoutConstraint *vertical = [NSLayoutConstraint constraintWithItem:useButton
                                                                attribute:NSLayoutAttributeCenterY
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:editingToolbarView
                                                                attribute:NSLayoutAttributeCenterY
                                                               multiplier:1.0
                                                                 constant:0.0];
    [view addConstraints:@[right, vertical]];
}

- (void)addUseOverlayButton
{
    UIView *view = self.view;
    UIView *editingToolbarView = self.editingToolbarView;
    UIButton *useButton = self.useButton;
    
    // View
    UIButton *useOverlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [useOverlayButton addTarget:self action:@selector(didPressUseButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [view addSubview:useOverlayButton];
    self.useOverlayButton = useOverlayButton;
    
    // Constraints
    useOverlayButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:useOverlayButton
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:editingToolbarView
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1.0
                                                            constant:0.0];
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:useOverlayButton
                                                             attribute:NSLayoutAttributeRight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:editingToolbarView
                                                             attribute:NSLayoutAttributeRight
                                                            multiplier:1.0
                                                              constant:0.0];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:useOverlayButton
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:editingToolbarView
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0
                                                               constant:0.0];
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:useOverlayButton
                                                            attribute:NSLayoutAttributeLeading
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:useButton
                                                            attribute:NSLayoutAttributeLeading
                                                           multiplier:1.0
                                                             constant:-JPSImagePickerControllerButtonInset];
    [view addConstraints:@[top, right, bottom, left]];
}

#pragma mark - Update UI

- (void)updateSubviewsHiddenFromState
{
    [self updateCapturingToolbarViewHidden];
    [self updateEditingToolbarViewHidden];
    
    [self updateFlashButtonHidden];
    [self updateCameraSwitchButtonHidden];
    [self updateCapturePreviewViewHidden];
    [self updatePreviewImageViewHidden];
    [self updateRetakeButtonHidden];
    [self updateRetakeOverlayButtonHidden];
    [self updateUseButtonHidden];
    [self updateUseOverlayButtonHidden];
    
    [self updateCameraButtonHidden];
    [self updateCancelButtonHidden];
}

- (void)updateCapturingToolbarViewHidden
{
    BOOL capturing = (self.state == JPSImagePickerControllerStateCapturing);
    
    BOOL visible = capturing;
    
    self.capturingToolbarView.hidden = !visible;
}

- (void)updateEditingToolbarViewHidden
{
    BOOL captured = (self.state == JPSImagePickerControllerStateCaptured);
    
    BOOL visible = captured;
    
    self.editingToolbarView.hidden = !visible;
}

- (void)updateFlashButtonHidden
{
    BOOL capturing = (self.state == JPSImagePickerControllerStateCapturing);
    BOOL deviceHasFlash = self.currentDevice.hasFlash;
    
    BOOL visible = deviceHasFlash && !capturing;
    
    self.flashButton.hidden = !visible;
}

- (void)updateCameraSwitchButtonHidden
{
    BOOL capturing = (self.state == JPSImagePickerControllerStateCapturing);
    
    BOOL frontCameraAvailable = [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
    BOOL rearCameraAvailable = [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
    BOOL twoCamerasAvailable = frontCameraAvailable && rearCameraAvailable;
    
    BOOL visible = capturing && twoCamerasAvailable;
    
    self.cameraSwitchButton.hidden = !visible;
}

- (void)updateCapturePreviewViewHidden
{
    BOOL capturing = (self.state == JPSImagePickerControllerStateCapturing);
    
    BOOL visible = capturing;
    
    self.capturePreviewView.hidden = !visible;
}

- (void)updatePreviewImageViewHidden
{
    BOOL captured = (self.state == JPSImagePickerControllerStateCaptured);
    
    BOOL visible = captured;
    
    self.previewImageView.hidden = !visible;
}

- (void)updateRetakeButtonHidden
{
    BOOL captured = (self.state == JPSImagePickerControllerStateCaptured);
    
    BOOL visible = captured;
    
    self.retakeButton.hidden = !visible;
}

- (void)updateRetakeOverlayButtonHidden
{
    BOOL captured = (self.state == JPSImagePickerControllerStateCaptured);
    
    BOOL visible = captured;
    
    self.retakeOverlayButton.hidden = !visible;
}

- (void)updateUseButtonHidden
{
    BOOL captured = (self.state == JPSImagePickerControllerStateCaptured);
    
    BOOL visible = captured;
    
    self.useButton.hidden = !visible;
}

- (void)updateUseOverlayButtonHidden
{
    BOOL captured = (self.state == JPSImagePickerControllerStateCaptured);
    
    BOOL visible = captured;
    
    self.useOverlayButton.hidden = !visible;
}

- (void)updateCameraButtonHidden
{
    BOOL capturing = (self.state == JPSImagePickerControllerStateCapturing);
    
    BOOL visible = capturing;
    
    self.cameraButton.hidden = !visible;
}

- (void)updateCancelButtonHidden
{
    BOOL capturing = (self.state == JPSImagePickerControllerStateCapturing);
    
    BOOL visible = capturing;
    
    self.cancelButton.hidden = !visible;
}

- (void)updateCapturePreviewViewLayerConnectionVideoOrientationFromInterfaceOrientation
{
    [self updateCapturePreviewViewLayerConnectionVideoOrientationFromInterfaceOrientation:self.interfaceOrientation];
}

- (void)updateCapturePreviewViewLayerConnectionVideoOrientationFromInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    self.capturePreviewView.layer.connection.videoOrientation = AVCaptureVideoOrientationFromUIDeviceOrientation(orientation);
}

#pragma mark - Helpers: Volume Button Handler

- (void)setupVolumeButtonHandler
{
    if (self.volumeButtonTakesPicture) {
        __weak typeof(self) weak_self = self;
        self.volumeButtonHandler = [JPSVolumeButtonHandler volumeButtonHandlerWithUpBlock:^{
            __strong typeof(self) strong_self = weak_self;
            if (strong_self) {
                [strong_self takePicture:nil];
            }
        }
                                                                                downBlock:nil];
    }
}

- (void)teardownVolumeButtonHandler
{
    self.volumeButtonHandler = nil;
}

#pragma mark - UIViewController Overrides

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [self updateCapturePreviewViewLayerConnectionVideoOrientationFromInterfaceOrientation:toInterfaceOrientation];
}

#pragma mark - Helpers: Capture Session

- (void)setupSession
{
    self.state = JPSImagePickerControllerStateBeginningCapture;
    [self updateSubviewsHiddenFromState];
    
    __weak typeof(self) weak_self = self;
    NSOperation *setupOperation = [NSBlockOperation blockOperationWithBlock:^{
        __strong typeof(self) strong_self = weak_self;
        if (strong_self) {
            AVCaptureSession *session = [[AVCaptureSession alloc] init];
            session.sessionPreset = AVCaptureSessionPresetPhoto;
            AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            NSError *error = nil;
            
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
            if (!input) return;
            
            [session addInput:input];
            
            // Turn on point autofocus for middle of view
            NSError *lockError = nil;
            BOOL lockSuccess = [device lockForConfiguration:&lockError];
            if (lockSuccess) {
                if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                    device.focusPointOfInterest = CGPointMake(0.5,0.5);
                    device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
                }
                if ([device isFlashModeSupported:AVCaptureFlashModeOn]) {
                    device.flashMode = AVCaptureFlashModeOn;
                }
            }
            [device unlockForConfiguration];
            
            // Still Image Output
            AVCaptureStillImageOutput *stillOutput = [[AVCaptureStillImageOutput alloc] init];
            stillOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG};
            [session addOutput:stillOutput];
            
            strong_self.captureStillImageOutput = stillOutput;
            
            [session startRunning];
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong typeof(self) strong_self = weak_self;
                if (strong_self) {
                    strong_self.session = session;
                    
                    if (session) {
                        strong_self.state = JPSImagePickerControllerStateCapturing;
                        [strong_self updateSubviewsHiddenFromState];
                    } else {
                        strong_self.state = JPSImagePickerControllerStateError;
                        [strong_self updateSubviewsHiddenFromState];
                    }
                }
            });
        }
    }];
    
    [self.captureQueue addOperation:setupOperation];
}

- (void)teardownSession
{
    [self.captureQueue cancelAllOperations];
    
    __weak typeof(self) weak_self = self;
    NSOperation *teardownOperation = [NSBlockOperation blockOperationWithBlock:^{
        __strong typeof(self) strong_self = weak_self;
        if (strong_self) {
            AVCaptureSession *session = strong_self.session;
            [session stopRunning];
            for (AVCaptureInput *input in session.inputs) {
                [session removeInput:input];
            }
            for (AVCaptureOutput *output in session.outputs) {
                [session removeOutput:output];
            }
            strong_self.session = nil;
        }
    }];
    [self.captureQueue addOperation:teardownOperation];
}

#pragma mark - Actions

- (IBAction)takePicture:(id)sender
{
    if (!self.cameraButton.enabled) return;
    
    AVCaptureStillImageOutput *output = self.captureStillImageOutput;
    AVCaptureConnection *videoConnection = output.connections.lastObject;
    if (!videoConnection) return;
    
    self.cameraButton.enabled = NO;

    __weak typeof(self) weak_self = self;
    [output captureStillImageAsynchronouslyFromConnection:videoConnection
                                        completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                            __strong typeof(self) strong_self = weak_self;
                                            if (strong_self) {
                                                [self doCaptureStillImageCompletionWithImageDataSampleBuffer:imageDataSampleBuffer error:error];
                                            }
                                        }];
}

- (void)doCaptureStillImageCompletionWithImageDataSampleBuffer:(CMSampleBufferRef)imageDataSampleBuffer error:(NSError *)error
{
    if (imageDataSampleBuffer) {
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImageOrientation imageOrientation = [JPSImagePickerController currentImageOrientation];
        self.imageOrientation = imageOrientation;
        UIImage *image = [UIImage imageWithCGImage:[[[UIImage alloc] initWithData:imageData] CGImage]
                                             scale:1.0f
                                       orientation:imageOrientation];
        self.previewImage = image;
        self.state = JPSImagePickerControllerStateCaptured;
        
        [self delegateCalloutDidCaptureImage:image];
        if (self.editingEnabled) {
            [self updateSubviewsHiddenFromState];
        } else {
            [self delegateCalloutDidConfirmImage:image];
        }
    } else {
        self.cameraButton.enabled = YES;
    }
}

- (IBAction)cancelButtonPressed:(id)sender
{
    [self delegateCalloutDidCancel];
}

- (IBAction)didPressFlashButton:(id)sender
{
    // Expand to show flash modes
    AVCaptureDevice *device = [self currentDevice];
    // Turn on point autofocus for middle of view
    NSError *lockError = nil;
    BOOL lockSuccess = [device lockForConfiguration:&lockError];
    if (lockSuccess) {
        if (device.flashMode == AVCaptureFlashModeOff) {
            device.flashMode = AVCaptureFlashModeOn;
            [self.flashButton setTitle:@" On" forState:UIControlStateNormal];
        } else {
            device.flashMode = AVCaptureFlashModeOff;
            [self.flashButton setTitle:@" Off" forState:UIControlStateNormal];
        }
    }
    [device unlockForConfiguration];
}

- (IBAction)didPressCameraSwitchButton:(id)sender
{
    // Input Switch
    __weak typeof(self) weak_self = self;
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        __strong typeof(self) strong_self = weak_self;
        if (strong_self) {
            AVCaptureSession *session = strong_self.session;
            AVCaptureDeviceInput *input = session.inputs.firstObject;
            
            [session stopRunning];
            [session removeInput:input];
            
            AVCaptureDevicePosition currentCaptureDevicePosition =
            input.device.position;
            AVCaptureDevicePosition newCaptureDevicePosition =
            [strong_self captureDevicePositionAfterCaptureDevicePosition:currentCaptureDevicePosition];
            AVCaptureDevice *device =
            [strong_self captureDeviceForCaptureDevicePosition:newCaptureDevicePosition];
            
            NSError *error = nil;
            input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                          error:&error];
            if (!input) return;
            
            [session addInput:input];
            [session startRunning];
            
            dispatch_sync(dispatch_get_main_queue(), ^{
            });
        }
    }];
    operation.queuePriority = NSOperationQueuePriorityVeryHigh;
    [self.captureQueue addOperation:operation];
    
    // Flip Animation
    [UIView transitionWithView:self.capturePreviewView
                      duration:1.0f
                       options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowAnimatedContent
                    animations:nil
                    completion:nil];
}

- (IBAction)retake:(id)sender
{
    self.state = JPSImagePickerControllerStateCapturing;
    [self updateSubviewsHiddenFromState];
    self.cameraButton.enabled = YES;
}

- (IBAction)didPressUseButton:(id)sender
{
    [self delegateCalloutDidConfirmImage:self.previewImage];
}

#pragma mark - Orientation

+ (UIImageOrientation)currentImageOrientation {
    // This is weird, but it works
    // By all means fix it, but make sure to test it afterwards
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    UIImageOrientation imageOrientation = UIImageOrientationRight;
    
    switch (deviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            imageOrientation = UIImageOrientationUp;
            break;
            
        case UIDeviceOrientationLandscapeRight:
            imageOrientation = UIImageOrientationDown;
            break;
            
        case UIDeviceOrientationPortraitUpsideDown:
            imageOrientation = UIImageOrientationLeft;
            break;
            
        default:
            break;
    }
    
    return imageOrientation;
}

#pragma mark - Delegate Indirection

- (void)delegateCalloutDidCaptureImage:(UIImage *)image
{
    if ([self.delegate respondsToSelector:@selector(picker:didCaptureImage:)]) {
        [self.delegate picker:self didCaptureImage:image];
    }
}

- (void)delegateCalloutDidConfirmImage:(UIImage *)image
{
    if ([self.delegate respondsToSelector:@selector(picker:didConfirmImage:)]) {
        [self.delegate picker:self didConfirmImage:image];
    }
}

- (void)delegateCalloutDidCancel
{
    if ([self.delegate respondsToSelector:@selector(pickerDidCancel:)]) {
        [self.delegate pickerDidCancel:self];
    }
}

@end

static AVCaptureVideoOrientation AVCaptureVideoOrientationFromUIDeviceOrientation(UIInterfaceOrientation deviceOrientation)
{
    static NSDictionary *dictionary = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary *mutableDictionary = [[NSMutableDictionary alloc] init];
        
#undef SetVideoOrientationForDeviceOrientation
#define SetVideoOrientationForDeviceOrientation( videoOrientation , deviceOrientation ) \
    do { \
        mutableDictionary[@(deviceOrientation)] = @(videoOrientation); \
    } while(0)
        
        SetVideoOrientationForDeviceOrientation( AVCaptureVideoOrientationPortrait , UIInterfaceOrientationPortrait );
        SetVideoOrientationForDeviceOrientation( AVCaptureVideoOrientationPortraitUpsideDown , UIInterfaceOrientationPortraitUpsideDown );
        SetVideoOrientationForDeviceOrientation( AVCaptureVideoOrientationLandscapeRight , UIInterfaceOrientationLandscapeRight );
        SetVideoOrientationForDeviceOrientation( AVCaptureVideoOrientationLandscapeLeft , UIInterfaceOrientationLandscapeLeft );
        
#undef SetVideoOrientationForDeviceOrientation
        
        dictionary = [mutableDictionary copy];
    });
    
    NSNumber *resultNumber = dictionary[@(deviceOrientation)];
    AVCaptureVideoOrientation result = resultNumber.integerValue;
    return result;
}
