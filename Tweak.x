#import <UIKit/UIKit.h>
#import <Security/Security.h>

@interface AccountTableViewController : UITableViewController
@end

// need to store this to present the alert
static AccountTableViewController *tableVC = nil;

static void presentAlert(NSString *message, NSString *outputString) {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"2FA Export" message:message preferredStyle:UIAlertControllerStyleAlert];

	[alert addAction:[UIAlertAction actionWithTitle:@"Copy otpauth URIs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[UIPasteboard generalPasteboard] setString:outputString];
	}]];

	[alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];

	[tableVC presentViewController:alert animated:YES completion:nil];
}

static BOOL processKeychainItem(NSDictionary *item, NSDictionary **outJSON, NSString **outError) {
	NSString *displayName = item[(__bridge id)kSecAttrAccount];

	NSData *passwordData = item[(__bridge id)kSecValueData];
	if (!passwordData) {
		*outError = [NSString stringWithFormat:@"No password data found for item '%@'", displayName];
		return NO;
	}

	NSError *jsonError = nil;
	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:passwordData options:0 error:&jsonError];
	if (!json) {
		*outError = [NSString stringWithFormat:@"Invalid password data for item '%@' (error: %@)", displayName, jsonError];
		return NO;
	}

	if (!json[@"AccountOathSecretKey"] || ![json[@"AccountType"]isEqual:@(2)]) {
		*outError = [NSString stringWithFormat:@"Account type not supported for item '%@'", displayName];
		return NO;
	}

	*outJSON = json;
	return YES;
}

static NSString *generateOTPAuthURI(NSDictionary *json) {	
	NSString *accountName = json[@"AccountName"];
	NSString *accountUsername = json[@"AccountUsername"];
	NSString *secretKey = [json[@"AccountOathSecretKey"] stringByReplacingOccurrencesOfString:@" " withString:@""];

	return [NSString stringWithFormat:@"otpauth://totp/%@:%@?secret=%@&issuer=%@", accountName, accountUsername, secretKey, accountName];

	// Ente does not like URL encoding and seems to work fine without it
	// keeping this commented in case it's needed in the future
	// return [uri stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
}

static void handleResults(NSArray *successfulItems, NSArray *failedErrors) {
	NSMutableString *outputString = [NSMutableString string];
	NSMutableString *alertString = [NSMutableString string];

	if (failedErrors.count > 0) {
		[alertString appendString:@"Could not process the following items:\n"];

		for (NSDictionary *json in failedErrors) {
			[alertString appendFormat:@"- %@\n", json];
		}

		[alertString appendString:@"\n"];
	}

	[alertString appendString:@"Successfully processed the following items:\n"];

	for (NSDictionary *json in successfulItems) {
		[outputString appendFormat:@"%@\n", generateOTPAuthURI(json)];
		[alertString appendFormat:@"- %@ (%@)\n", json[@"AccountName"], json[@"AccountUsername"]];
	}

	presentAlert(alertString, outputString);
}

static void processKeychain() {
	NSDictionary *query = @{
		(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService: @"com.microsoft.authenticator.backup",
		(__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
		(__bridge id)kSecAttrSynchronizable: @YES,
		(__bridge id)kSecReturnAttributes: @YES,
		(__bridge id)kSecReturnData: @YES,
		(__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
	};

	CFTypeRef result = NULL;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

	if (status == errSecSuccess && result != NULL) {
		NSArray *items = (__bridge_transfer NSArray *)result;
		NSMutableArray *successfulItems = [NSMutableArray array];
		NSMutableArray *failedErrors = [NSMutableArray array];

		for (NSDictionary *item in items) {
			NSDictionary *json = nil;
			NSString *errorMessage = nil;

			if (processKeychainItem(item, &json, &errorMessage)) {
				[successfulItems addObject:json];
			} else {
				[failedErrors addObject:errorMessage];
			}
		}

		handleResults(successfulItems, failedErrors);
	} else if (status == errSecItemNotFound) {
		NSLog(@"[MS-2FA-Export] No keychain entries found");
	} else {
		NSLog(@"[MS-2FA-Export] Keychain query failed with status: %d", (int)status);
	}
}

%hook AccountTableViewController
-(void)viewDidLoad {
	%orig;
	tableVC = self;
}
%end

%hook UINavigationItem
-(void)setRightBarButtonItems:(NSArray *)rightBarButtonItems {
	// ignore if on wrong page, or if we haven't grabbed a vc instance
	if (rightBarButtonItems.count != 2 || !tableVC) {
		%orig;
		return;
	}

	// create export button
	UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"] style:UIBarButtonItemStylePlain target:self action:@selector(export_2fa)];

	// add to nav bar
	NSMutableArray *items = [rightBarButtonItems mutableCopy];
	[items addObject:button];
	%orig(items);
}

%new
-(void)export_2fa {
	processKeychain();
}
%end
