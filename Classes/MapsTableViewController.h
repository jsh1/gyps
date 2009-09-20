/* MapsTableViewController.h  -*- c-style: gnu -*- */

#import <UIKit/UIKit.h>

@interface MapsTableViewController : UITableViewController
{
  NSArray *_allMaps;
  NSDictionary *_currentMap;
}

@property(nonatomic, readonly) NSDictionary *currentMap;

@end
