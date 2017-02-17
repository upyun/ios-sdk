//
//  UpYunBlockUpLoader.m
//  UpYunSDKDemo
//
//  Created by DING FENG on 2/16/17.
//  Copyright © 2017 upyun. All rights reserved.
//

#import "UpYunBlockUpLoader.h"
#import "UpSimpleHttpClient.h"

#define  NSErrorDomain_UpYunBlockUpLoader   @"NSErrorDomain_UpYunBlockUpLoader"
#define  kUpYunBlockUpLoaderTasksRecords  @"kUpYunBlockUpLoaderTasksRecords"

@interface UpYunBlockUpLoader()
{
    NSString *_bucketName;
    NSString *_operatorName;
    NSString *_operatorPassword;
    NSString *_filePath;
    NSString *_savePath;
    UpLoaderSuccessBlock _successBlock;
    UpLoaderFailureBlock _failureBlock;
    UpLoaderProgressBlock _progressBlock;
    int _next_part_id;
    NSString *_X_Upyun_Multi_Uuid;
    NSDate *_initDate;
    int _fileSize;
    NSDictionary *_fileInfos;
    dispatch_queue_t _uploaderQueue;
    UpSimpleHttpClient *_httpClient;
    BOOL _cancelled;
    NSString *_uploaderIdentityString;//一次上传文件的特征值。特征值相同，上传成功后的结果相同（文件内容和保存路径)。
    NSMutableDictionary *_uploaderTaskInfo;//当前的上传任务。（目的是断点续传，所以仅仅纪录保存 upload 阶段的状态）
}

@end


@implementation UpYunBlockUpLoader

- (void)cancel {
    [_httpClient cancel];
    dispatch_async(_uploaderQueue, ^(){
        _cancelled = YES;
    });
}

- (void)canceledEnd {
    dispatch_async(_uploaderQueue, ^(){
        if (_failureBlock) {
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"UpYunBlockUpLoader task cancelled"};
            NSError * error  = [[NSError alloc] initWithDomain:NSErrorDomain_UpYunBlockUpLoader
                                                          code: -101
                                                      userInfo: userInfo];
            _failureBlock(error, nil, nil);
        }
        [self clean];
    });
}

- (void)clean {
    _successBlock = nil;
    _failureBlock = nil;
    _progressBlock = nil;
}

//判断是否可以续传
- (BOOL)checkUploadStatus {
    NSDictionary *uploaderTaskInfo_saved = [self getUploaderTaskInfoFromFile];
    if (!uploaderTaskInfo_saved) {
        uploaderTaskInfo_saved = [NSDictionary new];
    }
    _uploaderTaskInfo = [[NSMutableDictionary alloc] initWithDictionary:uploaderTaskInfo_saved];
    BOOL statusIsUploading = NO;
    if (_uploaderTaskInfo) {
        //分块上传阶段的失败或者取消。
        statusIsUploading = [[_uploaderTaskInfo objectForKey:@"statusIsUploading"] boolValue];
        int next_part_id  = [[_uploaderTaskInfo objectForKey:@"_next_part_id"]  intValue];
        int timestamp_save  = [[_uploaderTaskInfo objectForKey:@"timestamp"]  intValue];
        int timePast = [[NSDate date] timeIntervalSince1970] - timestamp_save;
        if (next_part_id == 0) {
            statusIsUploading = NO;
        }
        
        if (timestamp_save > 0 && timePast >= 86400) {
            NSLog(@"已上传分块，最长保存时间是 24 小时。您的分块已经过期，无法进行续传，现在进行重新上传");
            statusIsUploading = NO;
        }
    }
//    NSLog(@"_uploaderTaskInfo %@  %@", _uploaderTaskInfo, _uploaderIdentityString);
    return statusIsUploading;
}


