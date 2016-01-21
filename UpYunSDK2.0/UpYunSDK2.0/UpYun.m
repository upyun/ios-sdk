//
//  UpYun.m
//  UpYunSDK2.0
//
//  Created by jack zhou on 13-8-6.
//  Copyright (c) 2013年 upyun. All rights reserved.
//

#import "UpYun.h"
#import "UPMultipartBody.h"
#import "NSString+NSHash.h"



#define ERROR_DOMAIN @"upyun.com"
#define DATE_STRING(expiresIn) [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970] + expiresIn]
#define REQUEST_URL(bucket) [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/",API_DOMAIN,bucket]]

#define SUB_SAVE_KEY_FILENAME @"{filename}"

@implementation UpYun
-(id)init
{
    if (self = [super init]) {
        self.bucket = DEFAULT_BUCKET;
        self.expiresIn = DEFAULT_EXPIRES_IN;
        self.passcode = DEFAULT_PASSCODE;
	}
	return self;
}

- (void) uploadImage:(UIImage *)image savekey:(NSString *)savekey
{
    if (![self checkSavekey:savekey]) {
        return;
    }
    NSData *imageData = UIImagePNGRepresentation(image);
    [self uploadImageData:imageData savekey:savekey];
}

- (void) uploadImagePath:(NSString *)path savekey:(NSString *)savekey
{
    [self uploadFilePath:path savekey:savekey];
}

- (void) uploadImageData:(NSData *)data savekey:(NSString *)savekey
{
    if (![self checkSavekey:savekey]) {
        return;
    }
    [self uploadFileData:data savekey:savekey];
}

- (void) uploadFilePath:(NSString *)path savekey:(NSString *)savekey
{
    [self creatSessinTaskWithSaveKey:savekey data:nil filePath:path];
//    [task resume];
}

- (void) uploadFileData:(NSData *)data savekey:(NSString *)savekey
{
    [self creatSessinTaskWithSaveKey:savekey data:data filePath:nil];
//    [task resume];
}

- (BOOL)checkSavekey:(NSString *)string
{
    NSRange rangeFileName;
    NSRange rangeFileNameOnDic;
    rangeFileName = [string rangeOfString:SUB_SAVE_KEY_FILENAME];
    if ([_params objectForKey:@"save-key"]) {
        rangeFileNameOnDic = [[_params objectForKey:@"save-key"]
                              rangeOfString:SUB_SAVE_KEY_FILENAME];
    }else {
        rangeFileNameOnDic.location = NSNotFound;
    }
    
    
    if(rangeFileName.location != NSNotFound || rangeFileNameOnDic.location != NSNotFound)
    {
        NSString *  message = [NSString stringWithFormat:@"传入file为NSData或者UIImage时,不能使用%@方式生成savekey",
                               SUB_SAVE_KEY_FILENAME];
        NSError *err = [NSError errorWithDomain:ERROR_DOMAIN
                                           code:-1998
                                       userInfo:@{@"message":message}];
        if (_failBlocker) {
            _failBlocker(err);
        }
        return NO;
    }
    return YES;
}

- (void)uploadFile:(id)file saveKey:(NSString *)saveKey
{
    if (![file isKindOfClass:[NSString class]] && ![self checkSavekey:saveKey])//非path传入的需要检查savekey
    {
        return;
    }
    if([file isKindOfClass:[UIImage class]]){
        [self uploadImage:file savekey:saveKey];
    }else if([file isKindOfClass:[NSData class]]) {
        [self uploadFileData:file savekey:saveKey];
    }else if([file isKindOfClass:[NSString class]]) {
        [self uploadFilePath:file savekey:saveKey];
    }else {
        NSError *err = [NSError errorWithDomain:ERROR_DOMAIN
                                           code:-1999
                                       userInfo:@{@"message":@"传入参数类型错误"}];
        if (_failBlocker) {
            _failBlocker(err);
        }
    }
}

