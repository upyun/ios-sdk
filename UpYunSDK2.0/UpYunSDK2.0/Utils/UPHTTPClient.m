//
//  UPHTTPClient.m
//  UPYUNSDK
//
//  Created by DING FENG on 11/30/15.
//  Copyright © 2015 DING FENG. All rights reserved.
//

#import "UPHTTPClient.h"
#import "UPMultipartBody.h"


@interface UPHTTPClient() <NSURLSessionDelegate>
{
    NSURLSession *_session;
    NSURLSessionConfiguration *_sessionConfiguration;
    NSTimeInterval _timeInterval;
    NSMutableDictionary *_headers;
    HttpProgressBlock _progressBlock;
    HttpSuccessBlock _successBlock;
    HttpFailBlock _failureBlock;
    NSURLSessionTask *_sessionTask;
    NSMutableData *_didReceiveData;
    NSURLResponse *_didReceiveResponse;
    BOOL _didCompleted;
}

@end


@implementation UPHTTPClient

- (id)init {
    self = [super init];
    if (self) {
        _didCompleted = NO;
        _headers = [[NSMutableDictionary alloc] init];
        _sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:_sessionConfiguration
                                                              delegate:self
                                                         delegateQueue:nil];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"client dealloc");
    _session = nil;
    _sessionConfiguration = nil;
    _timeInterval = 0;
    _headers = nil;
    _progressBlock = nil;
    _successBlock = nil;
    _failureBlock = nil;
    _sessionTask = nil;
    _didReceiveData = nil;
    _didReceiveResponse = nil;
    _didCompleted = nil;
}

- (void)cancel {
    [_sessionTask cancel];
}


- (void)uploadRequest:(NSMutableURLRequest *)request
              success:(HttpSuccessBlock)successBlock
              failure:(HttpFailBlock)failureBlock
             progress:(HttpProgressBlock)progressBlock {
    //发起请求
    _progressBlock = progressBlock;
    _successBlock = successBlock;
    _failureBlock = failureBlock;
    _sessionTask = [_session dataTaskWithRequest:request];
    [_sessionTask resume];
}


- (void)sendMultipartFormRequestWithMethod:(NSString *)method
                                       url:(NSString *)urlString
                                parameters:(NSDictionary *)formParameters
                            filePathOrData:(id)filePathOrData
                                 fieldName:(NSString *)name
                                  fileName:(NSString *)filename
                                 mimeTypes:(NSString *)mimeType
                                   success:(HttpSuccessBlock)successBlock
                                   failure:(HttpFailBlock)failureBlock
                                  progress:(HttpProgressBlock)progressBlock {
    NSData *fileData;
    if ([filePathOrData isKindOfClass:[NSString class]]) {
        fileData = [NSData dataWithContentsOfFile:(NSString *)filePathOrData];
    } else {
        fileData = (NSData *)filePathOrData;
    }
    
    if (!name) {
        name = @"file";
    }
    if (!filename) {
        filename = @"filename";
    }
    if (!mimeType) {
        mimeType = @"application/octet-stream";
    }
    _progressBlock = progressBlock;
    _successBlock = successBlock;
    _failureBlock = failureBlock;
    NSString *boundary = @"UpYunSDKFormBoundaryFriSep25V01";
    boundary = [NSString stringWithFormat:@"%@%u", boundary,  arc4random() & 0x7FFFFFFF];
    
    
    UPMultipartBody *multiBody = [[UPMultipartBody alloc]initWithBoundary:boundary];
    [multiBody addDictionary:formParameters];
    
    [multiBody addFileData:fileData WithFileName:name];
    
    [multiBody dataFromPart];
    
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    //设置URLRequest
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    if (_headers) {
        for (NSString *key in _headers) {
            [request setValue:[_headers objectForKey:key] forHTTPHeaderField:key];
        }
    }
    request.HTTPBody = [multiBody dataFromPart];
    request.timeoutInterval = _timeInterval;
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    //发起请求
    _sessionTask = [_session dataTaskWithRequest:request];
    [_sessionTask resume];
}

