//
//  SSHFSDelegate.m
//  MacFusion2
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//      http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "SSHFSDelegate.h"
#import "MFConstants.h"
#import "MGUtilities.h"
#import "MFError.h"
#import "MFNetworkFS.h"
#import "MFSecurity.h"
#import <Security/Security.h>
#import "MFServerFS.h"
#import "SSHServerFS.h"
#import "MFClientFSUI.h"

#define kSSHFSCompressionParameter @"compression"
#define kSSHFSFollowSymlinksParameter @"followSymlinks"
#define kSSHFSAutoCacheParameter @"autoCache"
#define kSSHFSDeferPermissionsParameter @"deferPermissions"
#define kSSHFSFuseDebugParameter @"fuseDebug"
#define kSSHFSSshfsDebugParameter @"sshfsDebug"
#define kSSHFSSshDebugParameter @"sshDebug"

static NSString *primaryViewControllerKey = @"sshfsPrimaryView";
static NSString *advancedViewControllerKey = @"sshfsAdvancedView";

@implementation SSHFSDelegate

#pragma mark Plugin Info
- (NSString *)askpassPath {
	return [[NSBundle bundleForClass:[self class]] pathForResource:@"new_sshfs_askpass" ofType:nil inDirectory:nil];
}

- (NSString *)executablePath {
	NSProcessInfo *pinfo = [NSProcessInfo processInfo];
	NSArray *tmpArr = [[pinfo operatingSystemVersionString] componentsSeparatedByString:@" "];
	NSArray *versionArr = [[tmpArr objectAtIndex:1] componentsSeparatedByString:@"."];
	NSInteger OSmajor = [[versionArr objectAtIndex:0] integerValue];
	NSInteger OSminor = [[versionArr objectAtIndex:1] integerValue];

	// This shouldn't be necessary, but helps to safeguard, if people were to compile for OS X < 10.9
	// This check can hopefully removed in the future
    if (OSmajor >= 11) {
        // Use the binary built by yourself
        return [[NSBundle bundleForClass:[self class]] pathForResource:@"sshfs" ofType:nil inDirectory:nil];
    }else if (OSmajor == 10 && OSminor >= 9) {
		// Yes, use the latest and greatest code (no MacFuse compat layer needed)
		return [[NSBundle bundleForClass:[self class]] pathForResource:@"sshfs-static" ofType:nil inDirectory:nil];
	} else {
		// Fallback to the legacy code that requires the MacFuse compat layer
		return [[NSBundle bundleForClass:[self class]] pathForResource:@"sshfs-static-legacy" ofType:nil inDirectory:nil];
	}
}

- (NSArray *)secretsClientsList {
	return [NSArray arrayWithObjects:[self askpassPath], nil];
}

#pragma mark Mounting
- (NSArray *)taskArgumentsForParameters:(NSDictionary *)parameters {
	// MFLogS(self, @"Parameters received %@", parameters);
	NSMutableArray *arguments = [NSMutableArray array];
	[arguments addObject:[NSString stringWithFormat:@"%@@%@:%@",
						   [parameters objectForKey:kNetFSUserParameter],
						   [parameters objectForKey:kNetFSHostParameter],
						   [parameters objectForKey:kNetFSDirectoryParameter]]];
	
	[arguments addObject:[parameters objectForKey:kMFFSMountPathParameter]];
	[arguments addObject:[NSString stringWithFormat:@"-p%@", [parameters objectForKey:kNetFSPortParameter]]];
	[arguments addObject:@"-oNumberOfPasswordPrompts=1"];
	
	if ([[parameters objectForKey:kSSHFSCompressionParameter] boolValue] == YES) {
		[arguments addObject:@"-ocompression=yes"];
	}
	if ([[parameters objectForKey:kSSHFSFollowSymlinksParameter] boolValue] == YES) {
		[arguments addObject:@"-ofollow_symlinks"];	
	}
	if ([[parameters objectForKey:kSSHFSDeferPermissionsParameter] boolValue] == YES) {
        [arguments addObject:@"-odefer_permissions"];
    }
	if ([[parameters objectForKey:kSSHFSAutoCacheParameter] boolValue] == YES) {
        [arguments addObject:@"-oauto_cache"];
    }
	if ([[parameters objectForKey:kSSHFSSshfsDebugParameter] boolValue] == YES) {
        [arguments addObject:@"-osshfs_debug"];
    }
	if ([[parameters objectForKey:kSSHFSFuseDebugParameter] boolValue] == YES) {
        [arguments addObject:@"-odebug"];
    }
	if ([[parameters objectForKey:kSSHFSSshDebugParameter] boolValue] == YES) {
	[arguments addObject:@"-ologlevel=debug1"];
    }
	[arguments addObject:@"-f"];
	[arguments addObject:[NSString stringWithFormat:@"-ovolname=%@", [parameters objectForKey:kMFFSVolumeNameParameter]]];
	[arguments addObject:[NSString stringWithFormat:@"-ovolicon=%@", [parameters objectForKey:kMFFSVolumeIconPathParameter]]];
	// MFLogS(self, @"Arguments are %@", arguments);
	return [arguments copy];
}

