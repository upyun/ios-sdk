//
//  UPMultipartBody.h
//  UpYunSDK2.0Demo
//
//  Created by 林港 on 16/1/19.
//  Copyright © 2016年 upyun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UPMultipartBody : NSObject
@property (nonatomic, copy) NSString* boundary;
@property (nonatomic, strong) NSMutableData* data;
- (instancetype)initWithBoundary:(NSString*)boundary;

- (void)addKey:(NSString*)key AndValue:(NSString*)value;
- (void)addDictionary:(NSDictionary *)parames;
- (void)addFilePath:(NSString*)filePath WithFileName:(NSString*)fileName;
- (void)addFileData:(NSData*)fileData WithFileName:(NSString*)fileName;




- (void)dataFromPart;
@end
