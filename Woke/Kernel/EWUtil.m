//
//  EWUtil.m
//  EarlyWorm
//
//  Created by Lei on 8/19/13.
//  Copyright (c) 2013 Shens. All rights reserved.
//
//  This class serves as the basic file input/output class that handles file namagement and memory management

#import "EWUtil.h"
#import <AdSupport/ASIdentifierManager.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

//static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation EWUtil

+ (NSString *)UUID{
    
    NSString *uuid = [[NSUUID UUID] UUIDString];
    
    return uuid;
    
}
	
+ (NSString *)ADID{
    NSString *adId = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    return adId;
}

+(void)clearMemory{
    //
}

+ (NSDictionary *)timeFromNumber:(double)number{
    NSMutableDictionary *dic = [NSMutableDictionary new];
    NSInteger hour = floor(number);
    NSInteger minute = round((number - hour)*100);
    dic[@"hour"] = [NSNumber numberWithInteger:hour];
    dic[@"minute"] = [NSNumber numberWithInteger: minute];
    return dic;
}

+ (double)numberFromTime:(NSDictionary *)dic{
    double hour = [(NSNumber *)dic[@"hour"] doubleValue];
    double minute = [(NSNumber *)dic[@"minute"] doubleValue];
    double number = hour + minute/100;
    return number;
}


+ (BOOL) isMultitaskingSupported {
    
    BOOL result = NO;
    
    if ([[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)]){
        result = [[UIDevice currentDevice] isMultitaskingSupported];
    }
    return result;
}

+(BOOL) isFirstTimeLogin{
    
    NSDictionary *option = @{@"firstTime": @"YES"};
    [[NSUserDefaults standardUserDefaults] registerDefaults:option];
    
    NSString *isString = [[NSUserDefaults standardUserDefaults] valueForKey:@"firstTime"];
    
    if ([isString isEqualToString:@"YES"]) {
        
        return YES;
        
    }
    else{
        
        return NO;
    }

}
+(void)setFirstTimeLoginOver{
    
    [[NSUserDefaults standardUserDefaults] setValue:@"NO" forKey:@"firstTime"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+(NSString *)uploadImageToParseREST:(UIImage *)uploadImage
{
    
    NSMutableString *urlString = [NSMutableString string];
    [urlString appendString:kParseUploadUrl];
    [urlString appendFormat:@"files/imagefile.jpg"];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request addValue:kParseApplicationId forHTTPHeaderField:@"X-Parse-Application-Id"];
    [request addValue:kParseRestAPIId forHTTPHeaderField:@"X-Parse-REST-API-Key"];
    [request addValue:@"image/jpeg" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:UIImagePNGRepresentation(uploadImage)];
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    NSString *fileUrl = [httpResponse allHeaderFields][@"Location"];
    
    NSLog(@"%@",fileUrl);
    return fileUrl;

}

+ (void)deleteFileFromParseRESTwithURL:(NSURL *)url{
    //If you still want to delete a file, you can do so through the REST API. You will need to provide the master key in order to be allowed to delete a file. Note that the name of the file must be the name in the response of the upload operation, rather than the original filename.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"DELETE"];
    [request addValue:kParseApplicationId forHTTPHeaderField:@"X-Parse-Application-Id"];
    [request addValue:kParseRestAPIId forHTTPHeaderField:@"X-Parse-REST-API-Key"];
    [request addValue:@"X-Parse-Master-Key" forHTTPHeaderField:kParseMasterKey];
    [request addValue:@"image/jpeg" forHTTPHeaderField:@"Content-Type"];
    request.URL = url;
    
    [NSURLConnection sendAsynchronousRequest:request queue:nil completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            NSLog(@"Failed to delete photo: %@", connectionError);
        }
    }];
    
}


#pragma mark - Logging
void EWLog(NSString *format, ...){
    
    
    va_list args;
    va_start(args, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
#ifdef DEBUG
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //dispatch to NSLOG
        
        NSArray *symbolList = logLevelSymbols;
        if ([format hasPrefix:symbolList[0]]){
            DDLogError(str);
        }else if ([format hasPrefix:symbolList[1]]) {
            DDLogWarn(str);
        }else if ([format hasPrefix:symbolList[2]]) {
            DDLogInfo(str);
        }else if ([format hasPrefix:symbolList[3]]) {
            DDLogDebug(str);
        }else{
            DDLogVerbose(str);
        }
    });
#else
    //only send to TestFlight on release version
    TFLog(str);
#endif
    
}

+(NSArray *)readContactsEmailsFromAddressBooks
{
    
    NSMutableArray * friendsEmails = [[NSMutableArray alloc] init];
    
    ABAddressBookRef addressBook = ABAddressBookCreate();
    CFArrayRef results = ABAddressBookCopyArrayOfAllPeople(addressBook);
    for(int i = 0; i < CFArrayGetCount(results); i++)
    {
        ABRecordRef person = CFArrayGetValueAtIndex(results, i);
        //读取firstname
//        NSString *personName = (__bridge NSString*)ABRecordCopyValue(person, kABPersonFirstNameProperty);
//        //读取lastname
//        NSString *lastname = (__bridge NSString*)ABRecordCopyValue(person, kABPersonLastNameProperty);
//       
//        //读取middlename
//        NSString *middlename = (__bridge NSString*)ABRecordCopyValue(person, kABPersonMiddleNameProperty);

        
        //获取email多值
        ABMultiValueRef email = ABRecordCopyValue(person, kABPersonEmailProperty);
        long emailcount = ABMultiValueGetCount(email);
        for (int x = 0; x < emailcount; x++)
        {
            //获取email Label
            //NSString* emailLabel = (__bridge NSString*)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(email, x));
            //获取email值
            NSString* emailContent = (__bridge NSString*)ABMultiValueCopyValueAtIndex(email, x);
            [friendsEmails addObject:emailContent];

        }
    }

    CFRelease(results);
    CFRelease(addressBook);
    
    return [friendsEmails copy];
    
}


@end