- (NSDictionary *)taskEnvironmentForParameters:(NSDictionary *)params {
	NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
	[env setObject:[self askpassPath] forKey:@"SSH_ASKPASS"];
	[env setObject:mfsecTokenForFilesystemWithUUID([params objectForKey:kMFFSUUIDParameter]) forKey:@"SSHFS_TOKEN"];

	// MFLogS(self, @"Returning environment %@", env);
	return [env copy];
}

# pragma mark Quickmount
- (NSArray *)urlSchemesHandled {
	return [NSArray arrayWithObjects:@"ssh", @"sftp", nil];
}

- (NSDictionary *)parameterDictionaryForURL:(NSURL*)url error:(NSError **)outError {
	NSString *host = [url host];
	NSString *userName = [url user];
	NSNumber *port = [url port];
	NSString *directory = [url relativePath];
	
	NSMutableDictionary *params = [[self defaultParameterDictionary] mutableCopy];
	if (host) {
		[params setObject:host forKey:kNetFSHostParameter];
	}
	if (userName) {
		[params setObject:userName forKey:kNetFSUserParameter];
	}
	if (port) {
		[params setObject:port forKey:kNetFSPortParameter];
	}
	if (directory) {
		[params setObject:directory forKey:kNetFSDirectoryParameter];
	}
	
	return [params copy];
}

# pragma mark Parameters
- (NSArray *)parameterList {
	return [NSArray arrayWithObjects:kNetFSUserParameter,kNetFSHostParameter, kNetFSDirectoryParameter, kNetFSUserParameter,kNetFSPortParameter, kNetFSProtocolParameter, kSSHFSFollowSymlinksParameter,kSSHFSCompressionParameter, kSSHFSDeferPermissionsParameter, kSSHFSAutoCacheParameter, kSSHFSFuseDebugParameter, kSSHFSSshfsDebugParameter, kSSHFSSshDebugParameter, nil ];
}

- (NSArray *)secretsList {
	return [NSArray arrayWithObjects:kNetFSPasswordParameter, nil];
}

- (NSDictionary *)defaultParameterDictionary {
	NSDictionary *defaultParameters = [NSDictionary dictionaryWithObjectsAndKeys:
						NSUserName(), kNetFSUserParameter,
						@"", kNetFSDirectoryParameter,
						[NSNumber numberWithInt:22], kNetFSPortParameter,
						[NSNumber numberWithInt:kSecProtocolTypeSSH], kNetFSProtocolParameter,
						[NSNumber numberWithBool:YES], kSSHFSFollowSymlinksParameter,
						[NSNumber numberWithBool:YES], kSSHFSCompressionParameter,
                        [NSNumber numberWithBool:YES], kSSHFSDeferPermissionsParameter,
                        [NSNumber numberWithBool:YES], kSSHFSAutoCacheParameter,
                        [NSNumber numberWithBool:NO], kSSHFSFuseDebugParameter,
                        [NSNumber numberWithBool:NO], kSSHFSSshfsDebugParameter,
                        [NSNumber numberWithBool:NO], kSSHFSSshDebugParameter,
									   nil];
	
	return defaultParameters;
}

- (NSString *)descriptionForParameters:(NSDictionary *)parameters {
	NSString *description = nil;
	if (![parameters objectForKey:kNetFSHostParameter]) {
		description = @"No host specified";
	} else {
		if([parameters objectForKey:kNetFSUserParameter] && ![[parameters objectForKey:kNetFSUserParameter] isEqualTo:NSUserName()]) {
			description = [NSString stringWithFormat:@"%@@%@",
						   [parameters objectForKey:kNetFSUserParameter],
						   [parameters objectForKey:kNetFSHostParameter]];
		} else {
			description = [NSString stringWithString:[parameters objectForKey:kNetFSHostParameter]];
		}
	}
	
	return description;
}

