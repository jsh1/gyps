/* MapsLayer.h  -*- c-style: gnu -*- */

#import <QuartzCore/CoreAnimation.h>
#import <CoreLocation/CoreLocation.h>

struct MapCorner
{
  CLLocationCoordinate2D world_coord;
  CGPoint page_coord;
};

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

@property(nonatomic, retain) NSDictionary *map;

@property(nonatomic, retain) CLLocation *currentLocation;
@property(nonatomic, retain) NSArray *locations;

- (CGPoint)positionForWorldCoordinate:(CLLocationCoordinate2D)coord;

@end
