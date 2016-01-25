//
//  UMUUploaderManager.h
//  UpYunMultipartUploadSDK
//
//  Created by Jack Zhou on 6/10/14.
//
//

#import <Foundation/Foundation.h>


@interface UMUUploaderManager : NSObject

#pragma mark - setup Methods

/**
 *  设置授权时间长度（秒）默认为60秒
 */
+ (void)setValidTimeSpan:(NSInteger)validTimeSpan;

/**
 *  设置服务器地址 默认 @"http://m0.api.upyun.com/"
 *
 *  @param server 服务器地址
 */
+ (void)setServer:(NSString *)server;


/**
 *  设置请求重试次数 默认为:3
 *
 *  @param 重试次数
 */
+ (void)setMaxRetryCount:(NSInteger)retryCount;

#pragma mark - init Method

/**
 *  返回UMUUploaderManager 单例
 *
 *  @return bucket 空间 bucket
 *  @return UMUUploaderManager 实例
 */
+ (instancetype)managerWithBucket:(NSString *)bucket;

#pragma mark - Method

/**
 *  获取文件元信息 计算policy、signature需要此信息
 *
 *  @param fileData 文件数据
 *
 *  @return 获取文件元信息 字典
 */
+ (NSDictionary *)fetchFileInfoDictionaryWith:(NSData *)fileData;

/**
 *  上传文件
 *
 *  @param fileData                       文件数据
 *  @param policy                         策略信息
 *  @param signature                      签名
 *  @param progressBlock                  进度回调
 *  @param completeBlock                  结束回调:
 *                                          当completed
 *                                          为  YES 上传成功，可以从result中获取返回信息，
 *                                          为  NO  上传失败，可以从error 获取失败信息
 *
 *  @return UMUUploaderOperation
 */
- (NSMutableArray *)uploadWithFile:(NSData *)fileData
                                  policy:(NSString *)policy
                               signature:(NSString *)signature
                           progressBlock:(void (^)(CGFloat percent, int64_t requestDidSendBytes))progressBlock
                           completeBlock:(void (^)(NSError * error,
                                                   NSDictionary * result,
                                                   BOOL completed))completeBlock;

/**
 *  取消所有请求
 */
+ (void)cancelAllOperations;

@end
