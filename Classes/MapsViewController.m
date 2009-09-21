/* MapsViewController.m  -*- c-style: gnu -*- */

#import "MapsViewController.h"

#import "GypsAppDelegate.h"
#import "LocationTableViewController.h"
#import "MapsTableViewController.h"

#import <QuartzCore/CoreAnimation.h>

#define LOD_COUNT 16
#define LOD_BIAS 5
#define TILE_WIDTH 256
#define TILE_HEIGHT 256

#define MARKER_RADIUS 10
#define MARKER_LINE_WIDTH 4

struct MapCorner
{
  CLLocationCoordinate2D world_coord;
  CGPoint page_coord;
};

@interface MapsView : UIView
{
  MapsViewController *_controller;
  NSTimer *_tapTimer;
}
@property(nonatomic,assign) MapsViewController *controller;
@end

@interface MapsLayer : CATiledLayer
{
  NSDictionary *_map;
  CGPDFDocumentRef _document;
  CGPDFPageRef _page;
  CGRect _pageRect;
  struct MapCorner _mapCorners[4];
  CLLocation *_currentLocation;
  NSArray *_locations;
}
- (void)setMap:(NSDictionary *)dict;
- (void)setCurrentLocation:(CLLocation *)loc;
- (void)setLocations:(NSArray *)array;
- (CGPoint)positionForWorldCoordinate:(CLLocationCoordinate2D)coord;
@end

@implementation MapsViewController

@synthesize scrollView = _scrollView;

- (void)viewDidLoad
{
  NSString *str;

  [super viewDidLoad];

  [_scrollView setCanCancelContentTouches:NO];
  [_scrollView setMinimumZoomScale:1 / pow (2, (LOD_COUNT - LOD_BIAS))];
  [_scrollView setMaximumZoomScale:pow (2, LOD_BIAS) * 4];  
  [_scrollView setDelegate:self];

  _mapsView = [[MapsView alloc] initWithFrame:[_scrollView bounds]];
  [_mapsView setController:self];
  [_mapsView setTransform:CGAffineTransformMakeScale (1, -1)];
  [_scrollView addSubview:_mapsView];
  [_mapsView release];

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

  [[navController navigationBar] setAlpha:1];
  [[navController navigationBar] setTranslucent:NO];

  [[navController toolbar] setAlpha:1];
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
  _zoom = scale;
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)mode
{
  return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orient
    duration:(NSTimeInterval)dur
{
  UINavigationController *navController = (id) [self parentViewController];

  [[navController navigationBar] setAlpha:1];
  [[navController toolbar] setAlpha:1];
  [[UIApplication sharedApplication] setStatusBarHidden:NO animated:NO];
}

@end

@implementation MapsView

@synthesize controller = _controller;

+ (Class)layerClass
{
  return [MapsLayer class];
}

- (void)tapTimer:(NSTimer *)timer
{
  UINavigationController *navController;
  UIEdgeInsets insets;
  float alpha;

  _tapTimer = nil;

  navController = (id) [_controller parentViewController];
  alpha = 1 - [[navController navigationBar] alpha];

  [UIView beginAnimations:@"fadeout" context:nil];
  [[navController navigationBar] setAlpha:alpha];
  [[navController toolbar] setAlpha:alpha];
  [UIView commitAnimations];

  [[UIApplication sharedApplication]
   setStatusBarHidden:alpha == 0 animated:YES];

  insets = UIEdgeInsetsZero;
  if (alpha == 1)
    insets.bottom = [[navController toolbar] frame].size.height;
  [[_controller scrollView] setScrollIndicatorInsets:insets];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  float scale = [[_controller scrollView] zoomScale];
  float level = -log2 (scale), new_level = level;

  [_tapTimer invalidate];
  _tapTimer = nil;

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
      /* FIXME: this doesn't work. */
      new_level = floor (level + 1);
      break;
    }
    
  if (new_level != level)
    {
      scale = pow (2, -new_level);
      [[_controller scrollView] setZoomScale:scale animated:YES];
    }
}

- (void)dealloc
{
  [_tapTimer invalidate];
  [super dealloc];
}

@end

@implementation MapsLayer

static double
scanDegrees (NSScanner *scanner)
{
  double value, mul, tem;

  value = 0;
  mul = 1;

  while ([scanner scanDouble:&tem])
    {
      value += tem * mul;
      mul = mul * (1. / 60);
    }

  return value;
}

