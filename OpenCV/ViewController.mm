//
//  ViewController.m
//  OpenCV
//
//  Created by Ferose Babu on 8/19/16.
//  Copyright © 2016 WME. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "ViewController.h"
#import <opencv2/videoio/cap_ios.h>
#import <opencv2/opencv.hpp>

using namespace cv;
using namespace std;

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic) AVAssetReaderTrackOutput *output;
@property (nonatomic) AVAssetReader *assetReader;

@property (nonatomic) BOOL firstFrameIsProcessed;

@property (nonatomic) CGPoint topLeft;


@property (nonatomic) UIImage *currentImage;

@property (weak, nonatomic) IBOutlet UISlider *hLower;
@property (weak, nonatomic) IBOutlet UISlider *sLower;
@property (weak, nonatomic) IBOutlet UISlider *vLower;

@property (weak, nonatomic) IBOutlet UISlider *hUpper;
@property (weak, nonatomic) IBOutlet UISlider *sUpper;
@property (weak, nonatomic) IBOutlet UISlider *vUpper;
@end

@implementation ViewController {
    TermCriteria term_crit;
    cv::Rect track_window;
    Mat roi_hist;
    
    Scalar lowerBound;
    Scalar upperBound;
}

- (IBAction)sliderMoved:(id)sender {
    lowerBound = Scalar(self.hLower.value, self.sLower.value, self.vLower.value);
    upperBound = Scalar(self.hUpper.value, self.sUpper.value, self.vUpper.value);
    
    if (self.firstFrameIsProcessed) {
        return;
    }
    
    Mat mat = [self cvMatFromUIImage:self.currentImage];
    [self processNextFrame:mat];
    
    self.imageView.image = [self UIImageFromCVMat:mat];
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    if (!self.firstFrameIsProcessed) {
        UITouch *touch = touches.anyObject;
        
        CGPoint p = [touch locationInView:self.imageView];
        
        self.topLeft = p;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (!self.firstFrameIsProcessed) {
        UITouch *touch = touches.anyObject;
        
        CGPoint p = [touch locationInView:self.imageView];
        
        CGFloat scaleX = (self.imageView.image.size.width/self.imageView.frame.size.width);
        CGFloat scaleY = (self.imageView.image.size.height/self.imageView.frame.size.height);
        
        track_window = cv::Rect(self.topLeft.x*scaleX,
                                self.topLeft.y*scaleY,
                                (p.x-self.topLeft.x)*scaleX,
                                (p.y-self.topLeft.y)*scaleY);
        [self nextFrame];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
//    NSString* cascadePath = [[NSBundle mainBundle]
//                             pathForResource:@"haarcascade_frontalface_alt"
//                             ofType:@"xml"];
//    faceDetector.load([cascadePath UTF8String]);

    
    NSURL *videoURL = [[NSBundle mainBundle] URLForResource:@"video2" withExtension:@"mp4"];
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    NSError *err;
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&err];
    
    NSArray* video_tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack* video_track = [video_tracks objectAtIndex:0];

    NSDictionary* settings = @{
                               (id)kCVPixelBufferPixelFormatTypeKey     : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],  //kCVPixelFormatType_422YpCbCr8
                               (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary]
                               };
    
    AVAssetReaderTrackOutput* asset_reader_output = [[AVAssetReaderTrackOutput alloc] initWithTrack:video_track outputSettings:settings];
    [assetReader addOutput:asset_reader_output];
    
    [assetReader startReading];
    self.output = asset_reader_output;
    self.assetReader = assetReader;

    [self generateFirstFrame];
    
    lowerBound = Scalar(self.hLower.value, self.sLower.value, self.vLower.value);
    upperBound = Scalar(self.hUpper.value, self.sUpper.value, self.vUpper.value);
//    [self nextFrame];

}

- (void) generateFirstFrame
{
    if ( [self.assetReader status]==AVAssetReaderStatusReading ) {
        CMSampleBufferRef sampleBuffer = [self.output copyNextSampleBuffer];
        CGImageRef imageRef = [self imageFromSampleBuffer:sampleBuffer];
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        
        self.imageView.image = image;
        self.currentImage = image;
    }
}

- (void) nextFrame
{
    if ( [self.assetReader status]==AVAssetReaderStatusReading ) {
        if (!self.firstFrameIsProcessed) {
            UIImage *image = self.imageView.image;
            if (image) {
                Mat mat = [self cvMatFromUIImage:image];
                [self processFirstFrame:mat];
                image = [self UIImageFromCVMat:mat];
                
                self.imageView.image = image;
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1.0/30) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self nextFrame];
                });
            }
            
            self.firstFrameIsProcessed = YES;
        }
        else {
            CMSampleBufferRef sampleBuffer = [self.output copyNextSampleBuffer];
            CGImageRef imageRef = [self imageFromSampleBuffer:sampleBuffer];
            UIImage *image = [UIImage imageWithCGImage:imageRef];
            if (image) {
                Mat mat = [self cvMatFromUIImage:image];
                [self processNextFrame:mat];
                image = [self UIImageFromCVMat:mat];
                
                self.imageView.image = image;
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1.0/30) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self nextFrame];
                });
            }
        }
    }
}


- (void)processFirstFrame:(Mat&)image;
{

}

- (void)processNextFrame:(Mat&)image;
{
    Mat hsv;
    cvtColor(image, hsv, CV_BGR2HSV);
    
    Mat mask;
    inRange(hsv, lowerBound, upperBound, mask);
    
//    erode(mask, mask, NULL, cv::Point(-1,-1), 2);
//    dilate(mask, mask, NULL, cv::Point(-1,-1), 2);
    
//    mask.copyTo(image);
    
    vector<vector<cv::Point> > contours;

    findContours(mask, contours, RETR_EXTERNAL, CHAIN_APPROX_SIMPLE);
    
    if (contours.size() > 0) {
//        vector<cv::Point> maxContour;
//        for (auto i = contours.begin(); i != contours.end(); i++) {
//            vector<cv::Point> contour = *i;
//            if (contour.size() > maxContour.size()) {
//                maxContour = contour;
//            }
//        }
//        
//        double area = contourArea(maxContour);
//        
//        cv::Point2f center;
//        float radius;
//        minEnclosingCircle(maxContour, center, radius);
//        
//        
//        cv::circle(image, center, radius, Scalar(255,0,0));
        
        
        
        for (auto i = contours.begin(); i != contours.end(); i++) {
            vector<cv::Point> contour = *i;
            
            cv::Point2f center;
            float radius;
            minEnclosingCircle(contour, center, radius);
            
            
            cv::circle(image, center, radius, Scalar(255,0,0));
        }
    }
}

- (CGImageRef) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer // Create a CGImageRef from sample buffer data
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);        // Lock the image buffer
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);   // Get information of the image
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    /* CVBufferRelease(imageBuffer); */  // do not call this!
    
    return newImage;
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}


@end
