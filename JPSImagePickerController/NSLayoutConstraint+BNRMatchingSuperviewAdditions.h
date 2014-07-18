//
//  NSLayoutConstraint+BNRMatchingSuperviewAdditions.h
//  JPSImagePickerControllerDemo
//
//  Created by Nate Chandler on 7/17/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NSLayoutConstraint (BNRMatchingSuperviewAdditions)

+ (NSArray/*NSLayoutConstraint*/ *)bnr_constraintsForView:(UIView *)view toMatchFrameOfView:(UIView *)matchedView;

@end
