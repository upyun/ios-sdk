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
    //[self testFormUploader2];
    //[self testBlockUpLoader1];
}

//本地签名的表单上传。
- (void)testFormUploader1 {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mov"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    [up uploadWithBucketName:@"test86400"
                    operator:@"operator123"
                    password:@"password123"
                    fileData:fileData
                    fileName:nil
                     saveKey:@"ios_sdk_new/video.mov"
             otherParameters:nil
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传成功 responseBody：%@", responseBody);
                         NSLog(@"file url：https://test86400.b0.upaiyun.com/%@", [responseBody objectForKey:@"url"]);
                     }
     
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 responseBody：%@", responseBody);
                         NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                     }
     
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSString *progress = [NSString stringWithFormat:@"%lld / %lld", completedBytesCount, totalBytesCount];
                        NSString *progress_rate = [NSString stringWithFormat:@"upload %.1f %%", 100 * (float)completedBytesCount / totalBytesCount];
                        NSLog(@"upload progress: %@", progress);
                        //到主线程刷新ui
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self.uploadBtn setTitle:progress_rate forState:UIControlStateNormal];
                        });
                    }];

}

//服务器端签名的表单上传（模拟）
- (void)testFormUploader2 {
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"picture.jpg"];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    UpYunFormUploader *up = [[UpYunFormUploader alloc] init];
    
    //从 app 服务器获取的上传策略 policy
    NSString *policy = @"ewogICJjb250ZW50LW1kNSIgOiAiNDRiN2E4ZjMyN2Q3OTk1NjIzY2Q5MmJhZDYzYTc2MmMiLAogICJzYXZlLWtleSIgOiAiaW9zX3Nka19uZXdcLzExMXBpY3R1cmUuanBnIiwKICAiYnVja2V0IiA6ICJ0ZXN0ODY0MDAiLAogICJleHBpcmF0aW9uIiA6ICIxNDg3MDY3NjUyIiwKICAiZGF0ZSIgOiAiVHVlLCAxNCBGZWIgMjAxNyAwOTo1MDo1MSBHTVQiCn0=";
    
    //从 app 服务器获取的上传策略签名 signature
    NSString *signature = @"nbkIJVuqQvOckxFzdY5GkQ6dk5A=";
    
    [up uploadWithOperator:@"test86400"
                    policy:policy
                 signature:signature
                  fileData:fileData
                  fileName:nil
                   success:^(NSHTTPURLResponse *response,
                             NSDictionary *responseBody) {
                       NSLog(@"上传成功 responseBody：%@", responseBody);
                       NSLog(@"file url：https://test86400.b0.upaiyun.com/%@", [responseBody objectForKey:@"url"]);
                   }
     
                   failure:^(NSError *error,
                             NSHTTPURLResponse *response,
                             NSDictionary *responseBody) {
                       NSLog(@"上传失败 error：%@", error);
                       NSLog(@"上传失败 responseBody：%@", responseBody);
                       NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                   }
     
                  progress:^(int64_t completedBytesCount,
                             int64_t totalBytesCount) {
                      NSLog(@"upload progress: %lld / %lld", completedBytesCount, totalBytesCount);
                      
                  }];
}

//分块上传
- (void)testBlockUpLoader1{
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    NSString *filePath = [resourcePath stringByAppendingPathComponent:@"video.mov"];
    
    UpYunBlockUpLoader *up = [[UpYunBlockUpLoader alloc] init];
    NSString *bucketName = @"test86400";
    NSString *savePath = @"iossdk/blockupload/picture.jpg";
    
    [up uploadWithBucketName:bucketName
                    operator:@"operator123"
                    password:@"password123"
                        file:filePath
                    savePath:savePath
                     success:^(NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传成功");
                         NSLog(@"file url：https://%@.b0.upaiyun.com/%@",bucketName, savePath);
                     }
                     failure:^(NSError *error,
                               NSHTTPURLResponse *response,
                               NSDictionary *responseBody) {
                         NSLog(@"上传失败 error：%@", error);
                         NSLog(@"上传失败 responseBody：%@", responseBody);
                         NSLog(@"上传失败 message：%@", [responseBody objectForKey:@"message"]);
                     }
                    progress:^(int64_t completedBytesCount,
                               int64_t totalBytesCount) {
                        NSLog(@"upload progress: %lld / %lld", completedBytesCount, totalBytesCount);
                    }];
}

- (void)uploadBtn1Tap:(id)sender {
    ViewController *vc = [[ViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}


@end
