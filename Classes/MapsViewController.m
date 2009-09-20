/* MapsViewController.m  -*- c-style: gnu -*- */

#import "MapsViewController.h"

#import "GypsAppDelegate.h"
#import "MapsTableViewController.h"

#import <QuartzCore/CoreAnimation.h>

#define LOD_COUNT 16
#define LOD_BIAS 5
#define TILE_WIDTH 256
#define TILE_HEIGHT 256

@interface MapsView : UIView
{
  MapsViewController *_controller;
}
@property(nonatomic,assign) MapsViewController *controller;
@end

@interface MapsLayer : CATiledLayer
{
  CGPDFDocumentRef _document;
  CGPDFPageRef _page;
  CGRect _pageRect;
}
- (void)setPDFDocument:(CGPDFDocumentRef)doc;
@end

@implementation MapsViewController

- (void)viewDidLoad
{
  [super viewDidLoad];

  [_scrollView setCanCancelContentTouches:NO];
  [_scrollView setIndicatorStyle:UIScrollViewIndicatorStyleWhite];
  [_scrollView setMinimumZoomScale:1 / pow (2, (LOD_COUNT - LOD_BIAS))];
  [_scrollView setMaximumZoomScale:pow (2, LOD_BIAS) * 4];
  [_scrollView setDelegate:self];

  _mapsView = [[MapsView alloc] initWithFrame:[_scrollView bounds]];
  [_mapsView setController:self];
  [_mapsView setTransform:CGAffineTransformMakeScale (1, -1)];
  [_scrollView addSubview:_mapsView];
  [_mapsView release];
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
  [_locationController release];
  [_tableController release];
  [_scrollView release];
  [_currentMap release];
  [super dealloc];
}

- (NSDictionary *)currentMap
{
  return _currentMap;
}

- (void)setCurrentMap:(NSDictionary *)map
{
  NSData *data;
  CGDataProviderRef provider;
  CGPDFDocumentRef document;
  CGRect r;

  if (_currentMap != map)
    {
      [_currentMap release];
      _currentMap = [map copy];

      [self setTitle:[_currentMap objectForKey:@"name"]];

      data = [GypsAppDelegate applicationDataFromFile:
	      [map objectForKey:@"filename"]];

      if (data != nil)
	{
	  provider = CGDataProviderCreateWithCFData ((CFDataRef) data);
	  document = CGPDFDocumentCreateWithProvider (provider);
	  CGDataProviderRelease (provider);
	  [(MapsLayer *)[_mapsView layer] setPDFDocument:document];
	  CGPDFDocumentRelease (document);

	  r = [_mapsView bounds];
	  [_scrollView setContentSize:[_mapsView bounds].size];
	  [_mapsView setCenter:CGPointMake (CGRectGetMidX (r), CGRectGetMidY (r))];
	}
    }
}

@end

@implementation MapsView

@synthesize controller = _controller;

+ (Class)layerClass
{
  return [MapsLayer class];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  UINavigationController *navController;
  BOOL hidden;

  if ([touches count] == 2)
    {
      navController = (UINavigationController *) [_controller parentViewController];
      hidden = [navController isNavigationBarHidden];
      [navController setNavigationBarHidden:!hidden animated:YES];
      [navController setToolbarHidden:!hidden animated:YES];
    }
}

@end

@implementation MapsLayer

+ (id)defaultValueForKey:(NSString *)key
{
  if ([key isEqualToString:@"edgeAntialiasingMask"])
    return [NSNumber numberWithInt:0];
  if ([key isEqualToString:@"needsDisplayOnBoundsChange"])
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

- (void)setPDFDocument:(CGPDFDocumentRef)doc
{
  CGPDFDocumentRelease (_document);
  _document = CGPDFDocumentRetain (doc);

  _page = CGPDFDocumentGetPage (_document, 1);

  if (_page != NULL)
    {
      _pageRect = CGPDFPageGetBoxRect (_page, kCGPDFMediaBox);
      _pageRect = CGRectIntegral (_pageRect);
      [self setBounds:
       CGRectMake (0, 0, _pageRect.size.width, _pageRect.size.height)];
      [self setNeedsDisplay];
    }
}

- (void)drawInContext:(CGContextRef)ctx
{
  if (_page != NULL)
    {
      CGContextTranslateCTM (ctx, _pageRect.origin.x, _pageRect.origin.y);
      CGContextDrawPDFPage (ctx, _page);
    }
}

@end
