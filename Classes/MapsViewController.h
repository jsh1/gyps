/* MapsViewController.h  -*- c-style: gnu -*- */

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@class LocationTableViewController;
@class MapsTableViewController;
@class MapsView;

@interface MapsViewController : UIViewController <UIScrollViewDelegate>
{
  IBOutlet LocationTableViewController *_locationController;
  IBOutlet MapsTableViewController *_tableController;
  IBOutlet UIScrollView *_scrollView;

  MapsView *_mapsView;

  NSDictionary *_currentMap;
}

@property(nonatomic, retain) NSDictionary *currentMap;

@property(nonatomic) CGFloat currentLevelOfDetail;
- (void)setCurrentLevelOfDetail:(CGFloat)level animated:(BOOL)flag;

@property(nonatomic, getter=isUIHidden) BOOL UIHidden;
- (void)setUIHidden:(BOOL)state animated:(BOOL)flag;

- (IBAction)mapListAction:(id)sender;

- (void)tableDidSelectMap:(NSDictionary *)map;

@end
