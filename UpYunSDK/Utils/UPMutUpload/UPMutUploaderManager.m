//
//  UMUUploaderManager.m
//  UpYunMultipartUploadSDK
//
//  Created by Jack Zhou on 6/10/14.
//
//

#import "UPMutUploaderManager.h"
#import "NSData+MD5Digest.h"
#import "NSString+NSHash.h"
#import "UPHTTPClient.h"
#import "UPMultipartBody.h"


static NSString *UPMut_ERROR_DOMAIN = @"分块上传";

/**
 *  请求api地址
 */
static NSString *API_SERVER = @"http://m0.api.upyun.com/";


/**
 *  同一个bucket 上传文件时最大并发请求数
 */
static NSInteger MaxConcurrentOperationCount = 10;

/**
 *   默认授权时间长度（秒)
 */
static NSInteger ValidTimeSpan = 600.0f;

/**
 *   请求重试次数
 */
static NSInteger MaxRetryCount = 3;

static NSMutableDictionary *managerRepository;


@interface UPMutUploaderManager() {
    NSString *_saveToken;
    NSArray *_filesStatus;
    NSString *_tokenSecret;
    NSMutableArray *_remainingFileBlockIndexs;
    NSMutableArray *_progressArray;
    
    int _blockFailed;
    int _blockSuccess;
}

@property(nonatomic, copy) NSString *bucket;
@end


@implementation UPMutUploaderManager

- (instancetype)initWithBucket:(NSString *)bucket {
    if (self = [super init]) {
        self.bucket = bucket;
        _remainingFileBlockIndexs = [[NSMutableArray alloc]init];
        _progressArray = [[NSMutableArray alloc]init];
    }
    return self;
}

+ (instancetype)managerWithBucket:(NSString *)bucket {
    if (!managerRepository) {
        managerRepository = [[NSMutableDictionary alloc] init];
    }
    bucket = [self formatBucket:bucket];
    if (!managerRepository[bucket]) {
        UPMutUploaderManager *manager = [[self alloc] initWithBucket:bucket];
        managerRepository[bucket] = manager;
    }
    return managerRepository[bucket];
}

#pragma mark - Setup Methods

+ (void)setValidTimeSpan:(NSInteger)validTimeSpan {
    ValidTimeSpan = validTimeSpan;
}

+ (void)setServer:(NSString *)server {
    API_SERVER = server;
}

+ (void)setMaxRetryCount:(NSInteger)retryCount {
    MaxRetryCount = retryCount;
}

#pragma mark - Public Methods

+ (void)cancelAllOperations {
//    for (NSString * key in managerRepository.allKeys) {
        //todo
        #pragma mark -todo
//        UPMutUploaderManager *manager = managerRepository[key];
//    }
}


+ (NSDictionary *)fetchFileInfoDictionaryWith:(NSData *)fileData {
    NSInteger blockCount = [self calculateBlockCount:fileData.length];
    NSDictionary * parameters = @{@"file_blocks":@(blockCount),
                                  @"file_hash":[fileData MD5HexDigest],
                                  @"file_size":@(fileData.length)};
    return parameters;
}

+ (NSDictionary *)fetchFileInfoDictionaryWithFilePath:(NSString *)filePath {
    NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    NSUInteger fileSize = [fileDictionary fileSize];
    NSInteger blockCount = [self calculateBlockCount:fileSize];
    NSDictionary * parameters = @{@"file_blocks":@(blockCount),
                                  @"file_hash":[filePath FilePathMD5],
                                  @"file_size":@(fileSize)};
    return parameters;
}


#pragma mark--------uploadBlock

- (void)uploadWithFile:(NSData *)fileData
                        OrFilePath:(NSString *)filePath
                            policy:(NSString *)policy
                         signature:(NSString *)signature
                     progressBlock:(UPProGgressBlock)progressBlock
                     completeBlock:(UPCompeleteBlock)completeBlock {
    
    if (filePath) {
        [self uploadWithFilePath:filePath policy:policy signature:signature progressBlock:progressBlock completeBlock:completeBlock];
    } else if (fileData) {
        [self uploadWithFileData:fileData policy:policy signature:signature progressBlock:progressBlock completeBlock:completeBlock];
    }
}

