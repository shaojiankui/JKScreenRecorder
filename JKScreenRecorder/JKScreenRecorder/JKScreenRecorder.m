//
//  JKScreenRecorder.m
//  JKScreenRecorder
//
//  Created by Jakey on 2017/2/5.
//  Copyright © 2017年 www.skyfox.org. All rights reserved.
//
#define JKScreenRecorderFrameTime 0.05
#import "JKScreenRecorder.h"

@interface JKScreenRecorder ()<RPScreenRecorderDelegate,RPPreviewViewControllerDelegate>
{
    JKScreenRecording _screenRecording;
    JKScreenRecordStop _screenRecordStop;
    NSInteger _frameCount;
    BOOL _using8API;
    AVAssetWriter *_videoWriter;
    AVAssetWriterInput *_videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *_adaptor;
}
@end

@implementation JKScreenRecorder
-(BOOL)available{
    return YES;
}
- (void)startRecordingWithHandler:(void(^)(NSError *error))handler{
    if (NSClassFromString(@"RPScreenRecorder") != nil)
    {
        if ([[RPScreenRecorder sharedRecorder] isAvailable]) {
            [self startiOS9:handler];
        } else {
            NSLog(@"不支持支持ReplayKit录制! 使用原始截图方式");
            [self startRecordingWithCapture];
        }
    }
    else
    {
        [self startRecordingWithCapture];
    }
}
-(void)startRecordingWithCapture
{
    NSLog(@"录制开始");
    _using8API = YES;
    [self initVideoWriter];
    _recording = YES;
    [self nextFrame:YES];
}
-(void)startiOS9:(void(^)(NSError *error))handler{
    NSLog(@"支持ReplayKit录制");
    _using8API = NO;

    [[RPScreenRecorder sharedRecorder] startRecordingWithMicrophoneEnabled:NO handler:^(NSError *error){
        if(handler){
            handler(error);
        }
        NSLog(@"录制开始");
        if (error) {
            NSLog(@"错误信息 %@", error);
        } else {
            NSLog(@"录制成功开始");
            _recording = YES;
            [self nextFrame:NO];
        }
    }];

}

- (void)stopRecordingWithHandler:(JKScreenRecordStop)handler{
    _recording = NO;
    if (_using8API)
    {
        [_videoWriterInput markAsFinished];
        
        [_videoWriter finishWritingWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (handler) {
                    MPMoviePlayerViewController *player = [[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL fileURLWithPath:self.videoPath]];
                     [player.moviePlayer setControlStyle:MPMovieControlStyleFullscreen];
                    handler(player,self.videoPath,nil);
                }
            });
            _adaptor = nil;
            _videoWriterInput = nil;
            _videoWriter = nil;
        }];
        
     }else
    {
        [[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController *previewViewController, NSError *  error)
         {
             if (error)
             {
                 NSLog(@"停止录屏失败");
             } else
             {
                 previewViewController.previewControllerDelegate = self;
             }
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (handler) {
                     handler(previewViewController,nil,error);
                 }
             });
         }];
    }
}
- (void)previewController:(RPPreviewViewController *)previewController didFinishWithActivityTypes:(NSSet <NSString *> *)activityTypes {
    if ([activityTypes containsObject:@"com.apple.UIKit.activity.SaveToCameraRoll"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"保存成功");
        });
    }
    if ([activityTypes containsObject:@"com.apple.UIKit.activity.CopyToPasteboard"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"复制成功");

        });
    }
}
- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController {
    [previewController dismissViewControllerAnimated:YES completion:^{
        
    }];
}
- (void)screenRecording:(JKScreenRecording)screenRecording{
    _screenRecording = [screenRecording copy];
}
#pragma mark
- (void)nextFrame:(BOOL)lessiOS9
{
    if (!_recording) {
        return;
    }
    if (lessiOS9) {
        [self makeiOS8Frame];
    }
    if (_screenRecording) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _screenRecording(self.duration);
        });
    }
    _duration += JKScreenRecorderFrameTime;
    
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, JKScreenRecorderFrameTime*NSEC_PER_SEC);
    dispatch_after(time, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         [self nextFrame:lessiOS9];
    });
}
- (void)makeiOS8Frame
{
    _frameCount ++;
    if (_recording) {
        //CFAbsoluteTime interval = (CFAbsoluteTimeGetCurrent() - startTime) * 1000;
        // CMTime frametime = CMTimeMake((int)interval, 1000);
        NSUInteger fps = 24;
        CMTime frameTime = CMTimeMake(_frameCount,(int32_t)fps);
        [self appendVideoFrameAtTime:frameTime];
    }
}
- (void)appendVideoFrameAtTime:(CMTime)frameTime
{
    CGImageRef newImage = [self getScreenshot].CGImage;
    if (![_videoWriterInput isReadyForMoreMediaData])
    {
        NSLog(@"Not ready for video data");
    }
    else
    {
        if (_adaptor.assetWriterInput.readyForMoreMediaData)  {
            NSLog(@"Processing video frame (%zd)",_frameCount);
            CVPixelBufferRef buffer = [self pixelBufferFromCGImage:newImage];
            if(![_adaptor appendPixelBuffer:buffer withPresentationTime:frameTime]){
                NSError *error = _videoWriter.error;
                if(error) {
                    NSLog(@"Unresolved error %@,%@.", error, [error userInfo]);
                }
            }
            CVPixelBufferRelease(buffer);
        }
        else {
            printf("adaptor not ready %zd\n", _frameCount);
        }
        NSLog(@"**************************************************");
    }
}

