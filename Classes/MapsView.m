/* MapsView.m  -*- c-style: gnu -*- */

#import "MapsView.h"

#import "MapsLayer.h"
#import "MapsViewController.h"

@implementation MapsView

@synthesize controller = _controller;

+ (Class)layerClass
{
  return [MapsLayer class];
}

- (void)tapTimer:(NSTimer *)timer
{
  _tapTimer = nil;
  [_controller setUIHidden:![_controller isUIHidden] animated:YES];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  CGFloat level, new_level;

  [_tapTimer invalidate];
  _tapTimer = nil;

  level = [_controller currentLevelOfDetail];

  switch ([[event allTouches] count])
    {
    case 1:
      if ([[touches anyObject] tapCount] == 2)
	new_level = ceil (level - 1);
      else
	{
	  _tapTimer = [NSTimer scheduledTimerWithTimeInterval:.25 target:self
		       selector:@selector(tapTimer:) userInfo:nil repeats:NO];
	}
      break;
    case 2:
      new_level = floor (level + 1);
      break;
    }
    
  if (new_level != level)
    [_controller setCurrentLevelOfDetail:new_level animated:YES];
}

- (void)dealloc
{
  [_tapTimer invalidate];
  [super dealloc];
}

@end
