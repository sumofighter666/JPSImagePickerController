//
//  JPSAVCaptureVideoPreviewLayerHostingView.h
//  JPSImagePickerControllerDemo
//
//  Created by Nate Chandler on 7/17/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface JPSAVCaptureVideoPreviewLayerHostingView : UIView

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *layer;

@end