- (void)uploadWithBucketName:(NSString *)bucketName
                    operator:(NSString *)operatorName
                    password:(NSString *)operatorPassword
                        file:(NSString *)filePath
                    savePath:(NSString *)savePath
                     success:(UpLoaderSuccessBlock)successBlock
                     failure:(UpLoaderFailureBlock)failureBlock
                    progress:(UpLoaderProgressBlock)progressBlock {
    
    _initDate = [NSDate date];
    _bucketName = bucketName;
    _operatorName = operatorName;
    _operatorPassword = operatorPassword;
    _filePath = filePath;
    _savePath = savePath;
    _successBlock = successBlock;
    _failureBlock = failureBlock;
    _progressBlock = progressBlock;
    _fileInfos = [self fileBlocksInfo:filePath];
    _uploaderIdentityString = [NSString stringWithFormat:@"bucketName=%@&operatorName=%@&savePath=%@&file=%@",
                               _bucketName,
                               _operatorName,
                               _savePath,
                               _fileInfos[@"fileHash"]];
//    NSLog(@"_uploaderIdentityString %@", _uploaderIdentityString);
    
    
    if (_uploaderQueue) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"UpYunBlockUpLoader instance is unavailable，please create a new one."};
        NSError * error  = [[NSError alloc] initWithDomain:NSErrorDomain_UpYunBlockUpLoader
                                                      code: -102
                                                  userInfo: userInfo];
        NSLog(@"error %@",error);
        failureBlock(error, nil, nil);
        return;
    }
    _uploaderQueue = dispatch_queue_create("UpYunBlockUpLoader.uploaderQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(_uploaderQueue, ^(){
        if (_cancelled) {
            [self canceledEnd];
        } else {
            if ([self checkUploadStatus]) {
                //断点续传
                [self uploadNextFileBlock];
            } else {
                [self initiate];
                //崭新的上传
            }
        }
    });
}

//分块上传步骤1: 初始化
- (void)initiate {
    
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [dateFormatter setLocale:usLocale];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
    NSString *date = [dateFormatter stringFromDate:now];
    NSDictionary *uploadParameters = @{@"bucket": _bucketName,
                                       @"savePath": _savePath,
                                       @"date": date};
    
    NSString *uri = [NSString stringWithFormat:@"/%@/%@", uploadParameters[@"bucket"], uploadParameters[@"savePath"]];
    NSString *signature = [UpApiUtils getSignatureWithPassword:_operatorPassword
                                                    parameters:@[@"PUT",
                                                                 uri,
                                                                 uploadParameters[@"date"]]];
    //http headers
    NSString *Authorization = [NSString stringWithFormat:@"UPYUN %@:%@", _operatorName, signature];
    NSString *Date = uploadParameters[@"date"];
    NSString *X_Upyun_Multi_Stage = @"initiate";
    NSString *X_Upyun_Multi_Length = [UpApiUtils lengthOfFileAtPath:_filePath];
    NSString *X_Upyun_Multi_Type = [UpApiUtils mimeTypeOfFileAtPath:_filePath];
    //暂时不支持 X-Upyun-Meta-X http://docs.upyun.com/api/rest_api/#metadata
    NSDictionary *headers = @{@"Authorization": Authorization,
                              @"Date": Date,
                              @"X-Upyun-Multi-Stage": X_Upyun_Multi_Stage,
                              @"X-Upyun-Multi-Length": X_Upyun_Multi_Length,
                              @"X-Upyun-Multi-Type": X_Upyun_Multi_Type};
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", UpYunStorageServer, uri];
    _httpClient = [UpSimpleHttpClient PUT:urlString
                                  headers:headers file:nil
                        sendProgressBlock:^(NSProgress *progress) {
                            
                        }
                        completionHandler:^(NSError *error, id response, NSData *body) {
                            NSHTTPURLResponse *res = response;
                            if (res.statusCode == 204) {
                                NSDictionary *resHeaders = res.allHeaderFields;
                                NSString *next_part_id = [resHeaders objectForKey:@"x-upyun-next-part-id"];
                                _next_part_id = [next_part_id intValue];
                                
                                if (_progressBlock) {
                                    int  completedNum = _next_part_id - 1;
                                    if (completedNum < 0 ) {
                                        completedNum = 0;
                                    }
                                    _progressBlock(completedNum, _fileSize);
                                }
                                
                                _X_Upyun_Multi_Uuid = [resHeaders objectForKey:@"x-upyun-multi-uuid"];
                                dispatch_async(_uploaderQueue, ^(){
                                    if (_cancelled) {
                                        [self canceledEnd];
                                    } else {
                                        [self updateUploaderTaskInfoWithCompleted:NO];
                                        [self uploadNextFileBlock];
                                    }
                                });
                                
                                
                            } else {
                                if (_failureBlock) {
                                    NSDictionary *retObj = nil;
                                    if (body) {
                                        //有返回 body ：尝试按照 json 解析。
                                        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:body options:kNilOptions error:&error];
                                        retObj = json;
                                    }
                                    _failureBlock(error, response, retObj);
                                    [self clean];
                                    
                                }
                            }
                        }];
}

