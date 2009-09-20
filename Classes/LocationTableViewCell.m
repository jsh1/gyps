/* LocationTableViewCell.m  -*- c-style: gnu -*- */

#import "LocationTableViewCell.h"

#define FONT_SIZE 24
#define LINE_SPACING 36
#define CELL_X_INSET 40
#define CELL_Y_INSET 20

static NSString *
formatPositiveAngle (CLLocationDegrees ang, double acc)
{
  static NSString *deg_str, *min_str, *sec_str;

  double deg, min, sec;

  deg = ang;
  ang = (ang - floor (deg)) * 60;
  min = ang;
  sec = (ang - floor (min)) * 60;

 if (deg_str == nil)
   {
     deg_str = [[NSString alloc] initWithUTF8String:"\302\260"];
     min_str = [[NSString alloc] initWithUTF8String:"\342\200\231"];
     sec_str = [[NSString alloc] initWithUTF8String:"\342\200\235"];
   }

 if (acc <= 1. / 360000)
   {
     return [NSString stringWithFormat:@"%d%@ %d%@ %.2f%@",
	     (int) deg, deg_str, (int) min, min_str, sec, sec_str];
   }
 else if (acc <= 1. / 36000)
   {
     return [NSString stringWithFormat:@"%d%@ %d%@ %.1f%@",
	     (int) deg, deg_str, (int) min, min_str, sec, sec_str];
   }
 else if (acc <= 1. / 3600)
   {
     return [NSString stringWithFormat:@"%d%@ %d%@ %d%@",
	     (int) deg, deg_str, (int) min, min_str, (int) (sec + .5f), sec_str];
   }
 else if (acc <= 1. / 60)
   {
     return [NSString stringWithFormat:@"%d%@ %d%@",
	     (int) deg, deg_str, (int) (min + .5f), min_str];
   }
 else
   {
     return [NSString stringWithFormat:@"%d%@",
	     (int) (deg + .5f), deg_str];
   }
}

static NSString *
formatAngle (CLLocationDegrees ang, CLLocationAccuracy acc,
	     const char *pos_str, const char *neg_str)
{
  const char *suf;

  if (acc < 0)
    return @"-";

  if (ang < 0)
    ang = -ang, suf = neg_str;
  else if (ang > 180)
    ang = 360 - ang, suf = neg_str;
  else
    suf = pos_str;

 return [NSString stringWithFormat:@"%@ %s",
	 formatPositiveAngle (ang, 1e-10), suf];
}

static NSString *
formatAltitude (CLLocationDistance alt, CLLocationAccuracy acc)
{
  if (acc < 0)
    return @"-";

#if 0
  if (acc > 10)
    {
      double quant = 10;
      while (acc > quant)
	quant = quant * 10;
      alt = round (alt / quant) * quant;
    }
  else
    alt = round (alt);

  return [NSString stringWithFormat:@"%d m", (int) alt];
#else
  static NSString *pm_str;

  if (pm_str == nil)
    pm_str = [[NSString alloc] initWithUTF8String:"\302\261"];

  return [NSString stringWithFormat:@"%dm %@%gm",
	  (int) alt, pm_str, round (acc)];
#endif
}

static NSString *
formatDistance (CLLocationDistance dist)
{
  return [NSString stringWithFormat:@"%dm", (int) round (dist)];
}

@implementation LocationTableViewCell

+ (CGFloat)heightOfRow
{
  return LINE_SPACING*4.5;
}

- (void)setLocation:(CLLocation *)loc
{
  if (_location != loc)
    {
      [_location release];
      _location = [loc retain];
      [self setNeedsDisplay];
    }
}

- (CLLocation *)location
{
  return _location;
}

- (void)setPreviousLocation:(CLLocation *)loc
{
  if (_previousLocation != loc)
    {
      [_previousLocation release];
      _previousLocation = [loc retain];
      [self setNeedsDisplay];
    }
}

- (CLLocation *)previousLocation
{
  return _previousLocation;
}

- (void)drawRect:(CGRect)clip
{
  static NSString *right_arrow, *up_arrow, *down_arrow;

  CLLocationCoordinate2D pos;
  CLLocationDistance altitude, distance;
  CLLocationAccuracy hacc, vacc;
  CGRect bounds = [self bounds], r;

  if (right_arrow == nil)
    {
      right_arrow = [[NSString alloc] initWithUTF8String:"\342\206\222"];
      up_arrow = [[NSString alloc] initWithUTF8String:"\342\206\221"];
      down_arrow = [[NSString alloc] initWithUTF8String:"\342\206\223"];
    }

  UIFont *f = [UIFont fontWithName:@"Courier" size:FONT_SIZE];

  [[UIColor blackColor] set];
  UIRectFill (r);

  [[UIColor yellowColor] set];

  if (_location != nil)
    {
      pos = [_location coordinate];
      hacc = [_location horizontalAccuracy];
      altitude = [_location altitude];
      vacc = [_location verticalAccuracy];
    }
  else
    {
      hacc = -1;
      vacc = -1;
    }

  r = CGRectMake (10, 0, bounds.origin.x + bounds.size.width - 10, 14);
  [[[_location timestamp] description] drawInRect:r
   withFont:[UIFont fontWithName:@"Courier" size:14]
   lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentLeft];

  CGPoint p = CGPointMake (CELL_X_INSET, CELL_Y_INSET);

  [formatAngle (pos.latitude, hacc, "N", "S") drawAtPoint:p withFont:f];
  p.y += LINE_SPACING;
  [formatAngle (pos.longitude, hacc, "E", "W") drawAtPoint:p withFont:f];
  p.y += LINE_SPACING;

  [formatAltitude (altitude, vacc) drawAtPoint:p withFont:f];
  p.y += LINE_SPACING;

  NSString *h_delta = nil, *v_delta = nil, *str;

  if (_previousLocation && hacc >= 0)
    {
      distance = [_location getDistanceFrom:_previousLocation];
      h_delta = [right_arrow stringByAppendingString:
		 formatDistance (distance)];
    }

  if (_previousLocation && vacc >= 0)
    {
      distance = altitude - [_previousLocation altitude];
      v_delta = [(distance > 0 ? up_arrow : down_arrow)
	       stringByAppendingString: formatDistance (fabs(distance))];
    }

  if (h_delta && v_delta)
    str = [NSString stringWithFormat:@"%@ %@", h_delta, v_delta];
  else if (h_delta)
    str = h_delta;
  else
    str = v_delta;

  if (str == nil)
    str = @"-";

  r = CGRectMake (p.x, p.y, bounds.origin.x + bounds.size.width
		  - p.x - CELL_X_INSET, LINE_SPACING);
  [str drawInRect:r withFont:f lineBreakMode:UILineBreakModeWordWrap
   alignment:UITextAlignmentRight];

  p.y += LINE_SPACING;
}

@end
