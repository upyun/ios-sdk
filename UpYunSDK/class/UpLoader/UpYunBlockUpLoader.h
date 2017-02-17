//
//  UpYunBlockUpLoader.h
//  UpYunSDKDemo
//
//  Created by DING FENG on 2/16/17.
//  Copyright © 2017 upyun. All rights reserved.
//



/*实现的存储接口及文档
 REST API。文档地址：http://docs.upyun.com/api/rest_api/#_3
 认证鉴权－在 Header 中包含签名。 文档地址：http://docs.upyun.com/api/authorization/#header
 */

#import <Foundation/Foundation.h>
#import "UpYunUploader.h"


@interface UpYunBlockUpLoader : NSObject


/*表单上传接口
 参数  bucketName:           上传空间名
 参数  operator:             空间操作员
 参数  operatorPassword:     空间操作员秘密
 参数  filePath:             上传文件本地路径
 参数  savePath:             上传文件的保存路径, 例如：“/2015/0901/file1.jpg”
 参数  successBlock:         上传成功回调
 参数  failureBlock:         上传失败回调
 参数  progressBlock:        上传进度回调
 */

- (void)uploadWithBucketName:(NSString *)bucketName
                    operator:(NSString *)operatorName
                    password:(NSString *)operatorPassword
                        file:(NSString *)filePath
                    savePath:(NSString *)savePath
                     success:(UpLoaderSuccessBlock)successBlock
                     failure:(UpLoaderFailureBlock)failureBlock
                    progress:(UpLoaderProgressBlock)progressBlock;
//取消上传
- (void)cancel;

@end
