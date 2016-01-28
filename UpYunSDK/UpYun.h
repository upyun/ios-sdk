//
//  UpYun.h
//  UpYunSDK
//
//  Created by jack zhou on 13-8-6.
//  Copyright (c) 2013年 upyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "NSData+MD5Digest.h"

#import "UPHTTPClient.h"
/**
 *	@brief 默认空间名(必填项), 可在init之后修改bucket的值来更改
 */

#define DEFAULT_BUCKET @"test654123"
/**
 *	@brief	默认表单API密钥, 可在init之后修改passcode的值来更改
 */
#define DEFAULT_PASSCODE @"0/8/1gPFWUQWGcfjFn6Vsn3VWDc="

/**
 *	@brief	默认当前上传授权的过期时间，单位为“秒” （必填项，较大文件需要较长时间)，可在init之后修改expiresIn的值来更改
 */
//#error 必填项
#define DEFAULT_EXPIRES_IN 600


/**
 *	@brief 默认超过大小后走分块上传，可在init之后修改mutUploadSize的值来更改
 */
#define DEFAULT_MUTUPLOAD_SIZE 2*1024*1024


/**
 *	@brief 失败重穿次数
 */
#define DEFAULT_RETRY_TIMES 1

/**
 *  单个分块尺寸100kb(不可小于此值)
 */
static NSInteger SingleBlockSize = 1024*100;

#define API_DOMAIN @"http://v0.api.upyun.com/"

#define API_MUT_DOMAIN @"http://m0.api.upyun.com/"


#define DATE_STRING(expiresIn) [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970] + expiresIn]

typedef void(^UPCompeleteBlock)(NSError *error, NSDictionary *result, BOOL completed);

typedef void(^UPSuccessBlock)(NSURLResponse *response, id responseData);
typedef void(^UPFailBlock)(NSError *error);
typedef void(^UPProGgressBlock)(CGFloat percent, int64_t requestDidSendBytes);
typedef NSString*(^UPSignatureBlock)(NSString *policy);


@interface UpYun : NSObject

@property (nonatomic, copy) NSString *bucket;

@property (nonatomic, assign) NSTimeInterval expiresIn;

@property (nonatomic, copy) NSMutableDictionary *params;

@property (nonatomic, copy) NSString *passcode;

@property (nonatomic, assign) NSInteger mutUploadSize;

@property (nonatomic, assign) NSInteger retryTimes;

@property (nonatomic, copy) UPSuccessBlock    successBlocker;

@property (nonatomic, copy) UPFailBlock       failBlocker;

@property (nonatomic, copy) UPProGgressBlock  progressBlocker;

@property (nonatomic, copy) UPSignatureBlock  signatureBlocker;



/**********************/
/**以下新增接口 建议使用**/
/**
 *	@brief	上传文件
 *
 *	@param 	file 	文件信息 可用值:  1、UIImage(会转成PNG格式，需要其他格式请先转成NSData传入 或者 传入文件路径)、
 2、NSData、
 3、NSString(文件路径)
 *	@param 	saveKey 	由开发者自定义的saveKey
 */
-(void)uploadFile:(id)file saveKey:(NSString *)saveKey;

/**以上新增接口 建议使用**/
/**********************/


/**
 *	@brief	上传图片接口
 *
 *	@param 	image 	图片
 *	@param 	savekey 	savekey
 */
- (void)uploadImage:(UIImage *)image savekey:(NSString *)savekey;

/**
 *	@brief	上传图片接口
 *
 *	@param 	path 	图片path
 *	@param 	savekey 	savekey
 */
- (void)uploadImagePath:(NSString *)path savekey:(NSString *)savekey;

/**
 *	@brief	上传图片接口
 *
 *	@param 	data 	图片data
 *	@param 	savekey 	savekey
 */
- (void) uploadImageData:(NSData *)data savekey:(NSString *)savekey;

@end
