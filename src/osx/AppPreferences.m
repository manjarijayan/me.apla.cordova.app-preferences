//
//  AppPreferences.m
//
//
//  Created by Tue Topholm on 31/01/11.
//  Copyright 2011 Sugee. All rights reserved.
//
//  Modified by Ivan Baktsheev, 2012-2015
//  Modified by Tobias Bocanegra, 2015
//
// THIS HAVEN'T BEEN TESTED WITH CHILD PANELS YET.

#import "AppPreferences.h"

@implementation AppPreferences

- (void)pluginInitialize
{

}

- (void)defaultsChanged:(NSNotification *)notification {

	NSString * jsCallBack = [NSString stringWithFormat:@"cordova.fireDocumentEvent('preferencesChanged');"];

	// https://github.com/EddyVerbruggen/cordova-plugin-3dtouch/blob/master/src/ios/app/AppDelegate+threedeetouch.m
	if ([self.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
		// UIWebView
		[self.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:jsCallBack waitUntilDone:NO];
	} else if ([self.webView respondsToSelector:@selector(evaluateJavaScript:completionHandler:)]) {
		// WKWebView
		[self.webView performSelector:@selector(evaluateJavaScript:completionHandler:) withObject:jsCallBack withObject:nil];
	} else {
		NSLog(@"No compatible method found to send notification to the webview. Please notify the plugin author.");
	}
}



- (void)watch:(CDVInvokedUrlCommand*)command
{

	__block CDVPluginResult* result = nil;

	NSNumber *option = command.arguments[0];
	bool watchChanges = true;
	if (option) {
		watchChanges = [option boolValue];
	}

	if (watchChanges) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];
	} else {
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	}

	[self.commandDelegate runInBackground:^{
		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
	}];
}



- (void)fetch:(CDVInvokedUrlCommand*)command
{

	__block CDVPluginResult* result = nil;

	NSDictionary* options = command.arguments[0];

	if (!options) {
		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"no options given"];
		[self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
		return;
	}

	NSString *settingsDict = options[@"dict"];
	NSString *settingsName = options[@"key"];
	NSString *suiteName    = options[@"iosSuiteName"];

	[self.commandDelegate runInBackground:^{

	NSUserDefaults *defaults;

	if (suiteName != nil) {
		defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
	} else {
		defaults = [NSUserDefaults standardUserDefaults];
	}


	id target = defaults;

	// NSMutableDictionary *mutable = [[dict mutableCopy] autorelease];
	// NSDictionary *dict = [[mutable copy] autorelease];

	@try {

		NSString *returnVar;
		id settingsValue = nil;

		if (settingsDict) {
			target = [defaults dictionaryForKey:settingsDict];
			if (target == nil) {
				returnVar = nil;
			}
		}

		if (target != nil) {
			settingsValue = [target objectForKey:settingsName];
		}

		if (settingsValue != nil) {
			if ([settingsValue isKindOfClass:[NSString class]]) {
				NSString *escaped = [(NSString*)settingsValue stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
				escaped = [escaped stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
				returnVar = [NSString stringWithFormat:@"\"%@\"", escaped];
			} else if ([settingsValue isKindOfClass:[NSNumber class]]) {
				if ([@YES isEqual:settingsValue]) {
					returnVar = @"true";
				} else if ([@NO isEqual:settingsValue]) {
					returnVar = @"false";
				} else {
					// TODO: int, float
					returnVar = [NSString stringWithFormat:@"%@", (NSNumber*)settingsValue];
				}
			} else if ([settingsValue isKindOfClass:[NSData class]]) { // NSData
				returnVar = [[NSString alloc] initWithData:(NSData*)settingsValue encoding:NSUTF8StringEncoding];
			}
		} else {
			// TODO: also submit dict
			returnVar = [self getSettingFromBundle:settingsName]; //Parsing Root.plist
		}

		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:returnVar];

	} @catch (NSException * e) {

		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT messageAsString:[e reason]];

	} @finally {

		[self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
	}
	}];
}

- (void)remove:(CDVInvokedUrlCommand*)command
{

	__block CDVPluginResult* result = nil;

	NSDictionary* options = command.arguments[0];

	if (!options) {
		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"no options given"];
		[self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
		return;
	}

	NSString *settingsDict = options[@"dict"];
	NSString *settingsName = options[@"key"];
	NSString *suiteName    = options[@"iosSuiteName"];

	//[self.commandDelegate runInBackground:^{

	NSUserDefaults *defaults;

	if (suiteName != nil) {
		defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
	} else {
		defaults = [NSUserDefaults standardUserDefaults];
	}

	id target = defaults;

	// NSMutableDictionary *mutable = [[dict mutableCopy] autorelease];
	// NSDictionary *dict = [[mutable copy] autorelease];

	@try {

		NSString *returnVar;

		if (settingsDict) {
			target = [defaults dictionaryForKey:settingsDict];
			if (target)
				target = [target mutableCopy];
		}

		if (target != nil) {
			[target removeObjectForKey:settingsName];
			if (target != defaults)
				[defaults setObject:(NSMutableDictionary*)target forKey:settingsDict];
			[defaults synchronize];
		}

		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:returnVar];

	} @catch (NSException * e) {

		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT messageAsString:[e reason]];

	} @finally {

		[self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
	}
	//}];
}