- (void)sendURLFormEncodedRequestWithMethod:(NSString *)methed
                                        url:(NSString *)urlString
                                 parameters:(NSDictionary *)formParameters
                                    success:(HttpSuccessBlock)successBlock
                                    failure:(HttpFailBlock)failureBlock {
    NSURL *url = [[NSURL alloc] initWithString:urlString];
    NSMutableURLRequest *request = (NSMutableURLRequest *)[NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSMutableString *postParameters = [NSMutableString new];
    for (NSString *key in formParameters.allKeys) {
        NSString *keyValue = [NSString stringWithFormat:@"&%@=%@",key, [formParameters objectForKey:key]];
        [postParameters appendString:keyValue];
    }
    NSData *postData = [NSData data];
    if (postParameters.length > 1) {
        postData = [[postParameters substringFromIndex:1] dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    request.HTTPBody = postData;
    _sessionTask = [_session dataTaskWithRequest:request
                              completionHandler:^(NSData *data,
                                                  NSURLResponse *response,
                                                  NSError *error) {
                                  if (error) {
                                      failureBlock(error);
                                  } else {
                                      //判断返回状态码错误。
                                      NSInteger statusCode =((NSHTTPURLResponse *)response).statusCode;
                                      NSIndexSet *succesStatus = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
                                      if ([succesStatus containsIndex:statusCode]) {
                                          successBlock(response, data);
                                      } else {
                                          
                                          NSString *errorString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                          NSError *erro = [[NSError alloc]initWithDomain:@"UPHTTPClient" code:0
                                                                                userInfo:@{NSLocalizedDescriptionKey:errorString}];
                                          failureBlock(erro);
                                      }
                                  }
                              }];
    [_sessionTask resume];
}

#pragma mark NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    dispatch_async(dispatch_get_main_queue(), ^(){
        if (!_didCompleted) {
            if (_progressBlock) {
                _progressBlock(totalBytesSent, totalBytesExpectedToSend);
            }
        }
    });
}

-(void)URLSession:(NSURLSession *)session
             task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    _didCompleted = YES;
    dispatch_async(dispatch_get_main_queue(), ^(){
        if (error) {
            if (_failureBlock) {
                _failureBlock(error);
            }
            
        } else {
            //判断返回状态码错误。
            NSInteger statusCode =((NSHTTPURLResponse *)_didReceiveResponse).statusCode;
            NSIndexSet *succesStatus = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
            if ([succesStatus containsIndex:statusCode]) {
                
                if (_successBlock) {
                    _successBlock(_didReceiveResponse, _didReceiveData);
                }
                
            } else {
                
                NSString *errorString = [[NSString alloc] initWithData:_didReceiveData encoding:NSUTF8StringEncoding];
                NSError *error = [[NSError alloc] initWithDomain:@"UPHTTPClient"
                                                            code:0
                                                        userInfo:@{NSLocalizedDescriptionKey:errorString}];
                if (_failureBlock) {
                    _failureBlock(error);
                }
            }
        }
        _sessionTask = nil;
        _progressBlock = nil;
        _successBlock = nil;
        _failureBlock = nil;
        _didReceiveData = nil;
        _didReceiveData = nil;
        _didReceiveResponse = nil;
        _sessionConfiguration = nil;
        _session = nil;
    });
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    completionHandler(NSURLSessionResponseAllow);
    _didReceiveResponse = response;
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    if (_didReceiveData) {
        [_didReceiveData appendBytes:data.bytes length:data.length];
    } else {
        _didReceiveData = [[NSMutableData alloc] init];
        [_didReceiveData appendBytes:data.bytes length:data.length];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                             NSURLCredential *credential))completionHandler {
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        completionHandler(NSURLSessionAuthChallengeUseCredential,
                          [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    }
}

#pragma NSProgress KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"fractionCompleted"]) {
        NSProgress *progress = (NSProgress *)object;
        if (_progressBlock) {
            _progressBlock(progress.completedUnitCount, progress.totalUnitCount);
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end