- (void)uploadWithFileData:(NSData *)fileData
                                  policy:(NSString *)policy
                               signature:(NSString *)signature
                           progressBlock:(UPProGgressBlock)progressBlock
                           completeBlock:(UPCompeleteBlock)completeBlock {
    
    NSArray *blocks = [UPMutUploaderManager subDatasWithFileData:fileData];
    
    UPCompeleteBlock prepareUploadCompletedBlock = ^(NSError *error, NSDictionary *result, BOOL completed) {
        if (error) {
            completeBlock(error, nil, NO);
        } else {
            if ([result isKindOfClass:[NSData class]]){
                NSData *data = (NSData*)result;
                result =  [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
            }
            _saveToken = result[@"save_token"];
            _filesStatus = result[@"status"];
            _tokenSecret = result[@"token_secret"];
            
            if (!_saveToken) {
                NSString *errorString = [NSString stringWithFormat:@"返回参数错误: saveToken is %@", _saveToken];
                NSError* errorInfo = [NSError errorWithDomain:UPMut_ERROR_DOMAIN code:-1999 userInfo:@{@"message":errorString}];
                completeBlock(errorInfo, nil, NO);
                return;
            }
            
            for (int i=0; i<_filesStatus.count; i++) {
                [_progressArray addObject:_filesStatus[i]];
                if (![_filesStatus[i] boolValue]) {
                    [_remainingFileBlockIndexs addObject:@(i)];
                }
            }
            
            for (int i = 0; i<MaxConcurrentOperationCount; i++) {
                [self uploadBlockIndex:i fileData:blocks progressBlock:progressBlock completeBlock:completeBlock];
            }
        }
    };
    [self prepareUploadRequestWithPolicy:policy
                               signature:signature
                              retryCount:0
                           completeBlock:prepareUploadCompletedBlock];
    
}



- (void)uploadWithFilePath:(NSString *)filePath
                            policy:(NSString *)policy
                         signature:(NSString *)signature
                     progressBlock:(UPProGgressBlock)progressBlock
                     completeBlock:(UPCompeleteBlock)completeBlock {
    
    UPCompeleteBlock prepareUploadCompletedBlock = ^(NSError *error, NSDictionary *result, BOOL completed) {
        if (error) {
            completeBlock(error, nil, NO);
        } else {
            if ([result isKindOfClass:[NSData class]]){
                NSData *data = (NSData*)result;
                result =  [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
            }
            _saveToken = result[@"save_token"];
            _filesStatus = result[@"status"];
            _tokenSecret = result[@"token_secret"];
            
            if (!_saveToken) {
                NSString *errorString = [NSString stringWithFormat:@"返回参数错误: saveToken is %@", _saveToken];
                NSError* errorInfo = [NSError errorWithDomain:UPMut_ERROR_DOMAIN code:-1999 userInfo:@{@"message":errorString}];
                completeBlock(errorInfo, nil, NO);
                return;
            }
            
            for (int i=0; i<_filesStatus.count; i++) {
                [_progressArray addObject:_filesStatus[i]];
                if (![_filesStatus[i] boolValue]) {
                    [_remainingFileBlockIndexs addObject:@(i)];
                }
            }
            
            for (int i = 0; i<MaxConcurrentOperationCount; i++) {
                [self uploadBlockIndex:i filePath:filePath progressBlock:progressBlock completeBlock:completeBlock];
            }
        }
    };
    [self prepareUploadRequestWithPolicy:policy
                               signature:signature
                              retryCount:0
                           completeBlock:prepareUploadCompletedBlock];
    
}

#pragma mark --

- (void)uploadBlockIndex:(NSInteger)index filePath:(NSString *)filePath progressBlock:(UPProGgressBlock)progressBlock
           completeBlock:(UPCompeleteBlock)completeBlock {
    if (index >= _progressArray.count) {
        return;
    }
    __weak typeof(self)weakSelf = self;
    
    id singleUploadProgressBlcok = ^(float percent) {
        @synchronized(_progressArray) {
                _progressArray[index] = [NSNumber numberWithFloat:percent];
                float sumPercent = 0;
                for (NSNumber *num in _progressArray) {
                    sumPercent += [num floatValue];
                }
                float totalPercent = sumPercent/_progressArray.count;
                progressBlock(totalPercent, 100);
        }
    };
    
    
    UPCompeleteBlock singleUploadCompleteBlock = ^(NSError *error, NSDictionary *result, BOOL completed) {
        
        if (!completed) {
            if (completeBlock) {
                completeBlock(error, nil, NO);
            }
            return;
        }
        if (completed) {
            _blockSuccess++;
        } else {
            _blockFailed++;
        }
        
        if (_blockFailed < 1 && _blockSuccess == _remainingFileBlockIndexs.count) {
            UPCompeleteBlock mergeRequestCompleteBlcok = ^(NSError *error, NSDictionary *result, BOOL completed) {
                completeBlock(error, result, completed);
            };
            [weakSelf fileMergeRequestWithSaveToken:_saveToken
                                    tokenSecret:_tokenSecret
                                     retryCount:0
                                  completeBlock:mergeRequestCompleteBlcok];
        } else {
            [weakSelf uploadBlockIndex:index+MaxConcurrentOperationCount filePath:filePath progressBlock:progressBlock completeBlock:completeBlock];
        }
    };
    
    [self uploadFileBlockWithSaveToken:_saveToken
                                blockIndex:index
                             fileBlockData:[UPMutUploaderManager getBlockWithFilePath:filePath offset:index]
                                retryTimes:0
                               tokenSecret:_tokenSecret
                             progressBlock:singleUploadProgressBlcok
                             completeBlock:singleUploadCompleteBlock];
    
}

- (void)uploadBlockIndex:(NSInteger)index fileData:(NSArray *)filedataArray progressBlock:(UPProGgressBlock)progressBlock
           completeBlock:(UPCompeleteBlock)completeBlock {
    if (index >= _progressArray.count) {
        return;
    }
    
    if (index >= filedataArray.count) {
        return;
    }
    
    NSData *blockData = filedataArray[index];
    
    __weak typeof(self)weakSelf = self;
    
    id singleUploadProgressBlcok = ^(float percent) {
        @synchronized(_progressArray) {
//            dispatch_async(dispatch_get_main_queue(), ^() {
            
                _progressArray[index] = [NSNumber numberWithFloat:percent];
                float sumPercent = 0;
                for (NSNumber *num in _progressArray) {
                    sumPercent += [num floatValue];
                }
                float totalPercent = sumPercent/_progressArray.count;
                progressBlock(totalPercent, 100);
//            });
        }
    };
    
    
    UPCompeleteBlock singleUploadCompleteBlock = ^(NSError *error, NSDictionary *result, BOOL completed) {
        
        if (!completed) {
            if (completeBlock) {
                completeBlock(error, nil, NO);
            }
            return;
        }
        if (completed) {
            _blockSuccess++;
        } else {
            _blockFailed++;
        }
        
        if (_blockFailed < 1 && _blockSuccess == _remainingFileBlockIndexs.count) {
            UPCompeleteBlock mergeRequestCompleteBlcok = ^(NSError *error, NSDictionary *result, BOOL completed) {
                completeBlock(error, result, completed);
            };
            [weakSelf fileMergeRequestWithSaveToken:_saveToken
                                        tokenSecret:_tokenSecret
                                         retryCount:0
                                      completeBlock:mergeRequestCompleteBlcok];
        } else {
            [weakSelf uploadBlockIndex:index+MaxConcurrentOperationCount fileData:filedataArray progressBlock:progressBlock completeBlock:completeBlock];
        }
    };
    [self uploadFileBlockWithSaveToken:_saveToken
                            blockIndex:index
                         fileBlockData:blockData
                            retryTimes:0
                           tokenSecret:_tokenSecret
                         progressBlock:singleUploadProgressBlcok
                         completeBlock:singleUploadCompleteBlock];
    
}
#pragma mark - Private Methods

- (void)prepareUploadRequestWithPolicy:(NSString *)policy
                             signature:(NSString *)signature
                            retryCount:(NSInteger)retryCount
                         completeBlock:(UPCompeleteBlock)completeBlock {
    __block typeof(retryCount)blockRetryCount = retryCount;
    __weak typeof(self)weakSelf = self;
    [self ministrantRequestWithSignature:signature
                                  policy:policy
                           completeBlock:^(NSError *error,
                                           NSDictionary *result,
                                           BOOL completed) {
          if (completed) {
              completeBlock(error,result,completed);
          }else if(retryCount >= MaxRetryCount) {
              completeBlock(error, nil, NO);
          }else {
              blockRetryCount++;
              [weakSelf prepareUploadRequestWithPolicy:policy
                                             signature:signature
                                            retryCount:blockRetryCount
                                         completeBlock:completeBlock];
          }
     }];
}

- (void)uploadFileBlockWithSaveToken:(NSString *)saveToken
                          blockIndex:(NSInteger)blockIndex
                       fileBlockData:(NSData *)fileBlockData
                          retryTimes:(NSInteger)retryTimes
                         tokenSecret:(NSString *)tokenSecret
                       progressBlock:(void (^)(float percent))progressBlock
                       completeBlock:(UPCompeleteBlock)completeBlock {
    NSDictionary * policyParameters = @{@"save_token":saveToken,
                                        @"expiration":@(ceil([[NSDate date] timeIntervalSince1970]+ValidTimeSpan)),
                                        @"block_index":@(blockIndex),
                                        @"block_hash":[fileBlockData MD5HexDigest]};
    NSString * uploadPolicy = [self dictionaryToJSONStringBase64Encoding:policyParameters];
    __weak typeof(self)weakSelf = self;
    NSDictionary * parameters = @{@"policy":uploadPolicy,
                                  @"signature":[weakSelf createSignatureWithToken:tokenSecret
                                                                       parameters:policyParameters]};
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", API_SERVER, self.bucket]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url.absoluteString]];
    
    
    
    UPMultipartBody *multiBody = [[UPMultipartBody alloc]init];
    [multiBody addDictionary:parameters];
    [multiBody addFileData:fileBlockData fileName:@"file" fileType:nil];
    //设置URLRequest
    request.HTTPMethod = @"POST";
    request.HTTPBody = [multiBody dataFromPart];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", multiBody.boundary] forHTTPHeaderField:@"Content-Type"];
    
    UPHTTPClient *upHttpClient =  [[UPHTTPClient alloc] init];
    
    [upHttpClient uploadRequest:request success:^(NSURLResponse *response, id responseObject) {
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseObject
                                                             options:kNilOptions
                                                               error:&error];
        if (error) {
            NSLog(@"error %@", error);
            completeBlock(error, nil, NO);
        } else {
            completeBlock(error, json, YES);
        }
    } failure:^(NSError *error) {
        completeBlock(error, nil, NO);
    } progress:^(int64_t completedBytesCount, int64_t totalBytesCount) {
        @synchronized(self) {
            float k = (float)completedBytesCount / totalBytesCount;
            if (progressBlock) {
                progressBlock(k);
            }
        }
    }];
}


- (void)fileMergeRequestWithSaveToken:(NSString *)saveToken
                          tokenSecret:(NSString *)tokenSecret
                           retryCount:(NSInteger)retryCount
                        completeBlock:(void (^)(NSError * error,
                                                NSDictionary * result,
                                                BOOL completed))completeBlock
{
    __weak typeof(self)weakSelf = self;
    __block typeof(retryCount)blockRetryCount = retryCount;
    NSDictionary * parameters = @{@"save_token":saveToken,
                                  @"expiration":@(ceil([[NSDate date] timeIntervalSince1970]+60))};
    NSString * mergePolicy = [self dictionaryToJSONStringBase64Encoding:parameters];
    [self ministrantRequestWithSignature:[self createSignatureWithToken:tokenSecret
                                                             parameters:parameters]
                                  policy:mergePolicy
                           completeBlock:^(NSError *error, NSDictionary *result, BOOL completed) {
        if (completed) {
            completeBlock(error,result,completed);
        } else if(retryCount >= MaxRetryCount) {
            completeBlock(error, nil, NO);
        } else {
            blockRetryCount++;
            [weakSelf fileMergeRequestWithSaveToken:saveToken
                                        tokenSecret:tokenSecret
                                         retryCount:blockRetryCount
                                      completeBlock:completeBlock];
        }
     }];
}

- (void)ministrantRequestWithSignature:(NSString *)signature
                                policy:(NSString *)policy
                         completeBlock:(void (^)(NSError * error,
                                                 NSDictionary * result,
                                                 BOOL completed))completeBlock {

    NSDictionary *requestParameters = @{@"policy":policy,
                                         @"signature":signature};
    NSURLSession *session = [NSURLSession sharedSession];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", API_SERVER, self.bucket]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSMutableString *postParameters = [[NSMutableString alloc] init];
    for (NSString *key in requestParameters.allKeys) {
        NSString *keyValue = [NSString stringWithFormat:@"&%@=%@", key, requestParameters[key]];
        [postParameters appendString:keyValue];
    }
    if (postParameters.length > 1) {
        request.HTTPBody = [[postParameters substringFromIndex:1] dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        NSString *errorInfo = [NSString stringWithFormat:@"传入参数类型错误: Signature is %@, policy is %@", signature, policy];
        NSError *error = [NSError errorWithDomain:UPMut_ERROR_DOMAIN
                                             code:-1999
                                         userInfo:@{@"message":errorInfo}];
        
        completeBlock(error, nil, NO);
    }
    
    NSURLSessionTask *sessionTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data,
                                                                    NSURLResponse *response,
                                                                    NSError *error) {
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse *)response;
        if (error) {
            completeBlock(error, nil, NO);
        } else {
            //判断返回状态码错误。
            NSInteger statusCode = httpResponse.statusCode;
            NSIndexSet *succesStatus = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
            if ([succesStatus containsIndex:statusCode]) {
                NSError *error;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
                if (json == nil) {
                    completeBlock(error, nil, NO);
                } else {
                    completeBlock(nil, json, YES);
                }
            } else {
                NSString *errorString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSError *erro = [[NSError alloc] initWithDomain:UPMut_ERROR_DOMAIN
                                                           code:-1998
                                                       userInfo:@{NSLocalizedDescriptionKey:errorString}];
                completeBlock(erro, nil, NO);
            }
        }
    }];
    [sessionTask resume];
}