static CLLocationDegrees
parseLatitude (NSString *str)
{
  NSScanner *scanner;
  double value;
  NSString *tem;

  scanner = [[NSScanner alloc] initWithString:str];
  
  value = scanDegrees (scanner);

  if ([scanner scanCharactersFromSet:
       [NSCharacterSet letterCharacterSet] intoString:&tem]
      && [tem isEqualToString:@"S"])
    {
      value = -value;
    }

  [scanner release];

  return value;
}

static CLLocationDegrees
parseLongitude (NSString *str)
{
  NSScanner *scanner;
  double value;
  NSString *tem;

  scanner = [[NSScanner alloc] initWithString:str];
  
  value = scanDegrees (scanner);

  if ([scanner scanCharactersFromSet:
       [NSCharacterSet letterCharacterSet] intoString:&tem]
      && [tem isEqualToString:@"W"])
    {
      value = -value;
    }

  [scanner release];

  return value;
}

+ (CFTimeInterval)fadeDuration
{
  return 0;
}

+ (id)defaultValueForKey:(NSString *)key
{
  if ([key isEqualToString:@"edgeAntialiasingMask"])
    return [NSNumber numberWithInt:0];
  if ([key isEqualToString:@"needsDisplayOnBoundsChange"])
    return [NSNumber numberWithBool:YES];
  if ([key isEqualToString:@"opaque"])
    return [NSNumber numberWithBool:YES];
  if ([key isEqualToString:@"levelsOfDetail"])
    return [NSNumber numberWithInt:LOD_COUNT];
  if ([key isEqualToString:@"levelsOfDetailBias"])
    return [NSNumber numberWithInt:LOD_BIAS];
  if ([key isEqualToString:@"minificationFilter"])
    return @"trilinear";
  if ([key isEqualToString:@"magnificationFilter"])
    return @"nearest";
  if ([key isEqualToString:@"tileSize"])
    {
      CGSize s = CGSizeMake (TILE_WIDTH, TILE_HEIGHT);
      return [NSValue valueWithBytes:&s objCType:@encode(CGSize)];
    }
  return [super defaultValueForKey:key];
}

- (void)dealloc
{
  CGPDFDocumentRelease (_document);
  [super dealloc];
}

- (void)setMap:(NSDictionary *)map
{
  NSData *data;
  CGDataProviderRef provider;
  NSArray *array;
  NSDictionary *dict;
  NSInteger i;
  NSNumber *num;
  NSString *str;

  @synchronized (self)
    {
      if (_map != map)
	{
	  [_map release];
	  _map = [map retain];

	  CGPDFDocumentRelease (_document);
	  _document = NULL;
	  _page = NULL;

	  data = [GypsAppDelegate applicationDataFromFile:
		  [map objectForKey:@"filename"]];

	  if (data != nil)
	    {
	      provider = CGDataProviderCreateWithCFData ((CFDataRef) data);
	      _document = CGPDFDocumentCreateWithProvider (provider);
	      CGDataProviderRelease (provider);

	      _page = CGPDFDocumentGetPage (_document, 1);

	      if (_page != NULL)
		{
		  _pageRect = CGPDFPageGetBoxRect (_page, kCGPDFMediaBox);
		  _pageRect = CGRectIntegral (_pageRect);
		  [self setBounds:
		   CGRectMake (0, 0, _pageRect.size.width,
			       _pageRect.size.height)];
		  [self setContents:nil];
		  [self setNeedsDisplay];
		}
	      else
		NSLog (@"failed get pdf page");

	      array = [map objectForKey:@"corners"];
	      if (array != nil && [array count] == 4)
		{
		  for (i = 0; i < 4; i++)
		    {
		      dict = [array objectAtIndex:i];  
		      str = [dict objectForKey:@"latitude"];
		      _mapCorners[i].world_coord.latitude
		        = parseLatitude (str);
		      str = [dict objectForKey:@"longitude"];
		      _mapCorners[i].world_coord.longitude
		        = parseLongitude (str);
		      num = [dict objectForKey:@"x"];
		      _mapCorners[i].page_coord.x
		        = _pageRect.origin.x + [num doubleValue] * _pageRect.size.width;
		      num = [dict objectForKey:@"y"];
		      _mapCorners[i].page_coord.y
		        = _pageRect.origin.y + [num doubleValue] * _pageRect.size.height;
		    }
		}
	      else
		NSLog (@"failed get map corners");
	    }
	  else
	    NSLog (@"failed to open file %@", [map objectForKey:@"filename"]);
	}
    }
}

static inline void
mixCorners (CGPoint *p, const CGPoint *p0, const CGPoint *p1, double t)
{
  p->x = p0->x + (p1->x - p0->x) * t;
  p->y = p0->y + (p1->y - p0->y) * t;
}

