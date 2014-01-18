/* LocationTableViewController.h  -*- c-style: gnu -*- */

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <CoreLocation/CoreLocation.h>

@class MapsViewController;

enum LocationActionSheetMode
{
    kLocationActionSheetModeNone,
    kLocationActionSheetModeMain,
    kLocationActionSheetModeConfirmClear,
};

@interface LocationTableViewController : UITableViewController
    <UITableViewDelegate, UIActionSheetDelegate,
     MFMailComposeViewControllerDelegate, CLLocationManagerDelegate>
{
  IBOutlet MapsViewController *_mapsController;

  NSMutableArray *_locations;
  CLLocationManager *_locationManager;
  unsigned int _actionSheetMode;

  MFMailComposeViewController *_msgController;
}

@property(nonatomic, readonly) CLLocation *currentLocation;
@property(nonatomic, readonly) NSArray *locations;

- (IBAction)addAction:(id)sender;
- (IBAction)actionAction:(id)sender;
- (IBAction)mapsAction:(id)sender;
- (IBAction)clearAction:(id)sender;
- (IBAction)emailKMLAction:(id)sender;

@end

extern NSString *const CurrentLocationDidChange;
extern NSString *const LocationsDidChange;
