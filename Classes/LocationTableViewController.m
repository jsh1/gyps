/* LocationTableViewController.m  -*- c-style: gnu -*- */

#import "LocationTableViewController.h"

#import "GypsAppDelegate.h"
#import "LocationTableViewCell.h"

#define CELL_IDENTIFIER @"locationCell"

@interface LocationTableViewController ()
- (void)loadLocations;
- (void)saveLocations;
@end

@implementation LocationTableViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  [[self tableView] setRowHeight:[LocationTableViewCell heightOfRow]];
  self.navigationItem.rightBarButtonItem = [self editButtonItem];
  [self loadLocations];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];

  if (_locationManager == nil)
    {
      _locationManager = [[CLLocationManager alloc] init];
      [_locationManager setDelegate:self];
      [_locationManager setDistanceFilter:10];
      [_locationManager setDesiredAccuracy:
       kCLLocationAccuracyNearestTenMeters];
    }

  [_locationManager startUpdatingLocation];
  [_locationManager startUpdatingHeading];

  [[UIApplication sharedApplication]
   setStatusBarStyle:UIStatusBarStyleBlackOpaque];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [[UIApplication sharedApplication]
   setStatusBarStyle:UIStatusBarStyleDefault];

  [_locationManager stopUpdatingHeading];
  [_locationManager stopUpdatingLocation];

  [super viewDidDisappear:animated];
}

- (void)dealloc
{
  [_locations release];
  [_locationManager release];
  [super dealloc];
}

- (void)saveLocations
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_locations];
  [GypsAppDelegate writeApplicationData:data toFile:@"GypsLocations"];
}

- (void)loadLocations
{
  NSData *data = [GypsAppDelegate applicationDataFromFile:@"GypsLocations"];
  if (data != nil)
    {
      [_locations release];
      _locations = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
    }
}

- (void)updateFirstRow:(CLLocation *)loc
{
  static NSIndexPath *row0;
  LocationTableViewCell *cell;

  if (row0 == nil)
    row0 = [[NSIndexPath indexPathForRow:0 inSection:0] retain];

  cell = (id) [[self tableView] cellForRowAtIndexPath:row0];

  if (cell != nil)
    {
      [cell setLocation:loc];
      if ([_locations count] != 0)
	[cell setPreviousLocation:[_locations objectAtIndex:0]];
      else
	[cell setPreviousLocation:nil];
    }
}

- (IBAction)addAction:(id)sender
{
  CLLocation *loc;

  if (_locations == nil)
    _locations = [[NSMutableArray alloc] init];

  loc = [_locationManager location];

  if (loc != nil)
    {
      [_locations addObject:loc];

      [[self tableView] insertRowsAtIndexPaths:
       [NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:0]]
       withRowAnimation:UITableViewRowAnimationLeft];
      [self updateFirstRow:[_locationManager location]];

      [self saveLocations];
    }
}

- (IBAction)actionAction:(id)sender
{
  UIActionSheet *sheet;
  UIToolbar *toolbar;

  if (_actionSheetMode == kLocationActionSheetModeNone)
    {
      sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self
	       cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Clear"
	       otherButtonTitles:@"Email KML", nil];

      toolbar = [[(GypsAppDelegate *)[[UIApplication sharedApplication]
				      delegate] controller] toolbar];
      [sheet showFromToolbar:toolbar];
      [sheet release];

      _actionSheetMode = kLocationActionSheetModeMain;
    }
}

- (void)clearAction:(id)sender
{
  UIActionSheet *sheet;
  UIToolbar *toolbar;

  sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self
	   cancelButtonTitle:@"Cancel"
	   destructiveButtonTitle:@"Confirm" otherButtonTitles:nil];

  toolbar = [[(GypsAppDelegate *)[[UIApplication sharedApplication]
				  delegate] controller] toolbar];
  [sheet showFromToolbar:toolbar];
  [sheet release];

  _actionSheetMode = kLocationActionSheetModeConfirmClear;
}