//分块上传步骤2: 上传文件块


- (void)uploadNextFileBlock {
    //从_uploaderTaskInfo中，重新赋值成员变量。因为_uploaderTaskInfo也可能是从userdefault 获取的
    _fileInfos = [_uploaderTaskInfo objectForKey:@"_fileInfos"];
    _uploaderIdentityString = [_uploaderTaskInfo objectForKey:@"_uploaderIdentityString"];
    _X_Upyun_Multi_Uuid = [_uploaderTaskInfo objectForKey:@"_X_Upyun_Multi_Uuid"];
    _next_part_id = [[_uploaderTaskInfo objectForKey:@"_next_part_id"] intValue];
    
    int part_id = _next_part_id;
    NSArray *blockArray = [_fileInfos objectForKey:@"blocks"];
    if (part_id >= blockArray.count || part_id < 0) {
        [self complete];
        return;
    }
    
    NSDictionary *targetBlcokInfo = [blockArray objectAtIndex:part_id];
    NSString *rangeString = [targetBlcokInfo objectForKey:@"block_range"];
    NSRange range = NSRangeFromString(rangeString);
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:_filePath];
    [fileHandle seekToFileOffset:range.location];
    NSData *blockData = [fileHandle readDataOfLength:range.length];
    
    NSString *Content_MD5 =  [targetBlcokInfo objectForKey:@"block_hash"];
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [dateFormatter setLocale:usLocale];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
    NSString *date = [dateFormatter stringFromDate:now];
    NSDictionary *uploadParameters = @{@"bucket": _bucketName,
                                       @"savePath": _savePath,
                                       @"date": date, @"Content-MD5": Content_MD5};
    
    NSString *uri = [NSString stringWithFormat:@"/%@/%@", uploadParameters[@"bucket"], uploadParameters[@"savePath"]];
    NSString *signature = [UpApiUtils getSignatureWithPassword:_operatorPassword
                                                    parameters:@[@"PUT",
                                                                 uri,
                                                                 uploadParameters[@"date"],
                                                                 uploadParameters[@"Content-MD5"]]];
    //http headers
    NSString *Authorization = [NSString stringWithFormat:@"UPYUN %@:%@", _operatorName, signature];
    NSString *Date = uploadParameters[@"date"];
    NSString *X_Upyun_Multi_Stage = @"upload";
    //暂时不支持 X-Upyun-Meta-X http://docs.upyun.com/api/rest_api/#metadata
    NSDictionary *headers = @{@"Authorization": Authorization,
                              @"Date": Date,
                              @"X-Upyun-Multi-Stage": X_Upyun_Multi_Stage,
                              @"X-Upyun-Multi-Uuid": _X_Upyun_Multi_Uuid,
                              @"X-Upyun-Part-Id": [NSString stringWithFormat:@"%d", part_id],
                              @"Content-MD5": Content_MD5};
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", UpYunStorageServer, uri];
    
    
//    NSLog(@"request headers %@", headers);
    _httpClient = [UpSimpleHttpClient PUT:urlString
                                  headers:headers
                                     file:blockData
                        sendProgressBlock:^(NSProgress *progress) {
                            
                        }
                        completionHandler:^(NSError *error, id response, NSData *body) {
                            NSHTTPURLResponse *res = response;
                            NSDictionary *resHeaders = res.allHeaderFields;


                            if (res.statusCode == 204) {
                                if (_progressBlock) {
                                    _progressBlock(_next_part_id * UpYunFileBlcokSize, _fileSize);
                                }
                                NSString *next_part_id = [resHeaders objectForKey:@"x-upyun-next-part-id"];
                                _next_part_id = [next_part_id intValue];
                                _X_Upyun_Multi_Uuid = [resHeaders objectForKey:@"x-upyun-multi-uuid"];
                                dispatch_async(_uploaderQueue, ^(){
                                    if (_cancelled) {
                                        [self canceledEnd];
                                    } else {
                                        [self updateUploaderTaskInfoWithCompleted:NO];
                                        [self uploadNextFileBlock];
                                    }
                                });
                                
                            } else {
                                NSDictionary *retObj = nil;
                                if (body) {
                                    //有返回 body ：尝试按照 json 解析。
                                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:body options:kNilOptions error:&error];
                                    retObj = json;
                                }
//                                NSLog(@"retObj %@", retObj);
//                                NSLog(@"response %@", response);
                                if ([[retObj objectForKey:@"code"] intValue] == 40011059) {
                                    //msg = "file already upload";
                                    //当文件已经成功了
                                    _next_part_id = -1;
                                    [self updateUploaderTaskInfoWithCompleted:NO];
                                    [self uploadNextFileBlock];
                                    return ;
                                }
                                
                                
                                if ([resHeaders.allKeys containsObject:@"x-upyun-next-part-id"]) {
                                    NSString *next_part_id = [resHeaders objectForKey:@"x-upyun-next-part-id"];
                                    _next_part_id = [next_part_id intValue];
                                    dispatch_async(_uploaderQueue, ^(){
                                        if (_cancelled) {
                                            [self canceledEnd];
                                        } else {
                                            [self updateUploaderTaskInfoWithCompleted:NO];
                                            [self uploadNextFileBlock];
                                        }
                                    });
                                    return;
                                }
                                if (_failureBlock) {
                                    _failureBlock(error, response, retObj);
                                    [self clean];
                                    
                                }
                            }
                        }];
    
    

}
//分块上传步骤3: 结束上传，合并文件
- (void)complete {
    
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [dateFormatter setLocale:usLocale];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [dateFormatter setDateFormat:@"EEE, dd MMM y HH:mm:ss zzz"];
    NSString *date = [dateFormatter stringFromDate:now];
    NSDictionary *uploadParameters = @{@"bucket": _bucketName,
                                       @"savePath": _savePath,
                                       @"date": date};
    
    NSString *uri = [NSString stringWithFormat:@"/%@/%@", uploadParameters[@"bucket"], uploadParameters[@"savePath"]];
    NSString *signature = [UpApiUtils getSignatureWithPassword:_operatorPassword
                                                    parameters:@[@"PUT",
                                                                 uri,
                                                                 uploadParameters[@"date"]]];
    //http headers
    NSString *Authorization = [NSString stringWithFormat:@"UPYUN %@:%@", _operatorName, signature];
    NSString *Date = uploadParameters[@"date"];
    NSString *X_Upyun_Multi_Stage = @"complete";
    
    NSDictionary *headers = @{@"Authorization": Authorization,
                              @"Date": Date,
                              @"X-Upyun-Multi-Stage": X_Upyun_Multi_Stage,
                              @"X-Upyun-Multi-Uuid": _X_Upyun_Multi_Uuid,
                              @"X-Upyun-Multi-MD5": [_fileInfos objectForKey:@"fileHash"]};
    NSString *urlString = [NSString stringWithFormat:@"%@%@", UpYunStorageServer, uri];
    _httpClient = [UpSimpleHttpClient PUT:urlString
                                  headers:headers
                                     file:nil
                        sendProgressBlock:^(NSProgress *progress) {
                        }
                        completionHandler:^(NSError *error, id response, NSData *body) {
                            NSDictionary *retObj = nil;
                            if (body) {
                                //有返回 body ：尝试按照 json 解析。
                                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:body options:kNilOptions error:&error];
                                retObj = json;
                            }
                            NSHTTPURLResponse *res = response;
                            if (res.statusCode == 204 ||
                                res.statusCode == 201 ||
                                [[retObj objectForKey:@"code"] intValue] == 40011059) {
                                
                                if (_progressBlock) {
                                    _progressBlock(_fileSize, _fileSize);
                                    
                                }
                                if (_successBlock) {
                                    _successBlock(response, retObj);
                                }
                                [self updateUploaderTaskInfoWithCompleted:YES];
                            } else {
                                if (_failureBlock) {
                                    _failureBlock(error, response, retObj);
                                }
                            }
                            [self clean];
                        }];
}

