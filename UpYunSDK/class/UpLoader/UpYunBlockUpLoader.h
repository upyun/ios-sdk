//
//  UpYunBlockUpLoader.h
//  UpYunSDKDemo
//
//  Created by DING FENG on 2/16/17.
//  Copyright © 2017 upyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UpYunUploader.h"

@interface UpYunBlockUpLoader : NSObject


/*表单上传接口
 参数  bucketName:           上传空间名
 参数  operator:             空间操作员
 参数  password:             空间操作员秘密
 参数  formAPIKey:           表单密钥
 参数  fileData:             上传文件数据
 参数  fileName:             上传文件名
 参数  saveKey:              上传文件的保存路径, 例如：“/2015/0901/file1.jpg”。可用占位符，参考：http://docs.upyun.com/api/form_api/#save-key
 参数  otherParameters:      可选的其它参数可以为nil. 参考文档：表单-API-参数http://docs.upyun.com/api/form_api/#_2
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
