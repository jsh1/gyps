/* MapsViewController.m  -*- c-style: gnu -*- */

#import "MapsViewController.h"

#import "GypsAppDelegate.h"
#import "LocationTableViewController.h"
#import "MapsLayer.h"
#import "MapsTableViewController.h"
#import "MapsView.h"

@implementation MapsViewController

@synthesize scrollView = _scrollView;

- (void)viewDidLoad
{
  NSString *str;
  MapsLayer *mapsLayer;

  [super viewDidLoad];

  _mapsView = [[MapsView alloc] initWithFrame:[_scrollView bounds]];
  [_mapsView setController:self];
  [_mapsView setTransform:CGAffineTransformMakeScale (1, -1)];
  [_scrollView addSubview:_mapsView];
  [_mapsView release];

  mapsLayer = (MapsLayer *) [_mapsView layer];

  [_scrollView setDelegate:self];
  [_scrollView setCanCancelContentTouches:NO];

  [_scrollView setMinimumZoomScale:
   1 / pow (2, ([mapsLayer levelsOfDetail]
		- [mapsLayer levelsOfDetailBias]))];
  [_scrollView setMaximumZoomScale:
   pow (2, [mapsLayer levelsOfDetailBias]) * 4];  

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(locationsChanged:)
   name:LocationsDidChange object:_locationController];

  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(currentLocationChanged:)
   name:CurrentLocationDidChange object:_locationController];

  str = [[NSUserDefaults standardUserDefaults] stringForKey:@"CurrentMapName"];

  if (str != nil)
    {
      for (NSDictionary *dict in [GypsAppDelegate allMaps])
	{
	  if ([[dict objectForKey:@"name"] isEqualToString:str])
	    {
	      [self setCurrentMap:dict];
	      break;
	    }
	}
    }

  if (_currentMap == nil)
    {
      NSArray *maps = [GypsAppDelegate allMaps];
      if ([maps count] != 0)
	[self setCurrentMap:[maps objectAtIndex:0]];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  UINavigationController *navController;
  navController = (id) [self parentViewController];
  [[navController navigationBar] setTranslucent:YES];
  [[navController toolbar] setTranslucent:YES];
  [[UIApplication sharedApplication]
   setStatusBarStyle:UIStatusBarStyleBlackTranslucent];
}

- (void)viewWillDisappear:(BOOL)animated
{
  UINavigationController *navController = (id) [self parentViewController];

  [super viewWillDisappear:animated];

  [self setUIHidden:NO];

  [[navController navigationBar] setTranslucent:NO];
  [[navController toolbar] setTranslucent:NO];

  [[UIApplication sharedApplication]
   setStatusBarStyle:UIStatusBarStyleBlackOpaque];
  [[UIApplication sharedApplication] setStatusBarHidden:NO animated:NO];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
  return _mapsView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView
    withView:(UIView *)view atScale:(float)scale
{
}

- (IBAction)mapListAction:(id)sender
{
  [self presentModalViewController:_tableController animated:YES];
}

- (void)tableDidSelectMap:(NSDictionary *)map
{
  [self setCurrentMap:map];
  [self dismissModalViewControllerAnimated:YES];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_locationController release];
  [_tableController release];
  [_scrollView release];
  [_currentMap release];
  [super dealloc];
}

- (void)locationsChanged:(NSNotification *)note
{
  [(MapsLayer *)[_mapsView layer]
   setLocations:[_locationController locations]];
}

- (void)currentLocationChanged:(NSNotification *)note
{
  [(MapsLayer *)[_mapsView layer]
   setCurrentLocation:[_locationController currentLocation]];
}

- (NSDictionary *)currentMap
{
  return _currentMap;
}

- (void)setCurrentMap:(NSDictionary *)map
{
  MapsLayer *mapsLayer = (MapsLayer *) [_mapsView layer];
  CLLocation *loc;
  CGRect r;
  CGPoint p;

  if (_currentMap != map)
    {
      [_currentMap release];
      _currentMap = [map retain];

      [self setTitle:[_currentMap objectForKey:@"name"]];

      [mapsLayer setMap:map];

      r = [_mapsView bounds];
      [_scrollView setZoomScale:1 animated:NO];
      [_scrollView setContentSize:[_mapsView bounds].size];
      [_scrollView setContentInset:UIEdgeInsetsMake (10, 10, 10, 10)];
      [_mapsView setCenter:CGPointMake (CGRectGetMidX (r), CGRectGetMidY (r))];

      [self locationsChanged:nil];
      [self currentLocationChanged:nil];

      loc = [_locationController currentLocation];
      if (loc != nil)
	{
	  p = [mapsLayer positionForWorldCoordinate:[loc coordinate]];
	  p = [mapsLayer convertPoint:p toLayer:[_scrollView layer]];
	  p.x -= [_scrollView bounds].size.width * .5;
	  p.y -= [_scrollView bounds].size.height * .5;
	  [_scrollView setContentOffset:p];
	}

      [[NSUserDefaults standardUserDefaults]
       setObject:[map objectForKey:@"name"] forKey:@"CurrentMapName"];
    }
}

- (CGFloat)currentLevelOfDetail
{
  return -log2 ([_scrollView zoomScale]);
}

- (void)setCurrentLevelOfDetail:(CGFloat)level animated:(BOOL)animated
{
  [_scrollView setZoomScale:pow (2, -level) animated:animated];
}

- (void)setCurrentLevelOfDetail:(CGFloat)level
{
  [self setCurrentLevelOfDetail:level animated:NO];
}

- (BOOL)isUIHidden
{
  UINavigationController *navController = (id) [self parentViewController];
  return [[navController navigationBar] alpha] == 0;
}

- (void)setUIHidden:(BOOL)state animated:(BOOL)flag
{
  UINavigationController *navController = (id) [self parentViewController];
  float alpha = state ? 0 : 1;
  UIEdgeInsets insets;

  if (flag)
    [UIView beginAnimations:@"fadeout" context:nil];

  [[navController navigationBar] setAlpha:alpha];
  [[navController toolbar] setAlpha:alpha];

  if (flag)
    [UIView commitAnimations];

  [[UIApplication sharedApplication] setStatusBarHidden:state animated:flag];

  insets = UIEdgeInsetsZero;
  if (!state)
    insets.bottom = [[navController toolbar] frame].size.height;
  [_scrollView setScrollIndicatorInsets:insets];
  
}

- (void)setUIHidden:(BOOL)state
{
  [self setUIHidden:state animated:NO];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)mode
{
  return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orient
    duration:(NSTimeInterval)dur
{
  [self setUIHidden:NO animated:NO];
}

@end