//预处理获取文件信息，文件分块记录
- (NSDictionary *)fileBlocksInfo:(NSString *)filePath {
    _fileSize = [[UpApiUtils lengthOfFileAtPath:_filePath] intValue];
    NSMutableDictionary *fileInfo = [[NSMutableDictionary alloc] init];
    [fileInfo setValue:[NSString stringWithFormat:@"%d",_fileSize] forKey:@"fileSize"];
    NSInteger blockCount = _fileSize / UpYunFileBlcokSize;
    NSInteger blockRemainder = _fileSize % UpYunFileBlcokSize;
    
    if (blockRemainder > 0) {
        blockCount = blockCount + 1;
    }
    
    NSMutableArray *blocks = [[NSMutableArray alloc] init];
    for (UInt32 i = 0; i < blockCount; i++) {
        @autoreleasepool {
            UInt32 loc = i * UpYunFileBlcokSize;
            UInt32 len = UpYunFileBlcokSize;
            if (i == blockCount - 1) {
                len = (UInt32)_fileSize - loc;
            }
            NSRange blockRang = NSMakeRange(loc, len);
            NSString *rangeString = NSStringFromRange(blockRang);
            
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
            [fileHandle seekToFileOffset:loc];
            NSData *fileData = [fileHandle readDataOfLength:len];
            NSString *fileDataHash = [UpApiUtils getMD5HashFromData:fileData];
            
            NSDictionary *block = @{@"block_index":[NSString stringWithFormat:@"%u", i],
                                    @"block_range":rangeString,
                                    @"block_hash":fileDataHash};
            [blocks addObject:block];
        }
    }
    
    [fileInfo setValue:blocks forKey:@"blocks"];
    NSString *fileHash = [UpApiUtils getMD5HashOfFileAtPath:_filePath];
    [fileInfo setValue:fileHash forKey:@"fileHash"];
    
    return fileInfo;
}

