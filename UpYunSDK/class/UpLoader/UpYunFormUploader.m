//
//  UpYunFormUploader.m
//  UpYunSDKDemo
//
//  Created by DING FENG on 2/13/17.
//  Copyright © 2017 upyun. All rights reserved.
//

#import "UpYunFormUploader.h"
#import "UpSimpleHttpClient.h"
#import "UpApiUtils.h"



@interface UpYunFormUploader()
{
    UpSimpleHttpClient *_httpClient;
}
@end



@implementation UpYunFormUploader

- (void)uploadWithBucketName:(NSString *)bucketName
                  formAPIKey:(NSString *)formAPIKey
                    fileData:(NSData *)fileData
                    fileName:(NSString *)fileName
                     saveKey:(NSString *)saveKey
             otherParameters:(NSDictionary *)otherParameters
                     success:(UpLoaderSuccessBlock)successBlock
                     failure:(UpLoaderFailureBlock)failureBlock
                    progress:(UpLoaderProgressBlock)progressBlock {
    
    
    
    NSDate *now = [NSDate date];
    NSString *expiration = [NSString stringWithFormat:@"%.0f",[now timeIntervalSince1970] + 1800];//自签名30分钟后过期
    
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
    
    
    NSString *date = [dateFormatter stringFromDate:now];
    NSString *content_md5 = [UpApiUtils getMD5HashFromData:fileData];
    NSDictionary *policyDict = @{@"bucket": bucketName,
                                 @"save-key": saveKey,
                                 @"expiration": expiration,
                                 @"date": date,
                                 @"content-md5": content_md5};
    NSString *urlString = [NSString stringWithFormat:@"%@/%@/", UpYunFormUploaderServerHost, bucketName];
    NSString *police = [UpApiUtils getPolicyWithParameters:policyDict];
    
    NSLog(@"urlString %@", urlString);
    NSLog(@"police %@", police);
    
//    getSignatureWithPassword
    NSString *uri = [NSString stringWithFormat:@"/%@/", bucketName];
    NSString *signature = [UpApiUtils getSignatureWithPassword:formAPIKey parameters:@[@"POST", uri, date, police, content_md5]];
    
    NSLog(@"signature %@", signature);
    NSString *authorization = [NSString stringWithFormat:@"UPYUN %@:%@", @"test86400", signature];
    NSDictionary *parameters = @{@"policy": police, @"authorization": authorization};
    
//    -F authorization="UPYUN <Operator>:<Signature>" \
    
    _httpClient = [UpSimpleHttpClient POST:urlString
                                parameters:parameters
                                  formName:@"file"
                                  fileName:fileName
                                  mimeType:@""
                                      file:fileData
                         sendProgressBlock:^(NSProgress *progress) {
                             
                         }
                         completionHandler:^(NSError *error,
                                             id response,
                                             NSData *body) {
                             
                             NSLog(@"response %@", response);
                             NSLog(@"body %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
                         }];


}


- (void)uploadWithPolicy:(NSString *)policy
               signature:(NSString *)signature
                fileData:(NSData *)fileData
                fileName:(NSString *)fileName
                 success:(UpLoaderSuccessBlock)successBlock
                 failure:(UpLoaderFailureBlock)failureBlock
                progress:(UpLoaderProgressBlock)progressBlock{
}

- (void)cancel {

}

@end