#pragma mark - Utils

- (NSError *)checkResultWithResponseObject:(NSDictionary *)responseObject
                                  response:(NSHTTPURLResponse*)response
{
    if ([responseObject isKindOfClass:[NSData class]]){
        NSData *data = (NSData*)responseObject;
        responseObject =  [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    }

    if (responseObject[@"error_code"]) {
        NSMutableDictionary * userInfo = [NSMutableDictionary dictionary];
        if (response.allHeaderFields) {
            userInfo[@"allHeaderFields"] = response.allHeaderFields;
            userInfo[@"statusCode"] = @(response.statusCode);
        }
        userInfo[NSLocalizedDescriptionKey] = responseObject[@"message"];
        NSError *error = [NSError errorWithDomain:UPMut_ERROR_DOMAIN
                                              code:[responseObject[@"error_code"] integerValue]
                                          userInfo:userInfo];
        return error;
    }
    return nil;
}


//计算文件块数
+ (NSInteger)calculateBlockCount:(NSUInteger)fileLength {
    return ceil(fileLength*1.0/SingleBlockSize);
}

//生成单个文件块
+ (NSData *)getBlockWithFilePath:(NSString *)filePath offset:(NSInteger)index {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSInteger startLocation = index * SingleBlockSize;
    [handle seekToFileOffset:startLocation];
    NSData *subData = [handle readDataOfLength:SingleBlockSize];
    [handle closeFile];
    return [subData copy];
}

//生成文件块
+ (NSArray *)subDatasWithFileData:(NSData *)fileData {
    NSInteger blockCount = [self calculateBlockCount:fileData.length];
    NSMutableArray * blocks = [[NSMutableArray alloc]init];
    for (int i = 0; i < blockCount;i++ ) {
        NSInteger startLocation = i*SingleBlockSize;
        NSInteger length = SingleBlockSize;
        if (startLocation+length > fileData.length) {
            length = fileData.length-startLocation;
        }
        NSData * subData = [fileData subdataWithRange:NSMakeRange(startLocation, length)];
        [blocks addObject:subData];
    }
    return [blocks mutableCopy];
}

//根据token 计算签名
- (NSString *)createSignatureWithToken:(NSString *)token
                            parameters:(NSDictionary *)parameters
{
    NSString *signature = @"";
    NSArray *keys = [parameters allKeys];
    keys= [keys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString * key in keys) {
        NSString * value = parameters[key];
        signature = [NSString stringWithFormat:@"%@%@%@", signature, key, value];
    }
    signature = [signature stringByAppendingString:token];
    return [signature MD5];
}

- (NSString *)dictionaryToJSONStringBase64Encoding:(NSDictionary *)dic
{
    id paramesData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:paramesData
                                                 encoding:NSUTF8StringEncoding];
    return [jsonString Base64encode];
}

+ (NSString *)formatBucket:(NSString *)bucket
{
    if(![bucket hasSuffix:@"/"]) {
        bucket = [bucket stringByAppendingString:@"/"];
    }
    return bucket;
}

@end
