//
//  JPSImagePickerController.h
//  JPSImagePickerController
//
//  Created by JP Simard on 1/31/2014.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol JPSImagePickerDelegate;

@interface JPSImagePickerController : UIViewController

#pragma mark - Feature Flags

// Confirmation screen enabled, default YES
@property (nonatomic) BOOL editingEnabled;

// Volume up button as trigger enabled, default YES
@property (nonatomic) BOOL volumeButtonTakesPicture;

// Front camera enabled, default YES
@property (nonatomic) BOOL frontCameraEnabled;

// Enable auto retake
@property (nonatomic, getter = isAutoRetakeEnabled) BOOL enableAutoRetake;

// Camera button
@property (nonatomic) UIButton *cameraButton;

#pragma mark - Delegate

@property (nonatomic, weak) id<JPSImagePickerDelegate> delegate;

@end

#pragma mark - Protocol

@protocol JPSImagePickerDelegate <NSObject>

@optional

// Called immediately after the picture was taken
- (void)picker:(JPSImagePickerController *)picker didCaptureImage:(UIImage *)picture;
// Called immediately after the "Use" button was tapped
- (void)picker:(JPSImagePickerController *)picker didConfirmImage:(UIImage *)picture;
// Called immediately after the "Cancel" button is tapped
- (void)pickerDidCancel:(JPSImagePickerController *)picker;

@end
