//
//  ViewController2.m
//  upyundemo
//
//  Created by andy yao on 12-6-14.
//  Copyright (c) 2012年 upyun.com. All rights reserved.
//

#import "ViewController2.h"
#import "UpYunFormUploader.h" //图片，小文件，短视频
#import "UpYunBlockUpLoader.h" //分块上传，适合大文件上传

#import "ViewController.h"


@interface ViewController2 ()
@property (strong, nonatomic) UIButton *uploadBtn;
@property (strong, nonatomic) UIButton *uploadBtn1;


@end

@implementation ViewController2
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.uploadBtn = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 200, 44)];
    self.uploadBtn.backgroundColor = [UIColor lightGrayColor];
    [self.uploadBtn setTitle:@"upload"
               forState:UIControlStateNormal];
    [self.uploadBtn addTarget:self
                  action:@selector(uploadBtntap:)
        forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.uploadBtn];
    
    
    self.uploadBtn1 = [[UIButton alloc] initWithFrame:CGRectMake(100, 300, 200, 44)];
    self.uploadBtn1.backgroundColor = [UIColor lightGrayColor];
    [self.uploadBtn1 setTitle:@"旧版本"
                    forState:UIControlStateNormal];
    [self.uploadBtn1 addTarget:self
                       action:@selector(uploadBtn1Tap:)
             forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.uploadBtn1];
}

- (void)uploadBtntap:(id)sender {
        [self testFormUploader1];
//      [self testFormUploader2];
//      [self testBlockUpLoader1];
//      [self testFormUploaderAndAsyncTask];

}

//本地签名的表单上传。
- (void)testFormUploader1 {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mp4"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    
    NSString *bucketName = @"test86400";
    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    fileData:fileData
                    fileName:nil
                     saveKey:@"ios_sdk_new/video.mp4"
             otherParameters:nil
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传成功 responseBody：%@", responseBody);
                         NSLog(@"file url：https://%@.b0.upaiyun.com/%@", bucketName, [responseBody objectForKey:@"url"]);
                         //主线程刷新ui
                     }
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 responseBody：%@", responseBody);
                         NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                         //主线程刷新ui
                         dispatch_async(dispatch_get_main_queue(), ^(){
                             NSString *message = [responseBody objectForKey:@"message"];
                             if (!message) {
                                 message = [NSString stringWithFormat:@"%@", error.localizedDescription];
                             }
                             UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"上传失败!"
                                                                                            message:message
                                                                                     preferredStyle:UIAlertControllerStyleAlert];
                             UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                                                     style:UIAlertActionStyleDefault
                                                                                   handler:nil];
                             [alert addAction:defaultAction];
                             [self presentViewController:alert animated:YES completion:nil];
                         });
                     }
     
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);
                        
                        if ([progress floatValue] > 0.4) {
                            [up cancel];
                        }
                       
                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];

}

//服务器端签名的表单上传（模拟）
- (void)testFormUploader2 {
    //从 app 服务器获取的上传策略 policy
    NSString *policy = @"eyJleHBpcmF0aW9uIjoxNDg5Mzc4NjExLCJyZXR1cm4tdXJsIjoiaHR0cGJpbi5vcmdcL3Bvc3QiLCJidWNrZXQiOiJmb3JtdGVzdCIsInNhdmUta2V5IjoiXC91cGxvYWRzXC97eWVhcn17bW9ufXtkYXl9XC97cmFuZG9tMzJ9ey5zdWZmaXh9In0=";
    
    //从 app 服务器获取的上传策略签名 signature
    NSString *signature = @"BIC22iXgu5fBUXgoMGGpdWNpsak=";
    
    
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"picture.jpg"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    
    NSString *operatorName = @"one";
    [up uploadWithOperator:operatorName
                    policy:policy
                 signature:signature
                  fileData:fileData
                  fileName:nil
                   success:^(NSHTTPURLResponse *response,
                             NSDictionary *responseBody) {
                       NSLog(@"上传成功 responseBody：%@", responseBody);
                       //主线程刷新ui
                   }
     
                   failure:^(NSError *error,
                             NSHTTPURLResponse *response,
                             NSDictionary *responseBody) {
                       NSLog(@"上传失败 error：%@", error);
                       NSLog(@"上传失败 responseBody：%@", responseBody);
                       NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                       //主线程刷新ui
                   }
     
                  progress:^(int64_t completedBytesCount,
                             int64_t totalBytesCount) {
                      NSLog(@"upload progress: %lld / %lld", completedBytesCount, totalBytesCount);
                      //主线程刷新ui
                  }];
}

//分块上传
- (void)testBlockUpLoader1{
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mp4"];
    
    UpYunBlockUpLoader *up = [[UpYunBlockUpLoader alloc] init];
    NSString *bucketName = @"test86400";
    NSString *savePath = @"iossdk/blockupload/video.mp4";
    
    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    filePath:filePath
                    savePath:savePath
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传成功");
                         NSLog(@"file url：https://%@.b0.upaiyun.com/%@",bucketName, savePath);
                         //主线程刷新ui

                     }
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 responseBody：%@", responseBody);
                         NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                         //主线程刷新ui

                     }
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);
                        
                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];
}



//表单上传加异步多媒体处理－－视频截图
- (void)testFormUploaderAndAsyncTask {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mp4"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    
    //异步视频截图处理。更详细参数参考：云处理文档－音视频处理－视频截图 http://docs.upyun.com/cloud/av/#_16
    NSDictionary *asycTask = @{@"name": @"naga",@"type": @"thumbnail",
                               @"save_as": @"ios_sdk_new/test2/video.jpg",
                               @"avopts": @"/o/true/n/1/",
                               @"notify_url": @"http://124.160.114.202:18989/echo"};
    NSArray *apps = @[asycTask];
    
    NSString *bucketName = @"test86400";
    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                    fileData:fileData
                    fileName:nil
                     saveKey:@"ios_sdk_new/test2/video.mp4"
             otherParameters:@{@"apps": apps}
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传成功 responseBody：%@", responseBody);
                         NSLog(@"file url：https://%@.b0.upaiyun.com/%@", bucketName, [responseBody objectForKey:@"url"]);
                         //主线程刷新ui
                     }
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 responseBody：%@", responseBody);
                         NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                         //主线程刷新ui
                         dispatch_async(dispatch_get_main_queue(), ^(){
                             NSString *message = [responseBody objectForKey:@"message"];
                             if (!message) {
                                 message = [NSString stringWithFormat:@"%@", error.localizedDescription];
                             }
                             UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"上传失败!"
                                                                                            message:message
                                                                                     preferredStyle:UIAlertControllerStyleAlert];
                             UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                                                     style:UIAlertActionStyleDefault
                                                                                   handler:nil];
                             [alert addAction:defaultAction];
                             [self presentViewController:alert animated:YES completion:nil];
                         });
                     }
     
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);
                        
                        //主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];

}

//旧版本 sdk demo
- (void)uploadBtn1Tap:(id)sender {
    ViewController *vc = [[ViewController alloc] initWithNibName:@"ViewController_iPhone" bundle:nil];
    [self presentViewController:vc animated:YES completion:nil];
}


@end
