/* GypsAppDelegate.m  -*- c-style: gnu -*- */

#import "GypsAppDelegate.h"

@implementation GypsAppDelegate

@synthesize window = _window;
@synthesize controller = _controller;

- (void)applicationDidFinishLaunching:(UIApplication *)application 
{
  [_window addSubview:[_controller view]];
}

- (void)dealloc
{
  [_controller release];
  [_window release];
  [super dealloc];
}

+ (BOOL)writeApplicationData:(NSData *)data toFile:(NSString *)file
{
  NSArray *paths;
  NSString *path;
  NSFileManager *fm;

  paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory,
					       NSUserDomainMask, YES);
  if ([paths count] == 0)
    return NO;

  path = [paths objectAtIndex:0];

  fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:path])
    {
      [fm createDirectoryAtPath:path withIntermediateDirectories:YES
       attributes:nil error:nil];
    }

  path = [path stringByAppendingPathComponent:file];

  return [data writeToFile:path atomically:NO];
}

+ (NSData *)applicationDataFromFile:(NSString *)file
{
  NSArray *paths;
  NSString *path;

  paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory,
					       NSUserDomainMask, YES);
  if ([paths count] == 0)
    return NO;

  path = [paths objectAtIndex:0];
  path = [path stringByAppendingPathComponent:file];

  return [NSData dataWithContentsOfFile:path];
}

+ (NSArray *)allMaps
{
  static NSArray *maps;
  NSData *data;

  if (maps == nil)
    {
      data = [self applicationDataFromFile:@"GypsMaps.plist"];

      if (data != nil)
	{
	  maps = [[NSPropertyListSerialization propertyListFromData:data
		   mutabilityOption:NSPropertyListImmutable
		   format:nil errorDescription:nil] retain];
	}
      else
	maps = [[NSArray alloc] init];
    }

  return maps;
}

@end
