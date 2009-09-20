/* LocationTableViewCell.h  -*- c-style: gnu -*- */

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface LocationTableViewCell : UITableViewCell
{
  CLLocation *_location;
  CLLocation *_previousLocation;
}

+ (CGFloat)heightOfRow;

@property(nonatomic, retain) CLLocation *location;
@property(nonatomic, retain) CLLocation *previousLocation;

@end
