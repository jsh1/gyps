/* MapsTableViewController.m  -*- c-style: gnu -*- */

#import "MapsTableViewController.h"

#import "GypsAppDelegate.h"
#import "MapsViewController.h"

#define CELL_IDENTIFIER @"MapCell"

@implementation MapsTableViewController

- (void)viewDidLoad
{
  [super viewDidLoad];

  _allMaps = [[GypsAppDelegate allMaps] retain];
}

- (void)dealloc
{
  [_allMaps release];
  [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)mode
{
  return YES;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)sec
{
  return [_allMaps count];
}

- (UITableViewCell *)tableView:(UITableView *)tv
    cellForRowAtIndexPath:(NSIndexPath *)path
{
  UITableViewCell *cell;
  NSString *name;

  cell = [tv dequeueReusableCellWithIdentifier:CELL_IDENTIFIER];

  if (cell == nil)
    {
      cell = [[[UITableViewCell alloc]
	       initWithStyle:UITableViewCellStyleDefault
	       reuseIdentifier:CELL_IDENTIFIER] autorelease];
    }

  name = [[_allMaps objectAtIndex:path.row] objectForKey:@"name"];
  [[cell textLabel] setText:name];

  return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)path
{
  UINavigationController *navController;
  MapsViewController *mapsController;
  NSDictionary *map;

  map = [_allMaps objectAtIndex:path.row];

  /* FIXME: hmm..? */
  navController = (UINavigationController *) [self parentViewController];
  mapsController = (MapsViewController *) [navController topViewController];

  [mapsController tableDidSelectMap:[_allMaps objectAtIndex:path.row]];
}

@end