static CGPoint
pageCoordinate (MapsLayer *self, CLLocationCoordinate2D world_coord)
{
  const struct MapCorner *c = self->_mapCorners;
  CGPoint p1, p2, p3, p4, p;
  double u;
  
  mixCorners (&p1, &c[0].page_coord, &c[1].page_coord,
	      (world_coord.longitude - c[0].world_coord.longitude)
	      / (c[1].world_coord.longitude - c[0].world_coord.longitude));
  mixCorners (&p2, &c[2].page_coord, &c[3].page_coord,
	      (world_coord.longitude - c[2].world_coord.longitude)
	      / (c[3].world_coord.longitude - c[2].world_coord.longitude));

  mixCorners (&p3, &c[0].page_coord, &c[2].page_coord,
	      (world_coord.latitude - c[0].world_coord.latitude)
	      / (c[2].world_coord.latitude - c[0].world_coord.latitude));
  mixCorners (&p4, &c[1].page_coord, &c[3].page_coord,
	      (world_coord.latitude - c[1].world_coord.latitude)
	      / (c[3].world_coord.latitude - c[1].world_coord.latitude));

  u = (((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x))
       / ((p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)));
  p.x = p1.x + u * (p2.x - p1.x);
  p.y = p1.y + u * (p2.y - p1.y);

  return p;
}

static void
invalidateLocationMarker (MapsLayer *self, CLLocation *loc)
{
  CGPoint p;
  CGRect r;
  CGFloat outset = MARKER_RADIUS + MARKER_LINE_WIDTH + 1;

  p = pageCoordinate (self, [loc coordinate]);
  r = CGRectMake (p.x - outset, p.y - outset, outset * 2, outset * 2);

  [self setNeedsDisplayInRect:r];
}

- (void)setCurrentLocation:(CLLocation *)loc
{
  @synchronized (self)
    {
      if (_currentLocation != loc)
	{
	  if (_currentLocation)
	    invalidateLocationMarker (self, _currentLocation);

	  [_currentLocation release];
	  _currentLocation = [loc copy];

	  if (_currentLocation)
	    invalidateLocationMarker (self, _currentLocation);
	}
    }
}

- (void)setLocations:(NSArray *)array
{
  @synchronized (self)
    {
      if (_locations != array)
	{
	  for (CLLocation *loc in _locations)
	    {
	      if (array != nil
		  && [array indexOfObjectIdenticalTo:loc] == NSNotFound)
		invalidateLocationMarker (self, loc);
	    }

	  for (CLLocation *loc in array)
	    {
	      if (_locations != nil
		  && [_locations indexOfObjectIdenticalTo:loc] == NSNotFound)
		invalidateLocationMarker (self, loc);
	    }

	  [_locations release];
	  _locations = [array copy];
	}
    }
}

- (CGPoint)positionForWorldCoordinate:(CLLocationCoordinate2D)coord
{
  CGPoint p = pageCoordinate (self, coord);
  p.x -= _pageRect.origin.x;
  p.y -= _pageRect.origin.y;
  return p;
}

- (void)drawInContext:(CGContextRef)ctx
{
  CLLocation *currentLocation;
  NSArray *locations;
  NSInteger i, count;
  CGPoint p;
  CGRect r;

  if (_page != NULL)
    {
      CGContextTranslateCTM (ctx, _pageRect.origin.x, _pageRect.origin.y);
      CGContextDrawPDFPage (ctx, _page);
    }

  @synchronized (self)
    {
      currentLocation = [_currentLocation retain];
      locations = [_locations retain];
    }

  CGContextSetLineWidth (ctx, MARKER_LINE_WIDTH);
  CGContextSetRGBStrokeColor (ctx, 0, 0, 1, .8);

  count = [locations count];
  for (i = count - 1; i >= 0; i--)
    {
      p = pageCoordinate (self, [[locations objectAtIndex:i] coordinate]);
      r = CGRectMake (p.x - MARKER_RADIUS, p.y - MARKER_RADIUS,
		      MARKER_RADIUS * 2, MARKER_RADIUS * 2);
      CGContextAddEllipseInRect (ctx, r);
      CGContextStrokePath (ctx);
    }

  if (currentLocation != nil)
    {
      CGContextSetRGBStrokeColor (ctx, 1, 0, 1, .8);
      p = pageCoordinate (self, [currentLocation coordinate]);
      r = CGRectMake (p.x - MARKER_RADIUS, p.y - MARKER_RADIUS,
		      MARKER_RADIUS * 2, MARKER_RADIUS * 2);
      CGContextAddEllipseInRect (ctx, r);
      CGContextStrokePath (ctx);
    }

  [currentLocation release];
  [locations release];
}

@end