- (void)dealloc {
    //    NSLog(@"dealloc %@", self);
}

- (NSDictionary *)getUploaderTaskInfoFromFile {
    NSString *tmpDirectory = NSTemporaryDirectory();
    NSString *upYunUploaderTaskInfoDirectory = [tmpDirectory stringByAppendingPathComponent:@"/upYunUploaderTaskInfo/"];
    NSString *hash =  [UpApiUtils getMD5HashFromData:[NSData dataWithBytes:_uploaderIdentityString.UTF8String length:_uploaderIdentityString.length]];
    
    NSString *filename = [NSString stringWithFormat:@"%@.info", hash];
    NSString *filePath = [upYunUploaderTaskInfoDirectory stringByAppendingPathComponent:filename];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    NSDictionary *dict = nil;
    if (data) {
        dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];

    }
    return  dict;
}

- (void)updateUploaderTaskInfoWithCompleted:(BOOL)completedSuccess {
    NSString *tmpDirectory = NSTemporaryDirectory();
    NSString *upYunUploaderTaskInfoDirectory = [tmpDirectory stringByAppendingPathComponent:@"/upYunUploaderTaskInfo/"];
    NSString *hash =  [UpApiUtils getMD5HashFromData:[NSData dataWithBytes:_uploaderIdentityString.UTF8String length:_uploaderIdentityString.length]];
                       
    NSString *filename = [NSString stringWithFormat:@"%@.info", hash];
    NSString *filePath = [upYunUploaderTaskInfoDirectory stringByAppendingPathComponent:filename];
    
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:upYunUploaderTaskInfoDirectory withIntermediateDirectories:NO attributes:nil error:nil];

    if (completedSuccess) {
        return;
    }
    
    //对正在进行上传终止的纪录，以便下次之行续传
    NSMutableDictionary *taskInfo = [NSMutableDictionary new];
    [taskInfo setObject:_fileInfos forKey:@"_fileInfos"];
    [taskInfo setObject:_uploaderIdentityString forKey:@"_uploaderIdentityString"];//也是外层map的key
    [taskInfo setObject:_X_Upyun_Multi_Uuid forKey:@"_X_Upyun_Multi_Uuid"];
    [taskInfo setObject:[NSNumber numberWithInt:_next_part_id] forKey:@"_next_part_id"];
    [taskInfo setObject:[NSNumber numberWithBool:YES] forKey:@"statusIsUploading"];
    int timestamp = [_initDate timeIntervalSince1970];
    [taskInfo setObject:[NSNumber numberWithInt:timestamp] forKey:@"timestamp"];
    _uploaderTaskInfo = taskInfo;
    NSDictionary *info = _uploaderTaskInfo;
    NSData *jsonData = nil;
    
    if ([NSJSONSerialization isValidJSONObject:info]) {
        jsonData = [NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingPrettyPrinted error:nil];
    }
    if (jsonData) {
        [[NSFileManager defaultManager]  createFileAtPath:filePath contents:jsonData attributes:nil];
    }
    
}

@end
