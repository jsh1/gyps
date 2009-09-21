/* MapsView.h  -*- c-style: gnu -*- */

#import <UIKit/UIKit.h>

@class MapsViewController;

@interface MapsView : UIView
{
  MapsViewController *_controller;
  NSTimer *_tapTimer;
}

@property(nonatomic, assign) MapsViewController *controller;

@end

