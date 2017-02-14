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


#define  NSErrorDomain

@interface UpYunFormUploader()
{
    UpSimpleHttpClient *_httpClient;
}
@end



@implementation UpYunFormUploader



- (void)uploadWithBucketName:(NSString *)bucketName
                    operator:(NSString *)operatorName
                    password:(NSString *)operatorPassword
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
    NSString *signature = [UpApiUtils getSignatureWithPassword:operatorPassword
                                                    parameters:@[@"POST", uri, date, police, content_md5]];
    
    NSLog(@"signature %@", signature);
    NSString *authorization = [NSString stringWithFormat:@"UPYUN %@:%@", operatorName, signature];
    NSDictionary *parameters = @{@"policy": police, @"authorization": authorization};

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
                             
                             
                             
                             NSHTTPURLResponse *res = response;
                             NSDictionary *retObj  = NULL;// 期待返回的数据结构
                             NSString *retMessage  = @""; // 可阅读的描述消息
                             NSError *error_json; //接口期望的是 json 数据

                             
                             
                             if (body) {
                                 //有返回 body ：尝试按照 json 解析。
                                 NSDictionary *json = [NSJSONSerialization JSONObjectWithData:body options:kNilOptions error:&error];
                                 retObj = json;
                                 if (error_json) {
                                     NSLog(@"json parse failed %@", error_json);
                                 }
                             }
                             
                             
//                             
//                             typedef void (^UpLoaderSuccessBlock)(NSHTTPURLResponse *response, NSDictionary *responseBody);
//                             typedef void (^UpLoaderFailureBlock)(NSError *error, NSHTTPURLResponse *response, NSDictionary *responseBody);
//                             typedef void (^UpLoaderProgressBlock)(int64_t completedBytesCount, int64_t totalBytesCount);
//                             
//
                             
                             // http 请求错误。取消，超时，断开等
                             if (error) {
                                 failureBlock(error, res, retObj);
                             }
                             
                             if (res.statusCode >= 400) {
                                 if (!error) {
                                     error  = [[NSError alloc] initWithDomain:NSErrorDomain code:res.statusCode userInfo:NULL];
                                 }
                             }
                             
                             
                             
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