- (NSString *)getPolicyWithSaveKey:(NSString *)savekey {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:self.bucket forKey:@"bucket"];
    [dic setObject:DATE_STRING(self.expiresIn) forKey:@"expiration"];
    if (savekey && ![savekey isEqualToString:@""]) {
        [dic setObject:savekey forKey:@"save-key"];
    }
    
    if (self.params) {
        for (NSString *key in self.params.keyEnumerator) {
            [dic setObject:[self.params objectForKey:key] forKey:key];
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [json Base64encode];
}

- (NSString *)getSignatureWithPolicy:(NSString *)policy
{
    NSString *str = [NSString stringWithFormat:@"%@&%@",policy,self.passcode];
    NSString *signature = [[[str dataUsingEncoding:NSUTF8StringEncoding] MD5HexDigest] lowercaseString];
    return signature;
}


- (NSURLSessionTask *)creatSessinTaskWithSaveKey:(NSString *)saveKey
                                                 data:(NSData *)data
                                             filePath:(NSString *)filePath{
    //进度回调
    HttpProgressBlock httpProgress = ^(int64_t completedBytesCount, int64_t totalBytesCount) {
        CGFloat percent = completedBytesCount/(float)totalBytesCount;
        if (_progressBlocker) {
            _progressBlocker(percent, totalBytesCount);
        }
    };
    //成功回调
    HttpSuccessBlock httpSuccess = ^(NSURLResponse *response, id responseObject){
        NSError* error;
        NSDictionary * jsonDic = [NSJSONSerialization JSONObjectWithData:responseObject
                                                                 options:kNilOptions
                                                                   error:&error];;
        NSString *message = [jsonDic objectForKey:@"message"];
        if ([@"ok" isEqualToString:message]) {
            if (_successBlocker) {
                _successBlocker(response, jsonDic);
            }
        } else {
            NSError *err = [NSError errorWithDomain:ERROR_DOMAIN
                                               code:[[jsonDic objectForKey:@"code"] intValue]
                                           userInfo:jsonDic];
            if (_failBlocker) {
                _failBlocker(err);
            }
        }
    };
    //失败回调
    HttpFailBlock httpFail = ^(NSError * error){
        if (_failBlocker) {
            _failBlocker(error);
        }
    };
    
    NSString *policy = [self getPolicyWithSaveKey:saveKey];
    
    NSString *signature = @"";
    if (_signatureBlocker) {
        signature = _signatureBlocker(policy);
    } else if (self.passcode) {
        signature = [self getSignatureWithPolicy:policy];
    } else {
        NSString *message = _signatureBlocker?@"没有提供密钥":@"没有实现signatureBlock";
        NSError *err = [NSError errorWithDomain:ERROR_DOMAIN
                                           code:-1999
                                       userInfo:@{@"message":message}];
        if (_failBlocker) {
            _failBlocker(err);
        }
    }
    NSDictionary *parameDic = @{@"policy":policy, @"signature":signature};

    UPMultipartBody *multiBody = [[UPMultipartBody alloc]initWithBoundary:@"Boundary+32309A3DE1A3C0DB"];
    [multiBody addDictionary:parameDic];
    if (data) {
        [multiBody addFileData:data WithFileName:@"file"];
    } else if (filePath) {
        [multiBody addFilePath:filePath WithFileName:@"file"];
    }
    
    [multiBody dataFromPart];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:REQUEST_URL(self.bucket)];
    request.HTTPMethod = @"POST";
    request.HTTPBody = multiBody.data;
    [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", multiBody.boundary] forHTTPHeaderField:@"Content-Type"];
    
    UPHTTPClient *client = [[UPHTTPClient alloc]init];
    [client uploadRequest:request success:httpSuccess failure:httpFail progress:httpProgress];
    
    return nil;
}

#pragma mark----mut upload

- (void) mutUploadFilePath:(NSString *)path savekey:(NSString *)savekey
{
    
}

- (void) mutUploadImage:(UIImage *)image savekey:(NSString *)savekey
{
    
}

- (void) mutUploadFileData:(NSData *)data savekey:(NSString *)savekey
{
    
}




@end
