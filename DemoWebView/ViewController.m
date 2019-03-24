//
//  ViewController.m
//  DemoWebView
//
//  Created by lam on 2019/3/16.
//  Copyright © 2019 lam. All rights reserved.
//

#import "ViewController.h"
#import <WebViewJavascriptBridge/WebViewJavascriptBridge.h>
#import <AFNetworking.h>
#import <SDWebImageManager.h>
#import "imageInfo.h"
#import "videoInfo.h"


@interface ViewController ()<WKUIDelegate>
@property (nonatomic, copy)NSString *detailID;
@property (nonatomic, copy)NSMutableString *requestUrlString;
@property (weak, nonatomic) IBOutlet WKWebView *webView;
@property (nonatomic, strong) WebViewJavascriptBridge *bridge;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [WebViewJavascriptBridge enableLogging];
    
    [_webView setBackgroundColor:UIColor.yellowColor];
    _webView.UIDelegate = self;
    _bridge = [WebViewJavascriptBridge bridgeForWebView:_webView];
    [_bridge disableJavscriptAlertBoxSafetyTimeout];
    
    
    [self setupRequest];
}

- (void)setupRequest {
    
    //  self.detailID = @"AQ72N9QG00051CA1";//一张图片
    //  self.detailID = @"AQ4RPLHG00964LQ9";//多张图片
    self.detailID = @"EAAV21P9000181BR";
    
    NSString *urlStr = [NSString stringWithFormat:@"http://c.m.163.com/nc/article/%@/full.html", self.detailID];
    
    //获取新闻内容详情
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager GET:urlStr parameters:nil progress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self setupWebViewByData:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"error == %@",error);
    }];
}
    