- (void)clearAll:(CDVInvokedUrlCommand*)command
{
	__block CDVPluginResult* result = nil;

	NSDictionary* options = [[command arguments] objectAtIndex:0];

	if (!options) {
		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"no options given"];
		[self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
		return;
	}

	NSString *settingsDict = [options objectForKey:@"dict"];
	NSString *suiteName    = [options objectForKey:@"iosSuiteName"];

	//[self.commandDelegate runInBackground:^{

	@try {

		NSString *returnVar;

		NSUserDefaults *defaults;
		NSString *appDomain;

		if (suiteName != nil) {
			appDomain = suiteName;
			defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
		} else {
			appDomain = [[NSBundle mainBundle] bundleIdentifier];
			defaults = [NSUserDefaults standardUserDefaults];
		}

		[defaults removePersistentDomainForName:appDomain];

		[defaults synchronize];

		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:returnVar];

	} @catch (NSException * e) {

		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT messageAsString:[e reason]];

	} @finally {

		[self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
	}

	//}];
}

- (void)show:(CDVInvokedUrlCommand*)command
{
	__block CDVPluginResult* result;
	NSLog(@"OSX version of this plugin does not support show() yet.");
	result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"switching to preferences not supported"];
	[self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];

}

- (void)store:(CDVInvokedUrlCommand*)command
{
	__block CDVPluginResult* result;

	NSDictionary* options = command.arguments[0];

	if (!options) {
		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"no options given"];
		[self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
		return;
	}

	NSString *settingsDict  = options[@"dict"];
	NSString *settingsName  = options[@"key"];
	NSString *settingsValue = options[@"value"];
	NSString *settingsType  = options[@"type"];
	NSString *suiteName     = options[@"iosSuiteName"];

	//	NSLog(@"%@ = %@ (%@)", settingsName, settingsValue, settingsType);

	//[self.commandDelegate runInBackground:^{
	NSUserDefaults *defaults;

	if (suiteName != nil) {
		defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
	} else {
		defaults = [NSUserDefaults standardUserDefaults];
	}

	id target = defaults;

	// NSMutableDictionary *mutable = [[dict mutableCopy] autorelease];
	// NSDictionary *dict = [[mutable copy] autorelease];

	if (settingsDict) {
		target = [[defaults dictionaryForKey:settingsDict] mutableCopy];
		if (!target) {
			target = [[NSMutableDictionary alloc] init];
			#if !__has_feature(objc_arc)
				[target autorelease];
			#endif
		}
	}

	NSError* error = nil;
	id JSONObj = [NSJSONSerialization
		JSONObjectWithData:[settingsValue dataUsingEncoding:NSUTF8StringEncoding]
		options:NSJSONReadingAllowFragments
		error:&error
	];

	if (error != nil) {
		NSLog(@"NSString JSONObject error: %@", [error localizedDescription]);
	}

	@try {

		if ([settingsType isEqual: @"string"] && [JSONObj isKindOfClass:[NSString class]]) {
			[target setObject:(NSString*)JSONObj forKey:settingsName];
		} else if ([settingsType  isEqual: @"number"] && [JSONObj isKindOfClass:[NSNumber class]]) {
			[target setObject:(NSNumber*)JSONObj forKey:settingsName];
			// setInteger: forKey, setFloat: forKey:
		} else if ([settingsType  isEqual: @"boolean"]) {
			[target setObject:JSONObj forKey:settingsName];
		} else {
			// data
			[target setObject:[settingsValue dataUsingEncoding:NSUTF8StringEncoding] forKey:settingsName];
		}

		if (target != defaults)
			[defaults setObject:(NSMutableDictionary*)target forKey:settingsDict];
		[defaults synchronize];

		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

	} @catch (NSException * e) {

		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT messageAsString:[e reason]];

	} @finally {

		[self.commandDelegate sendPluginResult:result callbackId:[command callbackId]];
	}
	//}];
}

/*
  Parsing the Root.plist for the key, because there is a bug/feature in Settings.bundle
  So if the user haven't entered the Settings for the app, the default values aren't accessible through NSUserDefaults.
*/

- (NSString*)getSettingFromBundle:(NSString*)settingsName
{
	NSString *pathStr = [[NSBundle mainBundle] bundlePath];
	NSString *settingsBundlePath = [pathStr stringByAppendingPathComponent:@"Settings.bundle"];
	NSString *finalPath = [settingsBundlePath stringByAppendingPathComponent:@"Root.plist"];

	NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfFile:finalPath];
	NSArray *prefSpecifierArray = settingsDict[@"PreferenceSpecifiers"];
	NSDictionary *prefItem;
	for (prefItem in prefSpecifierArray)
	{
		if ([prefItem[@"Key"] isEqualToString:settingsName])
			return prefItem[@"DefaultValue"];
	}
	return nil;

}
@end
