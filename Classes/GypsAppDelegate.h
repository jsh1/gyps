/* GypsAppDelegate.h  -*- c-style: gnu -*- */

#import <UIKit/UIKit.h>

@interface GypsAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate>
{
  IBOutlet UIWindow *_window;
  IBOutlet UINavigationController *_controller;
}

+ (BOOL)writeApplicationData:(NSData *)data toFile:(NSString *)file;
+ (NSData *)applicationDataFromFile:(NSString *)file;

+ (NSArray *)allMaps;

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) UINavigationController *controller;

@end