- (BOOL)initVideoWriter{
    CGSize size = [[UIScreen mainScreen] bounds].size;
    
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    [[NSFileManager defaultManager] removeItemAtPath:[documents stringByAppendingPathComponent:@"movie.mov"] error:nil];
    _videoPath = [documents stringByAppendingPathComponent:@"movie.mov"];
    NSError *error;
    
    //Configure videoWriter
    NSURL   *fileUrl=[NSURL fileURLWithPath:_videoPath];
    _videoWriter = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(_videoWriter);
    
    //Configure videoWriterInput
    NSDictionary* videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:size.width*size.height], AVVideoAverageBitRateKey,
                                           nil ];
    
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:size.height], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSParameterAssert(_videoWriterInput);
    _videoWriterInput.expectsMediaDataInRealTime = YES;
    NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    _adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    
    //add input
    [_videoWriter addInput:_videoWriterInput];
    [_videoWriter startWriting];
    [_videoWriter startSessionAtSourceTime:kCMTimeZero];
    
//    dispatch_queue_t dispatchQueue = dispatch_queue_create("org.skyfox.mediaInputQueue", NULL);
//    [_videoWriterInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{
//        while ([_videoWriterInput isReadyForMoreMediaData])
//        {
//           [self makeiOS8Frame];
//        }
//        
//    }];
    return YES;
}


- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    CVPixelBufferRef pxbuffer = NULL;
    
    CGFloat frameWidth = CGImageGetWidth(image);
    CGFloat frameHeight = CGImageGetHeight(image);
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,frameWidth,frameHeight,kCVPixelFormatType_32ARGB,(__bridge CFDictionaryRef) options, &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameWidth, frameHeight, 8,CVPixelBufferGetBytesPerRow(pxbuffer),rgbColorSpace,(CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0, 0,frameWidth,frameHeight),  image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

- (UIImage *)getScreenshot
{
    NSLock *aLock = [NSLock new];
    [aLock lock];
    
    CGSize imageSize = [[UIScreen mainScreen] bounds].size;
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (UIWindow *window in [[UIApplication sharedApplication] windows])
    {
        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen])
        {
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, [window center].x, [window center].y);
            CGContextConcatCTM(context, [window transform]);
            CGContextTranslateCTM(context, -[window bounds].size.width * [[window layer] anchorPoint].x, -[window bounds].size.height * [[window layer] anchorPoint].y);
            [[window layer] renderInContext:context];
            CGContextRestoreGState(context);
        }
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [aLock unlock];
    return image;
}


@end
