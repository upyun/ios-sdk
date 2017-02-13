//
//  UpApiUtils.m
//  UpYunSDKDemo
//
//  Created by DING FENG on 2/13/17.
//  Copyright © 2017 upyun. All rights reserved.
//

#import "UpApiUtils.h"
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>

#define UPYUN_FILE_MD5_CHUNK_SIZE (1024*64)

@implementation UpApiUtils


+ (NSString *)getPolicyWithParameters:(NSDictionary *)parameter {
    /*Policy生成步骤：
      第 1 步：将请求参数键值对转换为 JSON 字符串；
      第 2 步：将第 1 步所得到的字符串进行 Base64 Encode 处理，得到 policy。
     */
    
    NSDictionary *info = parameter;
    NSString *jsonString;
    if ([NSJSONSerialization isValidJSONObject:info]) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
        
        jsonString = [[NSString alloc] initWithData:jsonData
                                           encoding:NSUTF8StringEncoding];
        if (!error && jsonString) {
            
            NSString *policy = [UpApiUtils base64EncodeFromString:jsonString];
            return policy;//最终生成上传策略
        }
        
    }
    return nil;
}

+ (NSString *)getSignatureWithPassword:(NSString *)password
                            parameters:(NSArray *)parameter {
    /*Signature 计算方式
     <Signature> = Base64 (HMAC-SHA1 (<Password>,
     <Method>&
     <URI>&
     <Date>&
     <Content-MD5>
     ))
     */
    NSString *parameterString = [parameter componentsJoinedByString:@"&"];
    NSString *passwordHash = [UpApiUtils getMD5HashFromData:[NSData dataWithBytes:password.UTF8String
                                                                           length:password.length]];
    
    NSString *signature = [UpApiUtils getHmacSha1HashWithKey:passwordHash
                                                      string:parameterString];
    return signature;//signature 已经是 Base64 编码
}


+ (NSString*)getMD5HashFromData:(NSData *)data {
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (int)data.length, result);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1],
            result[2], result[3],
            result[4], result[5],
            result[6], result[7],
            result[8], result[9],
            result[10], result[11],
            result[12], result[13],
            result[14], result[15]];
}


+ (NSString *)getMD5HashOfFileAtPath:(NSString *)path {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if(handle == nil) {
        NSLog(@"ERROR GETTING FILE MD5:file didnt exist");
        return nil;
    }
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    BOOL done = NO;
    while(!done) {
        @autoreleasepool {
            NSData* fileData = [handle readDataOfLength: UPYUN_FILE_MD5_CHUNK_SIZE ];
            CC_MD5_Update(&md5, [fileData bytes], (uint32_t)[fileData length]);
            if([fileData length] == 0) done = YES;
        }
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSString* s = [NSString stringWithFormat:
                   @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[0], digest[1],
                   digest[2], digest[3],
                   digest[4], digest[5],
                   digest[6], digest[7],
                   digest[8], digest[9],
                   digest[10], digest[11],
                   digest[12], digest[13],
                   digest[14], digest[15]];
    return s;
}


+ (NSString *)base64EncodeFromString:(NSString *)string {
    NSData *stingData = [NSData dataWithBytes:string.UTF8String length:string.length];
    NSData *base64Data = [stingData base64EncodedDataWithOptions:0];
    NSString *base64String = [NSString stringWithUTF8String:base64Data.bytes];
    return base64String;
}

+ (NSString *)base64DecodeFromString:(NSString *)base64String {
    NSData *stringData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    NSString *string = [NSString stringWithUTF8String:stringData.bytes];
    return string;
}

+ (NSString *)getHmacSha1HashWithKey:(NSString *)key string:(NSString *)string {
    const char *cKey  = [key cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [string cStringUsingEncoding:NSUTF8StringEncoding];
    char cHMAC[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:CC_SHA1_DIGEST_LENGTH];
    NSData *hashData = [HMAC base64EncodedDataWithOptions:0];
    NSString *hashString = [NSString stringWithUTF8String:hashData.bytes];
    return hashString;
}


@end