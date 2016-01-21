//
//  ViewController.m
//  upyundemo
//
//  Created by andy yao on 12-6-14.
//  Copyright (c) 2012年 upyun.com. All rights reserved.
//

#import "ViewController.h"
#import "UpYun.h"
#import "UMUUploaderManager.h"
#import "NSString+NSHash.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UIProgressView *pv;
@end

@implementation ViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (IBAction)mutilUploadAction:(UIButton *)sender {
    
    NSString * url = [[NSBundle mainBundle] pathForResource:@"image" ofType:@"jpg"];
    
    NSData * fileData = [NSData dataWithContentsOfFile:url];
    
    NSDictionary * fileInfo = [UMUUploaderManager fetchFileInfoDictionaryWith:fileData];//获取文件信息
    
    NSDictionary * signaturePolicyDic =[self constructingSignatureAndPolicyWithFileInfo:fileInfo];
    
    NSString * signature = signaturePolicyDic[@"signature"];
    NSString * policy = signaturePolicyDic[@"policy"];
    NSString * bucket = signaturePolicyDic[@"bucket"];
    
    __weak typeof(self)weakSelf = self;
    UMUUploaderManager *manager = [UMUUploaderManager managerWithBucket:bucket];
    [manager uploadWithFile:fileData policy:policy signature:signature progressBlock:^(float percent, long long requestDidSendBytes) {
        NSLog(@"%f",percent);
        dispatch_async(dispatch_get_main_queue(), ^() {
            weakSelf.pv.progress = percent;
        });
        
    } completeBlock:^(NSError *error, NSDictionary *result, BOOL completed) {
        dispatch_async(dispatch_get_main_queue(), ^() {
            UIAlertView * alert;
            if (completed) {
                alert = [[UIAlertView alloc]initWithTitle:@"" message:@"上传成功" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
                NSLog(@"%@",result);
            }else {
                alert = [[UIAlertView alloc]initWithTitle:@"" message:@"上传失败" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
                NSLog(@"%@",error);
            }
            [alert show];
            
        });
    }];

    
}


- (IBAction)uploadFile:(id)sender {
    UpYun *uy = [[UpYun alloc] init];
    uy.successBlocker = ^(NSURLResponse *response, id responseData)
    {
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"" message:@"上传成功" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        NSLog(@"%@",responseData);
    };
    uy.failBlocker = ^(NSError * error)
    {
        NSString *message = [error.userInfo objectForKey:@"message"];
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"error" message:message delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
        NSLog(@"%@",error);
    };
    uy.progressBlocker = ^(CGFloat percent, int64_t requestDidSendBytes)
    {
        [_pv setProgress:percent];
    };
    
//    如果 sinature 由服务端生成，则需要实现signatureBlocker, 否则就不用初始化signatureBlocker
//    uy.signatureBlocker = ^(NSString *policy)
//    {
//        // 在这里进行服务端的sinature 获取
//        return @"";
//    };
    
    
    /**
     *	@brief	根据 UIImage 上传
     */
    UIImage * image = [UIImage imageNamed:@"image.jpg"];
//    [uy uploadFile:image saveKey:[self getSaveKey]];
//    [uy uploadFile:image saveKey:@"2016.jpg"];
    [uy uploadImage:image savekey:[self getSaveKey]];
    /**
     *	@brief	根据 文件路径 上传
     */
//    NSString* resourcePath = [[NSBundle mainBundle] resourcePath];
//    NSString* filePath = [resourcePath stringByAppendingPathComponent:@"fileTest.file"];
//    [uy uploadFile:filePath saveKey:[self getSaveKey]];
    
    /**
     *	@brief	根据 NSDate  上传
     */
//    NSData * fileData = [NSData dataWithContentsOfFile:filePath];
//    [uy uploadFile:fileData saveKey:[self getSaveKey]];
    
}

-(NSString * )getSaveKey {
    /**
     *	@brief	方式1 由开发者生成saveKey
     */
    NSDate *d = [NSDate date];
    return [NSString stringWithFormat:@"/%d/%d/%.0f.jpg",[self getYear:d],[self getMonth:d],[[NSDate date] timeIntervalSince1970]];
    
    /**
     *	@brief	方式2 由服务器生成saveKey
     */
//    return [NSString stringWithFormat:@"/{year}/{mon}/{filename}{.suffix}"];
    
    /**
     *	@brief	更多方式 参阅 http://wiki.upyun.com/index.php?title=Policy_%E5%86%85%E5%AE%B9%E8%AF%A6%E8%A7%A3
     */

}

- (int)getYear:(NSDate *) date{
    NSDateFormatter *formatter =[[NSDateFormatter alloc] init];
    [formatter setTimeStyle:NSDateFormatterMediumStyle];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSInteger unitFlags = NSYearCalendarUnit;
    NSDateComponents *comps = [calendar components:unitFlags fromDate:date];
    int year=[comps year];
    return year;
}

- (int)getMonth:(NSDate *) date{
    NSDateFormatter *formatter =[[NSDateFormatter alloc] init];
    [formatter setTimeStyle:NSDateFormatterMediumStyle];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSInteger unitFlags = NSMonthCalendarUnit;
    NSDateComponents *comps = [calendar components:unitFlags fromDate:date];
    int month = [comps month];
    return month;
}


/**
 *  根据文件信息生成Signature\Policy\bucket (安全起见，以下算法应在服务端完成)
 *
 *  @param paramaters 文件信息
 *
 *  @return
 */
- (NSDictionary *)constructingSignatureAndPolicyWithFileInfo:(NSDictionary *)fileInfo
{
#warning 您需要加上自己的bucket和secret
    NSString * bucket = @"test654123";
    NSString * secret = @"0/8/1gPFWUQWGcfjFn6Vsn3VWDc=";
    
    NSMutableDictionary * mutableDic = [[NSMutableDictionary alloc]initWithDictionary:fileInfo];
    [mutableDic setObject:@(ceil([[NSDate date] timeIntervalSince1970])+60) forKey:@"expiration"];//设置授权过期时间
    [mutableDic setObject:[NSString stringWithFormat:@"/test/%@.jpeg",@"fileName"] forKey:@"path"];//设置保存路径
    /**
     *  这个 mutableDic 可以塞入其他可选参数 见：http://docs.upyun.com/api/form_api/#Policy%e5%86%85%e5%ae%b9%e8%af%a6%e8%a7%a3
     */
    NSString * signature = @"";
    NSArray * keys = [mutableDic allKeys];
    keys= [keys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString * key in keys) {
        NSString * value = mutableDic[key];
        signature = [NSString stringWithFormat:@"%@%@%@",signature,key,value];
    }
    signature = [signature stringByAppendingString:secret];
    
    return @{@"signature":[signature MD5],
             @"policy":[self dictionaryToJSONStringBase64Encoding:mutableDic],
             @"bucket":bucket};
}

- (NSString *)dictionaryToJSONStringBase64Encoding:(NSDictionary *)dic
{
    id paramesData = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:paramesData
                                                 encoding:NSUTF8StringEncoding];
    return [jsonString Base64encode];
}




@end
