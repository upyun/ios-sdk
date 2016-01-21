//
//  UPHTTPClient.h
//  UPYUNSDK
//
//  Created by DING FENG on 11/30/15.
//  Copyright © 2015 DING FENG. All rights reserved.
//

#import <Foundation/Foundation.h>


@class UPHTTPClient;


typedef void(^HttpSuccessBlock)(NSURLResponse *response, id responseObject);
typedef void(^HttpFailBlock)(NSError *error);
typedef void(^HttpProgressBlock)(int64_t completedBytesCount, int64_t totalBytesCount);


@interface UPHTTPClient : NSObject


- (void)uploadRequest:(NSMutableURLRequest *)request
            success:(HttpSuccessBlock)successBlock
            failure:(HttpFailBlock)failureBlock
           progress:(HttpProgressBlock)progressBlock;


// Multi-Part Request
- (void)sendMultipartFormRequestWithMethod:(NSString *)method
                                       url:(NSString *)urlString
                                parameters:(NSDictionary *)formParameters
                            filePathOrData:(id)filePathOrData
                                 fieldName:(NSString *)name
                                  fileName:(NSString *)filename
                                 mimeTypes:(NSString *)mimeType
                                   success:(HttpSuccessBlock)successBlock
                                   failure:(HttpFailBlock)failureBlock
                                  progress:(HttpProgressBlock)progressBlock;


// URL-Form-Encoded Request
- (void)sendURLFormEncodedRequestWithMethod:(NSString *)methed
                                        url:(NSString *)urlString
                                 parameters:(NSDictionary *)formParameters
                                    success:(HttpSuccessBlock)successBlock
                                    failure:(HttpFailBlock)failureBlock;

- (void)cancel;

@end