- (void)emailKMLAction:(id)sender
{
  MFMailComposeViewController *controller;
  NSMutableString *str;
  NSData *kmlData;
  NSInteger idx;

  if (![MFMailComposeViewController canSendMail])
    {
      UIAlertView *alert;
      alert = [[UIAlertView alloc] initWithTitle:nil message:
	       @"Device is unable to send mail." delegate:nil
	       cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
      [alert show];
      [alert release];
      return;
    }

  str = [NSMutableString string];
  [str appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
  [str appendString:@"<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n"];

  idx = 0;
  for (CLLocation *loc in _locations)
    {
      CLLocationCoordinate2D coord = [loc coordinate];
      [str appendString:@"  <Placemark>\n"];
      [str appendFormat:@"    <name>Point %d</name>\n", idx+1];
      if ([loc verticalAccuracy] >= 0)
	{
	  [str appendFormat:
	   @"    <description>Altitude %dm. %@</description>\n",
	   (int) [loc altitude], [[loc timestamp] description]];
	}
      [str appendString:@"    <Point>\n"];
      [str appendFormat:@"      <coordinates>%f,%f,0</coordinates>\n",
       coord.longitude, coord.latitude];
      [str appendString:@"    </Point>\n"];
      [str appendString:@"  </Placemark>\n"];
      idx++;
    }

  [str appendString:@"</kml>\n"];
  
  kmlData = [str dataUsingEncoding:NSUTF8StringEncoding];

  controller = [[MFMailComposeViewController alloc] init];
  [controller setSubject:@"Gyps KML data"];
  [controller addAttachmentData:kmlData
   mimeType:@"application/vnd.google-earth.kml+xml" fileName:@"gyps-log.kml"];
  [controller setMailComposeDelegate:self];

  [self presentModalViewController:controller animated:YES];
  [controller release];
}

/* UITableViewDelegate / UITableViewDataSource methods. */

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  return [_locations count] + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  LocationTableViewCell *cell;
  CLLocation *loc, *prevLoc;
  NSInteger count;

  cell = (id) [tv dequeueReusableCellWithIdentifier:CELL_IDENTIFIER];

  if (cell == nil)
    {
      cell = [[[LocationTableViewCell alloc]
	       initWithStyle:UITableViewCellStyleDefault
	       reuseIdentifier:CELL_IDENTIFIER] autorelease];
    }

  count = [_locations count];

  if (path.row == 0)
    loc = [_locationManager location];
  else
    loc = [_locations objectAtIndex:count-path.row];

  if (path.row == count)
    prevLoc = nil;
  else
    prevLoc = [_locations objectAtIndex:(count-path.row)-1];

  [cell setLocation:loc];
  [cell setPreviousLocation:prevLoc];

  return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tv
    editingStyleForRowAtIndexPath:(NSIndexPath *)path
{
  if (path.row == 0)
    return UITableViewCellEditingStyleNone;
  else
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tv
    commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)path
{
  if (style == UITableViewCellEditingStyleDelete && path.row > 0)
    {
      [_locations removeObjectAtIndex:path.row-1];
      [self saveLocations];

      [tv deleteRowsAtIndexPaths:[NSArray arrayWithObject:path]
       withRowAnimation:UITableViewRowAnimationLeft];

      [self updateFirstRow:[_locationManager location]];
    }
}

/* UIActionSheetDelegate methods. */

- (void)actionSheet:(UIActionSheet *)sheet
    willDismissWithButtonIndex:(NSInteger)idx
{
  unsigned int mode = _actionSheetMode;

  _actionSheetMode = kLocationActionSheetModeNone;

  switch (mode)
    {
    case kLocationActionSheetModeMain:
      switch (idx)
	{
	case 0:				/* Clear */
	  [self clearAction:self];
	  break;

	case 1:				/* Email KML */
	  [self emailKMLAction:self];
	  break;
	}
      break;

    case kLocationActionSheetModeConfirmClear:
      if (idx == 0)				/* Clear */
	{
	  [_locations removeAllObjects];
	  [self saveLocations];
	  [[self tableView] reloadData];
	}
      break;
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
    didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
  [self dismissModalViewControllerAnimated:YES];
}

/* CLLocationManagerDelegate methods. */

- (void)locationManager:(CLLocationManager *)lm
    didUpdateToLocation:(CLLocation *)newLoc fromLocation:(CLLocation *)oldLoc
{
  [self updateFirstRow:newLoc];
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateHeading:(CLHeading *)newHeading
{
#if 0
  CLLocationDirection ang;
  CLLocationDirection acc;

  ang = [newHeading trueHeading];
  acc = [newHeading headingAccuracy];
  ang = fmod (ang, 360);

  [_headingLabel setText:formatPositiveAngle (ang, acc)];
#endif
}

- (void)locationManager:(CLLocationManager *)lm didFailWithError:(NSError *)err
{
}

@end
