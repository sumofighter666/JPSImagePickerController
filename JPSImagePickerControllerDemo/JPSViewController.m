//
//  JPSViewController.m
//  JPSImagePickerControllerDemo
//
//  Created by JP Simard on 1/31/2014.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

#import "JPSViewController.h"
#import "JPSImagePickerController.h"

@interface JPSViewController ()
    <JPSImagePickerDelegate,
    UINavigationControllerDelegate,
    UIImagePickerControllerDelegate>

@property (nonatomic, strong) UIButton    *button;
@property (nonatomic, strong) UIButton    *altButton;
@property (nonatomic, strong) UIImageView *imageView;

@end

@implementation JPSViewController

#pragma mark - UI

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self setupButton];
    [self setupAltButton];
    [self setupImageView];
}

- (void)setupButton {
    // Button
    _button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_button setTitle:@"Launch Image Picker" forState:UIControlStateNormal];
    [_button addTarget:self action:@selector(launchImagePicker) forControlEvents:UIControlEventTouchUpInside];
    _button.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_button];
    
    // Constraints
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:_button
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1.0f
                                                                constant:0];
    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:_button
                                                               attribute:NSLayoutAttributeCenterY
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterY
                                                              multiplier:1.0f
                                                                constant:0];
    [self.view addConstraints:@[centerX, centerY]];
}

- (void)setupAltButton {
    // Button
    _altButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_altButton setTitle:@"Launch System Image Picker" forState:UIControlStateNormal];
    [_altButton addTarget:self action:@selector(launchSystemImagePicker) forControlEvents:UIControlEventTouchUpInside];
    _altButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_altButton];
    
    // Constraints
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:_altButton
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1.0
                                                                constant:0.0];
    NSLayoutConstraint *belowButton = [NSLayoutConstraint constraintWithItem:_altButton
                                                                   attribute:NSLayoutAttributeTop
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:_button
                                                                   attribute:NSLayoutAttributeBottom
                                                                  multiplier:1.0
                                                                    constant:10.0];
    [self.view addConstraints:@[centerX, belowButton]];
}

- (void)setupImageView {
    // Image View
    _imageView = [[UIImageView alloc] init];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:_imageView];
    
    // Constraints
    NSArray *vertical = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[_button][_imageView]|"
                                                                options:0
                                                                metrics:nil
                                                                  views:NSDictionaryOfVariableBindings(_button, _imageView)];
    NSArray *horizontal = [NSLayoutConstraint constraintsWithVisualFormat:@"|[_imageView]|"
                                                                  options:0
                                                                  metrics:nil
                                                                    views:NSDictionaryOfVariableBindings(_imageView)];
    [self.view addConstraints:vertical];
    [self.view addConstraints:horizontal];
}

#pragma mark - Actions

- (void)launchImagePicker {
    JPSImagePickerController *imagePicker = [[JPSImagePickerController alloc] init];
    imagePicker.zoomEnabled = NO;
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (void)launchSystemImagePicker {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

#pragma mark - JPSImagePickerControllerDelegate

#if 0 //This gives the controller ridiculous behavior.
- (void)picker:(JPSImagePickerController *)picker didCaptureImage:(UIImage *)picture
    picker.confirmationString = @"Zoom in to make sure you're happy with your picture";
    picker.confirmationOverlayString = @"Analyzing Image...";
    picker.confirmationOverlayBackgroundColor = [UIColor orangeColor];
    double delayInSeconds = 1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        picker.confirmationOverlayString = @"Good Quality";
        picker.confirmationOverlayBackgroundColor = [UIColor colorWithRed:0 green:0.8f blue:0 alpha:1.0f];
    });
}
#endif

- (void)picker:(JPSImagePickerController *)picker didConfirmImage:(UIImage *)picture {
    self.imageView.image = picture;
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.imageView.image = info[UIImagePickerControllerOriginalImage];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
