//
//  UPMultipartBody.m
//  UpYunSDK2.0Demo
//
//  Created by 林港 on 16/1/19.
//  Copyright © 2016年 upyun. All rights reserved.
//

#import "UPMultipartBody.h"
#import "UPHTTPBodyPart.h"




@interface UPMultipartBody()

@property (nonatomic, strong) NSMutableArray* bodyParts;

@end

@implementation UPMultipartBody


- (instancetype)init {
    return [self initWithBoundary:AFCreateMultipartFormBoundary()];
}

- (instancetype)initWithBoundary:(NSString*)boundary {
    self = [super init];
    if (self) {
        self.boundary = boundary;
        self.bodyParts = [NSMutableArray new];
        self.data = [NSMutableData new];
    }
    return self;
}


- (void)addKey:(NSString*)key AndValue:(NSString*)value {
    
    UPHTTPBodyPart *part = [[UPHTTPBodyPart alloc]init];
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"", key] forKey:@"Content-Disposition"];
    part.headers = mutableHeaders;
    part.body = [value dataUsingEncoding:NSUTF8StringEncoding];
    [self.bodyParts addObject:part];
}

- (void)addDictionary:(NSDictionary *)parames {
    for (NSString* key in parames) {
        NSString *value = [parames objectForKey:key];
        [self addKey:key AndValue:value];
    }
}

- (void)addFilePath:(NSString*)filePath WithFileName:(NSString*)fileName {
    
    UPHTTPBodyPart *part = [[UPHTTPBodyPart alloc]init];
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", fileName, fileName] forKey:@"Content-Disposition"];
    [mutableHeaders setValue:@"application/octet-stream" forKey:@"Content-Type"];
    
    part.headers = mutableHeaders;
    part.body = filePath;
    [self.bodyParts addObject:part];
}

- (void)addFileData:(NSData*)fileData WithFileName:(NSString*)fileName {
    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", fileName, fileName] forKey:@"Content-Disposition"];
    [mutableHeaders setValue:@"application/octet-stream" forKey:@"Content-Type"];
    
    UPHTTPBodyPart *part = [[UPHTTPBodyPart alloc]init];
    part.headers = mutableHeaders;
    part.body = fileData;
    [self.bodyParts addObject:part];
}


- (void)dataFromPart {

    for (int i = 0; i< self.bodyParts.count; i++) {
        UPHTTPBodyPart *part = self.bodyParts[i];
        
        NSData *beginData = [AFMultipartFormEncapsulationBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding];
        [self.data appendData:beginData];
        
        NSData *headerData = [[part stringForHeaders] dataUsingEncoding:NSUTF8StringEncoding];
        [self.data appendData:headerData];
        
        if ([part.body isKindOfClass:[NSData class]]) {
            [self.data appendData:part.body];
        } else if ([part.body isKindOfClass:[NSString class]]) {
            NSData *fileData = [NSData dataWithContentsOfFile:part.body];
            [self.data appendData:fileData];
        }
    }
    
    NSData *endData = [AFMultipartFormFinalBoundary(self.boundary) dataUsingEncoding:NSUTF8StringEncoding];
    [self.data appendData:endData];
}

@end
