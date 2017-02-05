//
//  ViewController.m
//  JKScreenRecorder
//
//  Created by Jakey on 2017/2/5.
//  Copyright © 2017年 Jakey. All rights reserved.
//

#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
     _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
     [_displayLink setPaused:NO];
}

- (void)tick:(CADisplayLink *)link {
    if (_lastTime == 0) {
        _lastTime = link.timestamp;
        return;
    }
    
    _count++;
    NSTimeInterval interval = link.timestamp - _lastTime;
    if (interval < 1) return;
    _lastTime = link.timestamp;
    float fps = _count / interval;
    _count = 0;
    
    NSString *text = [NSString stringWithFormat:@"%d FPS",(int)round(fps)];
    self.fpsLabel.text = text;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)startTouched:(id)sender {
    _sreenRecorder = [[JKScreenRecorder alloc]init];
    //不区分系统版本 直接使用截图合成视频
    //[_sreenRecorder startRecordingWithCapture];
    //根据不同版本的系统SDK 使用不同的API 两种开始方法调用一种即可
    [_sreenRecorder startRecordingWithHandler:^(NSError *error) {
        
    }];
    [_sreenRecorder screenRecording:^(NSTimeInterval duration) {
        self.timeLabel.text  = [@(duration) stringValue];
    }];
}

- (IBAction)stopTouched:(id)sender {
    [_sreenRecorder stopRecordingWithHandler:^(UIViewController *previewViewController, NSString *videoPath, NSError *error) {
        
        //videoPath非空为使用低版本截图方式保存视频 previewViewController为MPMoviePlayerViewController的实例
        if (videoPath) {
            MPMoviePlayerViewController *p = (MPMoviePlayerViewController*)previewViewController;
            [p.moviePlayer prepareToPlay];
            [p.moviePlayer play];
            [self presentMoviePlayerViewControllerAnimated:p];
//            存入相册 注意要在info.plist中增加 Privacy - Photo Library Usage Description
//            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
//            [library writeVideoAtPathToSavedPhotosAlbum:[NSURL fileURLWithPath:videoPath]
//                                        completionBlock:^(NSURL *assetURL, NSError *error) {
//                                            if (error) {
//                                                NSLog(@"Save video fail:%@",error);
//                                            } else {
//                                                NSLog(@"Save video succeed.");
//                                            }
//                                        }];
        }else{
             //videoPath空为使用ReplayKit.framework方式录制视频 previewViewController为RPPreviewViewController的实例
            [self presentViewController:previewViewController animated:YES completion:^{
                
            }];
        }
            
    }];
}
@end
