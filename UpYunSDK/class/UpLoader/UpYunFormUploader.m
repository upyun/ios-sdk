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


#define  NSErrorDomain_UpYunFormUploader   @"NSErrorDomain_UpYunFormUploader"

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
//    NSLog(@"urlString %@", urlString);
//    NSLog(@"police %@", police);
    
    NSString *uri = [NSString stringWithFormat:@"/%@/", bucketName];
    NSString *signature = [UpApiUtils getSignatureWithPassword:operatorPassword
                                                    parameters:@[@"POST", uri, date, police, content_md5]];
    
//    NSLog(@"signature %@", signature);
    NSString *authorization = [NSString stringWithFormat:@"UPYUN %@:%@", operatorName, signature];
    NSDictionary *parameters = @{@"policy": police, @"authorization": authorization};

    
    if (fileName.length <= 0) {
        fileName = @"fileName";
    }
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
                             NSError *error_json; //接口期望的是 json 数据

                             if (body) {
                                 //有返回 body ：尝试按照 json 解析。
                                 NSDictionary *json = [NSJSONSerialization JSONObjectWithData:body options:kNilOptions error:&error];
                                 retObj = json;
                                 if (error_json) {
                                     NSLog(@"NSErrorDomain_UpYunFormUploader json parse failed %@", error_json);
                                     NSLog(@"NSErrorDomain_UpYunFormUploader res.body content %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
                                 }
                             }
                             
                             // http 请求错误，网络错误。取消，超时，断开等
                             if (error) {
                                 failureBlock(error, res, retObj);
                                 return ;
                             }
                             
                             // http 请求 res body 格式错误，无法进行 json 序列化
                             if (error_json) {
                                 failureBlock(error_json, res, nil);
                                 return ;
                             }
                             
                             // api 接口错误。参数错误，权限错误
                             if (res.statusCode >= 400) {
                                 if (!error) {
                                     error  = [[NSError alloc] initWithDomain:NSErrorDomain_UpYunFormUploader
                                                                         code:res.statusCode
                                                                     userInfo:NULL];
                                 }
                                 
                                 NSLog(@"parameters %@", parameters);
                                 failureBlock(error, res, retObj);
                                 
                                 return ;
                             }
                             
                             // 上传成功
                             successBlock(res, retObj);
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
