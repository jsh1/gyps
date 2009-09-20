/* MapsViewController.h  -*- c-style: gnu -*- */

#import <UIKit/UIKit.h>

@class LocationTableViewController;
@class MapsTableViewController;
@class MapsView;

@interface MapsViewController : UIViewController <UIScrollViewDelegate>
{
  IBOutlet LocationTableViewController *_locationController;
  IBOutlet MapsTableViewController *_tableController;
  IBOutlet UIScrollView *_scrollView;

  MapsView *_mapsView;
  CGFloat _zoom;

  NSDictionary *_currentMap;
}

@property(nonatomic, retain) NSDictionary *currentMap;

- (IBAction)mapListAction:(id)sender;

- (void)tableDidSelectMap:(NSDictionary *)map;

@end