- (void)setupWebViewByData:(id)data {
    
    if (data!= nil) {
        //解析的字典
        NSDictionary *dic = (NSMutableDictionary *)data;
        NSDictionary *bodyDic = [dic objectForKey:_detailID];
        NSMutableString *bodyStr = [[NSMutableString alloc] initWithString:[bodyDic objectForKey:@"body"]];
        
        //写一段接收主标题的html字符串,直接拼接到字符串
        NSMutableString *titleStr= [bodyDic objectForKey:@"title"];
        NSMutableString *sourceStr = [bodyDic objectForKey:@"source"];
        NSMutableString *ptimeStr = [bodyDic objectForKey:@"ptime"];
        
        NSMutableString *allTitleStr =[NSMutableString stringWithString:@"<style type='text/css'> p.thicker{font-weight: 900}p.light{font-weight: 0}p{font-size: 108%}h2 {font-size: 120%}h3 {font-size: 80%}</style> <h2 class = 'thicker'>title_placeholder</h2><h3>source_placeholder    ptime_placeholder</h3>"];
        
        [allTitleStr replaceOccurrencesOfString:@"title_placeholder" withString:titleStr options:NSCaseInsensitiveSearch range:[allTitleStr rangeOfString:@"title_placeholder"]];
        [allTitleStr replaceOccurrencesOfString:@"ptime_placeholder" withString:ptimeStr options:NSCaseInsensitiveSearch range:[allTitleStr rangeOfString:@"ptime_placeholder"]];
        [allTitleStr replaceOccurrencesOfString:@"source_placeholder" withString:sourceStr options:NSCaseInsensitiveSearch range:[allTitleStr rangeOfString:@"source_placeholder"]];
        
        NSArray *imageArray = [bodyDic objectForKey:@"img"];
        NSArray *videoArray = [bodyDic objectForKey:@"video"];
        if ([videoArray count]) {
            NSLog(@"这个新闻里面有视频或者音频---");
            NSMutableArray *videos = [NSMutableArray arrayWithCapacity:[videoArray count]];
            for (NSDictionary *videoDic in videoArray) {
                videoInfo *videoin = [[videoInfo alloc] initWithInfo:videoDic];
                [videos addObject:videoin];
                NSRange range = [bodyStr rangeOfString:videoin.ref];
                NSString *videoStr = [NSString stringWithFormat:@"<embed height='50' width='280' src='%@' />",videoin.url_mp4];
                [bodyStr replaceOccurrencesOfString:videoin.ref withString:videoStr options:NSCaseInsensitiveSearch range:range];
            }
            
        }
        if ([imageArray count]==0) {
            NSLog(@"新闻没图片");
            NSString * str5 = [allTitleStr stringByAppendingString:bodyStr];
            [_webView loadHTMLString:str5 baseURL:[[NSURL URLWithString:_requestUrlString] baseURL]];
            
        }else{
            NSLog(@"新闻内容里面有图片");
            
            NSMutableArray *images = [NSMutableArray arrayWithCapacity:[imageArray count]];
            
            for (NSDictionary *d in imageArray) {
                
                imageInfo *info = [[imageInfo alloc] initWithInfo:d];//kvc
                [images addObject:info];
                NSRange range = [bodyStr rangeOfString:info.ref];
                NSArray *wh = [info.pixel componentsSeparatedByString:@"*"];
                CGFloat width = [[wh objectAtIndex:0] floatValue];
                
                CGFloat rate = (self.view.bounds.size.width-15)/ width;
                CGFloat height = [[wh objectAtIndex:1] floatValue];
                CGFloat newWidth = width * rate;
                CGFloat newHeight = height *rate;
                
                NSString *imageStr = [NSString stringWithFormat:@"<img src = 'loading' id = '%@' width = '%.0f' height = '%.0f' hspace='0.0' vspace='5'>",[self replaceUrlSpecialString:info.src],newWidth,newHeight];
                [bodyStr replaceOccurrencesOfString:info.ref withString:imageStr options:NSCaseInsensitiveSearch range:range];
            }
            
            
            NSString * str5 = [allTitleStr stringByAppendingString:bodyStr];
            
            //获取Html的内容
            NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"webViewHtml" ofType:@"html"];
            NSMutableString *appHtml = [NSMutableString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
            //替换p标签的内容
            NSRange range = [appHtml rangeOfString:@"<p>mainnews</p>"];
            [appHtml replaceOccurrencesOfString:@"<p>mainnews</p>" withString:str5 options:NSCaseInsensitiveSearch range:range];
            //加载Html文本传
            NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
            [_webView loadHTMLString:appHtml baseURL:baseURL];
            //下载图片保存到沙盒 & WKWebView使用JS交互加载本地图片
            [self getImageFromDownloaderOrDiskByImageUrlArray:imageArray];
        }
    }
}
    
    
- (void)getImageFromDownloaderOrDiskByImageUrlArray:(NSArray *)imageArray {
    
    SDWebImageManager *imageManager = [SDWebImageManager sharedManager];
    [[SDWebImageManager sharedManager] setCacheKeyFilter:^(NSURL *url) {
        NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
        NSString *str = [self replaceUrlSpecialString:[components.URL absoluteString]];
        return str;
    }];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    //SDWebImage默认的缓存路径
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"default/com.hackemist.SDWebImageCache.default"];
    
    __weak typeof(self) weakSelf = self;

    for (NSDictionary *d in imageArray) {
        
        NSMutableArray *images = [NSMutableArray arrayWithCapacity:[imageArray count]];
        imageInfo *info = [[imageInfo alloc] initWithInfo:d];//kvc
        [images addObject:info];
        NSURL *imageUrl = [NSURL URLWithString:info.src];
        [imageManager diskImageExistsForURL:imageUrl completion:^(BOOL isInCache) {
           
            if (isInCache) {
                NSString *cacheKey = [imageManager cacheKeyForURL:imageUrl];
                NSString *cacheImagePath = [imageManager.imageCache cachePathForKey:cacheKey inPath:filePath];

                NSString *content = [NSString stringWithFormat:@"replaceimage%@,%@",[weakSelf replaceUrlSpecialString:info.src],cacheImagePath];
                
                //调用JS替换img的src，才能显示图片
                [self.bridge callHandler:@"replaceimage" data:content responseCallback:^(id responseData) {
                    
                }];
            } else {
                
                __weak typeof(self) weakSelf = self;
                SDWebImageDownloader *down = [SDWebImageDownloader sharedDownloader];
                
                [down downloadImageWithURL:imageUrl options:SDWebImageDownloaderHighPriority progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
                                        
                } completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
                    
                    if (image && finished) {//如果下载成功
                         
                        NSString *cacheKey = [imageManager cacheKeyForURL:imageUrl];
                        NSString *imagePaths = [imageManager.imageCache cachePathForKey:cacheKey inPath:filePath];
                        
                        //缓存图片到沙盒
                        [[SDImageCache sharedImageCache] storeImage:image imageData:data forKey:cacheKey toDisk:YES completion:^{
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                
                                NSString *content = [NSString stringWithFormat:@"replaceimage%@,%@",[weakSelf replaceUrlSpecialString:info.src],imagePaths];
                                //调用JS替换img的src，才能显示图片
                                [self.bridge callHandler:@"replaceimage" data:content responseCallback:^(id responseData) {
                                    
                                }];
                            });
                        }];

                    }else {
                        
                    }
                }];  
            }
        }];
    }
}
    
- (NSString *)replaceUrlSpecialString:(NSString *)string {
    return [string stringByReplacingOccurrencesOfString:@"/"withString:@"_"];
}
    
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
    
}
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler{
    //    DLOG(@"msg = %@ frmae = %@",message,frame);
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }])];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }])];
    [self presentViewController:alertController animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = defaultText;
    }];
    [alertController addAction:([UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(alertController.textFields[0].text?:@"");
    }])];
    
    [self presentViewController:alertController animated:YES completion:nil];
}
    
    
@end
