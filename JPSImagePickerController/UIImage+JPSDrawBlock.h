//
//  UIImage+JPSDrawBlock.h
//  JPSImagePickerController
//
//  Created by JP Simard on 1/31/2014.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^DrawBlock)(CGContextRef context, CGSize size);

@interface UIImage (JPSDrawBlock)

+ (UIImage *)jps_imageWithSize:(CGSize)size drawBlock:(DrawBlock)drawBlock;

@end
