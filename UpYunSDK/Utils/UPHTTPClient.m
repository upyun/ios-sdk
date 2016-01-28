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

@property (copy) HttpProgressBlock progressBlock;
@property (copy) HttpSuccessBlock successBlock;
@property (copy) HttpFailBlock failureBlock;

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionTask *sessionTask;
@property (nonatomic, strong) NSMutableData *didReceiveData;
@property (nonatomic, strong) NSURLResponse *didReceiveResponse;
@property (nonatomic, assign) BOOL didCompleted;

@end


@implementation UPHTTPClient

- (id)init {
    self = [super init];
    if (self) {
        _didCompleted = NO;
    }
    return self;
}

- (void)cancel {
    [_sessionTask cancel];
}

- (NSMutableData *)didReceiveData {
    if (!_didReceiveData) {
        _didReceiveData = [[NSMutableData alloc]init];
    }
    return _didReceiveData;
}

- (NSURLSession *)session {
    if (!_session) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:[NSOperationQueue mainQueue]];
    }
    return _session;
}

- (void)uploadRequest:(NSMutableURLRequest *)request
              success:(HttpSuccessBlock)successBlock
              failure:(HttpFailBlock)failureBlock
             progress:(HttpProgressBlock)progressBlock {
    //发起请求
    _progressBlock = progressBlock;
    _successBlock = successBlock;
    _failureBlock = failureBlock;
    
    _sessionTask = [self.session dataTaskWithRequest:request];
    [_sessionTask resume];
}



#pragma mark NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    if (!_didCompleted) {
        if (_progressBlock) {
            _progressBlock(totalBytesSent, totalBytesExpectedToSend);
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    _didCompleted = YES;
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
                    _successBlock(_didReceiveResponse, self.didReceiveData);
                }
            } else {
                NSString *errorString = [[NSString alloc] initWithData:self.didReceiveData encoding:NSUTF8StringEncoding];
                NSError *error = [[NSError alloc] initWithDomain:@"UPHTTPClient"
                                                            code:statusCode
                                                        userInfo:@{NSLocalizedDescriptionKey:errorString}];
                if (_failureBlock) {
                    _failureBlock(error);
                }
            }
        }
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
    [self.didReceiveData appendBytes:data.bytes length:data.length];
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

#pragma mark NSProgress KVO

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