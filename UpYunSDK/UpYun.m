//
//  UpYun.m
//  UpYunSDK
//
//  Created by jack zhou on 13-8-6.
//  Copyright (c) 2013年 upyun. All rights reserved.
//

#import "UpYun.h"
#import "UPMultipartBody.h"
#import "NSString+NSHash.h"
#import "UPMutUploaderManager.h"

#define ERROR_DOMAIN @"upyun.com"
#define DATE_STRING(expiresIn) [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970] + expiresIn]
#define REQUEST_URL(bucket) [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/",API_DOMAIN,bucket]]

#define SUB_SAVE_KEY_FILENAME @"{filename}"

@implementation UpYun
- (instancetype)init {
    if (self = [super init]) {
        self.bucket = DEFAULT_BUCKET;
        self.expiresIn = DEFAULT_EXPIRES_IN;
        self.passcode = DEFAULT_PASSCODE;
        self.mutUploadSize = DEFAULT_MUTUPLOAD_SIZE;
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
    [self uploadSavekey:savekey data:nil filePath:path];
}

- (void) uploadFileData:(NSData *)data savekey:(NSString *)savekey
{
    [self uploadSavekey:savekey data:data filePath:nil];
}

- (void) uploadSavekey:(NSString *)savekey data:(NSData*)data filePath:(NSString*)filePath {
    
    NSInteger fileSize = data.length;
    if (filePath) {
        NSError *error = nil;
        NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
        fileSize = [fileDictionary fileSize];
    }
    
    if (fileSize > self.mutUploadSize) {
        [self mutUploadFileData:data OrFilePath:filePath savekey:savekey];
    } else {
        [self formUploadWithSaveKey:savekey data:data filePath:filePath];
    }
}

- (void)uploadFile:(id)file saveKey:(NSString *)saveKey
{
    //非path传入的需要检查savekey
    if (![file isKindOfClass:[NSString class]] && ![self checkSavekey:saveKey]) {
        return;
    }
    if([file isKindOfClass:[UIImage class]]){
        [self uploadImage:file savekey:saveKey];
    }else if([file isKindOfClass:[NSData class]]) {
        [self uploadFileData:file savekey:saveKey];
    }else if([file isKindOfClass:[NSString class]]) {
        [self uploadFilePath:file savekey:saveKey];
    }else {
        NSString *errorInfo = [NSString stringWithFormat:@"传入参数类型错误: file is %@",file];
        NSError *error = [NSError errorWithDomain:ERROR_DOMAIN
                                           code:-1999
                                       userInfo:@{@"message":errorInfo}];
        if (_failBlocker) {
            _failBlocker(error);
        }
    }
}

- (void)formUploadWithSaveKey:(NSString *)saveKey
                         data:(NSData *)data
                     filePath:(NSString *)filePath {
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
    
    __block NSString *signature = @"";
    if (_signatureBlocker) {
        dispatch_async(dispatch_get_main_queue(), ^(){
            signature = _signatureBlocker([policy stringByAppendingString:@"&"]);
        });
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
    
    UPMultipartBody *multiBody = [[UPMultipartBody alloc]init];
    [multiBody addDictionary:parameDic];
    [multiBody addFileData:data OrFilePath:filePath fileName:@"file" fileType:nil];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:REQUEST_URL(self.bucket)];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [multiBody dataFromPart];
    [request setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", multiBody.boundary] forHTTPHeaderField:@"Content-Type"];
    
    UPHTTPClient *client = [[UPHTTPClient alloc]init];
    [client uploadRequest:request success:httpSuccess failure:httpFail progress:httpProgress];
}

#pragma mark----mut upload

- (void)mutUploadFileData:(NSData *)data OrFilePath:(NSString*) filePath savekey:(NSString *)savekey {
    
    NSDictionary *fileInfo = nil;
    if (filePath) {
        fileInfo = [UPMutUploaderManager fetchFileInfoDictionaryWithFilePath:filePath];
    } else if (data) {
        fileInfo = [UPMutUploaderManager fetchFileInfoDictionaryWith:data];
    }
    
    NSDictionary *signaturePolicyDic = [self constructingSignatureAndPolicyWithFileInfo:fileInfo saveKey:savekey];
    
    NSString *signature = signaturePolicyDic[@"signature"];
    NSString *policy = signaturePolicyDic[@"policy"];
    
    UPMutUploaderManager *manager = [[UPMutUploaderManager alloc]initWithBucket:self.bucket];
    [manager uploadWithFile:data OrFilePath: filePath policy:policy signature:signature progressBlock:_progressBlocker completeBlock:^(NSError *error, NSDictionary *result, BOOL completed) {
        dispatch_async(dispatch_get_main_queue(), ^() {

            UIAlertView * alert;
            if (completed) {
                alert = [[UIAlertView alloc]initWithTitle:@"上传成功" message:@"" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
                NSLog(@"%@",result);
            } else {
                alert = [[UIAlertView alloc]initWithTitle:@"上传失败" message:error.userInfo[@"message"] delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
                NSLog(@"%@",error.userInfo);
            }
            [alert show];
        });
    }];
}

#pragma mark--Utils---

/**
 *  根据文件信息生成Signature\Policy (安全起见，以下算法应在服务端完成)
 *  @param paramaters 文件信息
 *  @return
 */
- (NSDictionary *)constructingSignatureAndPolicyWithFileInfo:(NSDictionary *)fileInfo saveKey:(NSString*) saveKey{
    NSMutableDictionary * mutableDic = [[NSMutableDictionary alloc]initWithDictionary:fileInfo];
    [mutableDic setObject:@(ceil([[NSDate date] timeIntervalSince1970])+60) forKey:@"expiration"];//设置授权过期时间
    [mutableDic setObject:saveKey forKey:@"path"];//设置保存路径
    /**
     *  这个 mutableDic 可以塞入其他可选参数 见：http://docs.upyun.com/api/multipart_upload/#_2
     */
    
    NSString *policy = [self dictionaryToJSONStringBase64Encoding:mutableDic];
    
    __block NSString *signature = @"";
    if (_signatureBlocker) {
        dispatch_async(dispatch_get_main_queue(), ^(){
            signature = _signatureBlocker(policy);
        });
    } else if (self.passcode) {
        NSArray * keys = [mutableDic allKeys];
        keys= [keys sortedArrayUsingSelector:@selector(compare:)];
        for (NSString * key in keys) {
            NSString * value = mutableDic[key];
            signature = [NSString stringWithFormat:@"%@%@%@",signature,key,value];
        }
        signature = [signature stringByAppendingString:self.passcode];
    } else {
        NSString *message = _signatureBlocker?@"没有提供密钥":@"没有实现signatureBlock";
        NSError *err = [NSError errorWithDomain:ERROR_DOMAIN
                                           code:-1999
                                       userInfo:@{@"message":message}];
        if (_failBlocker) {
            _failBlocker(err);
        }
    }
    return @{@"signature":[signature MD5],
             @"policy":policy};
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

- (NSString *)getSignatureWithPolicy:(NSString *)policy {
    NSString *str = [NSString stringWithFormat:@"%@&%@", policy, self.passcode];
    NSString *signature = [[[str dataUsingEncoding:NSUTF8StringEncoding] MD5HexDigest] lowercaseString];
    return signature;
}

- (NSString *)dictionaryToJSONStringBase64Encoding:(NSDictionary *)dic {
    id paramesData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:paramesData
                                                 encoding:NSUTF8StringEncoding];
    return [jsonString Base64encode];
}

- (BOOL)checkSavekey:(NSString *)string {
    NSRange rangeFileName;
    NSRange rangeFileNameOnDic;
    rangeFileName = [string rangeOfString:SUB_SAVE_KEY_FILENAME];
    if ([_params objectForKey:@"save-key"]) {
        rangeFileNameOnDic = [[_params objectForKey:@"save-key"]
                              rangeOfString:SUB_SAVE_KEY_FILENAME];
    }
    
    if(rangeFileName.location != NSNotFound || rangeFileNameOnDic.location != NSNotFound) {
        NSString *message = [NSString stringWithFormat:@"传入file为NSData或者UIImage时,不能使用%@方式生成savekey", SUB_SAVE_KEY_FILENAME];
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

@end