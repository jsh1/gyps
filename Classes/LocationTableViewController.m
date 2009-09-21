/* LocationTableViewController.m  -*- c-style: gnu -*- */

#import "LocationTableViewController.h"

#import "GypsAppDelegate.h"
#import "LocationTableViewCell.h"
#import "MapsViewController.h"

#define CELL_IDENTIFIER @"locationCell"

@interface LocationTableViewController ()
- (void)loadLocations;
- (void)saveLocations;
- (void)reloadCells;
@end

NSString *const CurrentLocationDidChange = @"CurrentLocationDidChange";
NSString *const LocationsDidChange = @"LocationsDidChange";

@implementation LocationTableViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  [[self tableView] setRowHeight:[LocationTableViewCell heightOfRow]];
  [[self tableView] setAllowsSelection:NO];
  [[self tableView] setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
  [[self tableView] setSeparatorColor:[UIColor lightGrayColor]];
  self.navigationItem.leftBarButtonItem = [self editButtonItem];
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
}

- (void)viewDidDisappear:(BOOL)animated
{
  [_locationManager stopUpdatingHeading];
  [_locationManager stopUpdatingLocation];

  [super viewDidDisappear:animated];
}

- (void)dealloc
{
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self];
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
      _locations = [[NSKeyedUnarchiver
		     unarchiveObjectWithData:data] mutableCopy];
    }
  [[self tableView] reloadData];
}

- (NSArray *)locations
{
  return [[_locations copy] autorelease];
}

- (CLLocation *)currentLocation
{
  return [_locationManager location];
}

- (void)updateFirstRow:(CLLocation *)loc
{
  static NSIndexPath *row0;
  LocationTableViewCell *cell;
  NSInteger count;

  if (row0 == nil)
    row0 = [[NSIndexPath indexPathForRow:0 inSection:0] retain];

  cell = (id) [[self tableView] cellForRowAtIndexPath:row0];

  if (cell != nil)
    {
      [cell setLocation:loc];
      count = [_locations count];
      if (count != 0)
	[cell setPreviousLocation:[_locations objectAtIndex:count-1]];
      else
	[cell setPreviousLocation:nil];
    }
}

- (void)reloadCells
{
  UITableView *tableView = [self tableView];
  LocationTableViewCell *cell;
  CLLocation *loc, *prevLoc;
  NSInteger count;

  count = [_locations count];

  for (NSIndexPath *path in [tableView indexPathsForVisibleRows])
    {
      cell = (id) [tableView cellForRowAtIndexPath:path];
      if (cell == nil)
	continue;

      loc = prevLoc = nil;

      if (path.section == 0)
	{
	  loc = [_locationManager location];
	  if (count > 0)
	    prevLoc = [_locations objectAtIndex:count-1];
	}
      else
	{
	  loc = [_locations objectAtIndex:count-path.row-1];
	  if (path.row < count - 1)
	    prevLoc = [_locations objectAtIndex:count-path.row-2];
	}

      [cell setLocation:loc];
      [cell setPreviousLocation:prevLoc];
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
      [self saveLocations];

      [[self tableView] insertRowsAtIndexPaths:
       [NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:1]]
       withRowAnimation:UITableViewRowAnimationTop];
      [self reloadCells];

      [[NSNotificationCenter defaultCenter]
       postNotificationName:LocationsDidChange object:self];
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

- (IBAction)mapsAction:(id)sender
{
  if (_mapsController == nil)
    [[NSBundle mainBundle] loadNibNamed:@"Maps" owner:self options:nil];

  if (_mapsController != nil)
    {
      [(UINavigationController *)[self parentViewController]
       pushViewController:_mapsController animated:YES];
    }
}

- (IBAction)clearAction:(id)sender
{
  UIActionSheet *sheet;
  UIToolbar *toolbar;

  sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self
	   cancelButtonTitle:@"Cancel"
	   destructiveButtonTitle:@"Confirm Clear" otherButtonTitles:nil];

  toolbar = [[(GypsAppDelegate *)[[UIApplication sharedApplication]
				  delegate] controller] toolbar];
  [sheet showFromToolbar:toolbar];
  [sheet release];

  _actionSheetMode = kLocationActionSheetModeConfirmClear;
}

- (IBAction)emailKMLAction:(id)sender
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv
{
  return 2;
}

- (NSString *)tableView:(UITableView *)tv
    titleForHeaderInSection:(NSInteger)section
{
  if (section == 0)
    return @"Current Location";
  else
    return @"Saved Locations";
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  if (sec == 0)
    return 1;
  else
    return [_locations count];
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
  loc = prevLoc = nil;

  if (path.section == 0)
    {
      loc = [_locationManager location];
      if (count > 0)
	prevLoc = [_locations objectAtIndex:count-1];
    }
  else
    {
      loc = [_locations objectAtIndex:count-path.row-1];
      if (path.row < count - 1)
	prevLoc = [_locations objectAtIndex:count-path.row-2];
    }

  [cell setLocation:loc];
  [cell setPreviousLocation:prevLoc];

  return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tv
    editingStyleForRowAtIndexPath:(NSIndexPath *)path
{
  if (path.section == 0)
    return UITableViewCellEditingStyleNone;
  else
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tv
    commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)path
{
  NSInteger count;

  if (style == UITableViewCellEditingStyleDelete && path.section > 0)
    {
      count = [_locations count];
      [_locations removeObjectAtIndex:count-(path.row+1)];
      [self saveLocations];

      [tv deleteRowsAtIndexPaths:[NSArray arrayWithObject:path]
       withRowAnimation:UITableViewRowAnimationLeft];
      [self reloadCells];

      [[NSNotificationCenter defaultCenter]
       postNotificationName:LocationsDidChange object:self];
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

  [[NSNotificationCenter defaultCenter]
   postNotificationName:CurrentLocationDidChange object:self];
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
