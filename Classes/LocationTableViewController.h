/* LocationTableViewController.h  -*- c-style: gnu -*- */

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <CoreLocation/CoreLocation.h>

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
  NSMutableArray *_locations;
  CLLocationManager *_locationManager;
  unsigned int _actionSheetMode;
}

- (IBAction)addAction:(id)sender;
- (IBAction)actionAction:(id)sender;

@end
