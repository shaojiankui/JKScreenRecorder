//
//  ViewController.h
//  JKScreenRecorder
//
//  Created by Jakey on 2017/2/5.
//  Copyright © 2017年 Jakey. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JKScreenRecorder.h"
@interface ViewController : UIViewController
{
    JKScreenRecorder *_sreenRecorder;
    CADisplayLink *_displayLink;
    NSTimeInterval _lastTime;
    NSUInteger _count;
}
- (IBAction)startTouched:(id)sender;
- (IBAction)stopTouched:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UILabel *fpsLabel;
@end