- (id)impliedValueParameterNamed:(NSString *)parameterName otherParameters:(NSDictionary *)parameters {
	if ([parameterName isEqualToString:kMFFSMountPathParameter] && [parameters objectForKey:kNetFSHostParameter]) {
		NSString *mountBathBase = [parameters objectForKey:kMFFSNameParameter] ? [parameters objectForKey:kMFFSNameParameter] :[parameters objectForKey:kNetFSHostParameter];
		
		NSString *mountPath = [NSString stringWithFormat:@"/Volumes/%@", mountBathBase];
		return mountPath;
	}
	if ([parameterName isEqualToString:kMFFSVolumeNameParameter] && [parameters objectForKey:kNetFSHostParameter]) {
		return [parameters objectForKey:kNetFSHostParameter];
	}
	
	if ([parameterName isEqualToString:kMFFSVolumeIconPathParameter]) {
		return [[NSBundle bundleForClass:[self class]] pathForImageResource:@"sshfs_icon"];
	}
	if ([parameterName isEqualToString:kMFFSVolumeImagePathParameter]) {
		return [[NSBundle bundleForClass:[self class]] pathForImageResource:@"sshfs"];
	}
	if ([parameterName isEqualToString:kMFFSNameParameter]) {
		return [parameters objectForKey:kNetFSHostParameter];
	}
	
	return nil;
}

# pragma mark Validation
- (BOOL)validateValue:(id)value forParameterName:(NSString*)paramName error:(NSError **)outError {
	if ([paramName isEqualToString:kNetFSPortParameter]) {
		NSNumber* converted = [NSNumber numberWithInt:[value intValue]];
		if([converted isKindOfClass:[NSNumber class]] && [converted intValue] > 0 && [converted intValue] < 65535) {
			return YES;
		} else {
			if (outError) {
				*outError = [MFError invalidParameterValueErrorWithParameterName:kNetFSPortParameter value:value description:@"Must be positive number < 65535"];	
			}
			return NO;
		}
	}
	
	return YES;
}

- (BOOL)validateParameters:(NSDictionary *)parameters error:(NSError **)outError {
	for (NSString *paramName in [parameters allKeys]) {
		BOOL ok = [self validateValue:[parameters objectForKey:paramName] forParameterName:paramName error:outError];
		
		if (!ok) {
			return NO;
		}
	}
	
	if (![parameters objectForKey:kNetFSHostParameter]) {
		if (outError) {
			*outError = [MFError parameterMissingErrorWithParameterName:kNetFSHostParameter];	
		}
		return NO;
	}
	
	return YES;
}

- (NSError *)errorForParameters:(NSDictionary *)parameters output:(NSString *)output {
	if ([output rangeOfString:@"Permission denied"].location != NSNotFound) {
		return [MFError errorWithErrorCode:kMFErrorCodeMountFaliure description:@"Authentication has failed."];
	}
	
	if ([output rangeOfString:@"Error resolving hostname"].location != NSNotFound) {
		return [MFError errorWithErrorCode:kMFErrorCodeMountFaliure description:@"Remote host could not be found."];
	}
	
	if ([output rangeOfString:@"remote host has disconnected"].location != NSNotFound) {
		return [MFError errorWithErrorCode:kMFErrorCodeMountFaliure description:@"Remote host has disconnected."];
	}
	
	if ([output rangeOfString:@"Host key verification failed"].location != NSNotFound) {
		return [MFError errorWithErrorCode:kMFErrorCodeMountFaliure description:@"Host key verification has failed."];
	}

	return nil;
}

# pragma mark UI
- (NSViewController *)primaryViewController {
	NSViewController* primaryViewController = [[NSViewController alloc] initWithNibName:@"sshfsConfiguration" bundle:[NSBundle bundleForClass:[self class]]];
	[primaryViewController setTitle:@"SSH"];
	return primaryViewController;
}

- (NSViewController *)advancedviewController {
	NSViewController* advancedviewController = [[NSViewController alloc] initWithNibName:@"sshfsAdvanced" bundle:[NSBundle bundleForClass:[self class]]];
	[advancedviewController setTitle:@"SSH Advanced"];
	return advancedviewController;
}

- (NSArray *)viewControllerKeys {
	return [NSArray arrayWithObjects:primaryViewControllerKey, advancedViewControllerKey, kMFUIMacfusionAdvancedViewKey,
			nil];
}

- (NSViewController *)viewControllerForKey:(NSString *)key {
	if (key == primaryViewControllerKey) {
		return [self primaryViewController];
	}
	if (key == advancedViewControllerKey) {
		return [self advancedviewController];
	}
	
	return nil;
}


# pragma mark Subclassing
// This is an example of how to specify subclasses
- (Class)subclassForClass:(Class)superclass {
	if ([NSStringFromClass(superclass) isEqualToString:@"MFServerFS"]) {
		return [SSHServerFS class];
	}
	
	return nil;
}

@end
