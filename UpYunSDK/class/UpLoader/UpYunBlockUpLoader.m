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
    int _fileSize;
    NSDictionary *_fileInfos;
    NSArray *_blockArray;
    dispatch_queue_t _uploaderQueue;
    
    UpSimpleHttpClient *_httpClient;
    BOOL _cancelled;
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
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"UpYunBlockUpLoader task cancelled"};
            NSError * error  = [[NSError alloc] initWithDomain:NSErrorDomain_UpYunBlockUpLoader
                                                          code: 0
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

- (void)uploadWithBucketName:(NSString *)bucketName
                    operator:(NSString *)operatorName
                    password:(NSString *)operatorPassword
                        file:(NSString *)filePath
                    savePath:(NSString *)savePath
                     success:(UpLoaderSuccessBlock)successBlock
                     failure:(UpLoaderFailureBlock)failureBlock
                    progress:(UpLoaderProgressBlock)progressBlock {
    if (_uploaderQueue) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"UpYunBlockUpLoader instance is unavailable"};
        NSError * error  = [[NSError alloc] initWithDomain:NSErrorDomain_UpYunBlockUpLoader
                                                      code: 0
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
            _bucketName = bucketName;
            _operatorName = operatorName;
            _operatorPassword = operatorPassword;
            _filePath = filePath;
            _savePath = savePath;
            _successBlock = successBlock;
            _failureBlock = failureBlock;
            _progressBlock = progressBlock;
            _fileInfos = [self fileBlocksInfo:filePath];
            _blockArray = [_fileInfos objectForKey:@"blocks"];
            [self initiate];
        }
    });
}


//分块上传步骤1: 初始化
- (void)initiate {
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
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
                  
                  NSLog(@"resHeaders %@", resHeaders);
                  
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
                          [self uploadFileBlockId:_next_part_id];
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
- (void)uploadFileBlockId:(int)part_id {
    if (part_id >= _blockArray.count || part_id < 0) {
        [self complete];
        return;
    }
    
    NSDictionary *targetBlcokInfo = [_blockArray objectAtIndex:part_id];
    NSRange range = [(NSValue *)[targetBlcokInfo objectForKey:@"block_range"] rangeValue];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:_filePath];
    [fileHandle seekToFileOffset:range.location];
    NSData *blockData = [fileHandle readDataOfLength:range.length];
    
    NSString *Content_MD5 =  [targetBlcokInfo objectForKey:@"block_hash"];
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
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
    _httpClient = [UpSimpleHttpClient PUT:urlString
                    headers:headers
                       file:blockData
          sendProgressBlock:^(NSProgress *progress) {
              
          }
          completionHandler:^(NSError *error, id response, NSData *body) {
              NSHTTPURLResponse *res = response;
              if (res.statusCode == 204) {
                  NSDictionary *resHeaders = res.allHeaderFields;
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
                          [self uploadFileBlockId:_next_part_id];
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

//分块上传步骤3: 结束上传，合并文件
- (void)complete {
    
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
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
                              @"X-Upyun-Multi-MD5": [UpApiUtils getMD5HashOfFileAtPath:_filePath]};
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
              if (res.statusCode == 204 || res.statusCode == 201) {
                  
                  if (_progressBlock) {
                      _progressBlock(_fileSize, _fileSize);

                  }
                  if (_successBlock) {
                      _successBlock(response, retObj);
                  }
                  
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
            NSValue *rangeValue = [NSValue valueWithRange:blockRang];
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
            [fileHandle seekToFileOffset:loc];
            NSData *fileData = [fileHandle readDataOfLength:len];
            NSString *fileDataHash = [UpApiUtils getMD5HashFromData:fileData];
            
            NSDictionary *block = @{@"block_index":[NSString stringWithFormat:@"%u", i],
                                    @"block_range":rangeValue,
                                    @"block_hash":fileDataHash};
            
            [blocks addObject:block];
        }
    }
    
    [fileInfo setValue:blocks forKey:@"blocks"];
    return fileInfo;

}

- (void)dealloc {
    NSLog(@"dealloc %@", self);
}

@end
