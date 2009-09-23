/* MapsLayer.m  -*- c-style: gnu -*- */

#import "MapsLayer.h"

#import "GypsAppDelegate.h"

#define LOD_COUNT 16
#define LOD_BIAS 5

#define TILE_WIDTH 256
#define TILE_HEIGHT 256

#define MARKER_RADIUS 10
#define MARKER_LINE_WIDTH 4

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
  return .5;
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

- (NSDictionary *)map
{
  return _map;
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

- (CLLocation *)currentLocation
{
  return _currentLocation;
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

- (NSArray *)locations
{
  return _locations;
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
  CGPDFDocumentRef doc;
  CGPDFPageRef page;
  CGPoint p;
  CGRect pageRect, r;

  @synchronized (self)
    {
      /* Retaining the page alone isn't good enough, it references the
         PDF document without retaining it. */

      doc = CGPDFDocumentRetain (_document);
      page = CGPDFPageRetain (_page);
      pageRect = _pageRect;

      currentLocation = [_currentLocation retain];
      locations = [_locations retain];
    }

  if (page != NULL)
    {
      CGContextTranslateCTM (ctx, pageRect.origin.x, pageRect.origin.y);
      CGContextDrawPDFPage (ctx, page);
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

  CGPDFPageRelease (page);
  CGPDFDocumentRelease (doc);

  [currentLocation release];
  [locations release];
}

@end
