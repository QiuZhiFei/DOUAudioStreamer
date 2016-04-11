/* vim: set ft=objc fenc=utf-8 sw=2 ts=2 et: */
/*
 *  DOUAudioStreamer - A Core Audio based streaming audio player for iOS/Mac:
 *
 *      https://github.com/douban/DOUAudioStreamer
 *
 *  Copyright 2013-2016 Douban Inc.  All rights reserved.
 *
 *  Use and distribution licensed under the BSD license.  See
 *  the LICENSE file for full text.
 *
 *  Authors:
 *      Chongyu Zhu <i@lembacon.com>
 *
 */

#import "DOUSimpleHTTPRequest.h"

#import <AFNetworking/AFNetworking.h>
#import <AFNetworking/AFURLRequestSerialization.h>
#import <AFNetworking/AFURLResponseSerialization.h>

@interface DOUSimpleHTTPRequest () {
@private
  DOUSimpleHTTPRequestCompletedBlock _completedBlock;
  DOUSimpleHTTPRequestProgressBlock _progressBlock;
  DOUSimpleHTTPRequestDidReceiveResponseBlock _didReceiveResponseBlock;
  DOUSimpleHTTPRequestDidReceiveDataBlock _didReceiveDataBlock;
  
  NSString *_userAgent;
  NSTimeInterval _timeoutInterval;
  
  CFHTTPMessageRef _message;
  CFReadStreamRef _responseStream;
  
  NSDictionary *_responseHeaders;
  NSMutableData *_responseData;
  NSString *_responseString;
  
  NSInteger _statusCode;
  NSString *_statusMessage;
  BOOL _failed;
  
  CFAbsoluteTime _startedTime;
  NSUInteger _downloadSpeed;
  
  NSUInteger _responseContentLength;
  NSUInteger _receivedLength;
  
  AFHTTPSessionManager *_sessionManager;
  NSURLSessionDataTask *_task;
  NSURL *_url;
}
@end

@implementation DOUSimpleHTTPRequest

@synthesize timeoutInterval = _timeoutInterval;
@synthesize userAgent = _userAgent;

@synthesize responseData = _responseData;

@synthesize responseHeaders = _responseHeaders;
@synthesize responseContentLength = _responseContentLength;
@synthesize statusCode = _statusCode;
@synthesize failed = _failed;
@synthesize downloadSpeed = _downloadSpeed;

@synthesize completedBlock = _completedBlock;
@synthesize progressBlock = _progressBlock;
@synthesize didReceiveResponseBlock = _didReceiveResponseBlock;
@synthesize didReceiveDataBlock = _didReceiveDataBlock;

+ (instancetype)requestWithURL:(NSURL *)url
{
  if (url == nil) {
    return nil;
  }
  
  return [[[self class] alloc] initWithURL:url];
}

- (instancetype)initWithURL:(NSURL *)url
{
  self = [super init];
  if (self) {
    _userAgent = [[self class] defaultUserAgent];
    _timeoutInterval = [[self class] defaultTimeoutInterval];
    _url = url;
    
    typeof(self) __weak wself = self;
    
    
    _sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@""]];
    
    _sessionManager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
    
    
    [_sessionManager setDataTaskDidReceiveDataBlock:^(NSURLSession * _Nonnull session, NSURLSessionDataTask * _Nonnull dataTask, NSData * _Nonnull data) {
      [wself _invokeDidReceiveDataBlockWithData:data];
    }];
    
    [_sessionManager setDataTaskDidReceiveResponseBlock:^NSURLSessionResponseDisposition(NSURLSession * _Nonnull session, NSURLSessionDataTask * _Nonnull dataTask, NSURLResponse * _Nonnull response) {
      typeof(self) __strong sself = wself;
      if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        sself->_responseHeaders = [(NSHTTPURLResponse *)response allHeaderFields];
      }
      [wself _checkResponseContentLength];
      [wself _invokeDidReceiveResponseBlock];
      return NSURLSessionResponseAllow;
    }];

//    NSMutableURLRequest *request = [_sessionManager.requestSerializer requestWithMethod:@"GET"
//                                                                              URLString:url.absoluteString
//                                                                             parameters:nil
//                                                                                  error:NULL];
//    _task = [_sessionManager dataTaskWithRequest:request
//                                  uploadProgress:NULL
//                                downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
//                                  if (wself.progressBlock) {
//                                    wself.progressBlock(downloadProgress.fractionCompleted);
//                                  }
//                                } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
//                                  
//                                  typeof(self) __strong sself = wself;
//                                  
//                                  if (sself) {
//                                    if (error) {
//                                      sself->_failed = YES;
//                                      NSLog(@"DOUAudioStreamer error == %@  \n %@", error.description, response);
//                                    }
//                                    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
//                                      sself->_statusCode = [(NSHTTPURLResponse *)response statusCode];
//                                    }
//                                    if (sself.completedBlock) {
//                                      sself.completedBlock();
//                                    }
//                                  }
//                                  
//                                }];
  }
  
  return self;
}

- (void)start
{
  _sessionManager.requestSerializer.timeoutInterval = _timeoutInterval;
  [_sessionManager.requestSerializer setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
  if (_host != nil) {
    [_sessionManager.requestSerializer setValue:_host forHTTPHeaderField:@"Host"];
  }
  NSMutableURLRequest *request = [_sessionManager.requestSerializer requestWithMethod:@"GET"
                                                                            URLString:_url.absoluteString
                                                                           parameters:nil
                                                                                error:NULL];
  [request setValue:@"mr7.doubanio.com" forHTTPHeaderField:@"Host"];
  typeof(self) __weak wself = self;
  _task = [_sessionManager dataTaskWithRequest:request
                                uploadProgress:NULL
                              downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                                if (wself.progressBlock) {
                                  wself.progressBlock(downloadProgress.fractionCompleted);
                                }
                              } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                
                                typeof(self) __strong sself = wself;
                                
                                if (sself) {
                                  if (error) {
                                    sself->_failed = YES;
                                    NSLog(@"DOUAudioStreamer error == %@  \n %@", error.description, response);
                                  }
                                  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                                    sself->_statusCode = [(NSHTTPURLResponse *)response statusCode];
                                  }
                                  if (sself.completedBlock) {
                                    sself.completedBlock();
                                  }
                                }
                                
                              }];
  _startedTime = CFAbsoluteTimeGetCurrent();
  [_task resume];
}

- (void)cancel
{
  [_task cancel];
}

#pragma mark - Private Methods

- (void)dealloc
{
  [_task cancel];
}

+ (NSTimeInterval)defaultTimeoutInterval
{
  return 20.0;
}

+ (NSString *)defaultUserAgent
{
  static NSString *defaultUserAgent = nil;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appName = [infoDict objectForKey:@"CFBundleName"];
    NSString *shortVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
    NSString *bundleVersion = [infoDict objectForKey:@"CFBundleVersion"];
    
    NSString *deviceName = nil;
    NSString *systemName = nil;
    NSString *systemVersion = nil;
    
#if TARGET_OS_IPHONE
    
    UIDevice *device = [UIDevice currentDevice];
    deviceName = [device model];
    systemName = [device systemName];
    systemVersion = [device systemVersion];
    
#else /* TARGET_OS_IPHONE */
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    SInt32 versionMajor, versionMinor, versionBugFix;
    Gestalt(gestaltSystemVersionMajor, &versionMajor);
    Gestalt(gestaltSystemVersionMinor, &versionMinor);
    Gestalt(gestaltSystemVersionBugFix, &versionBugFix);
#pragma clang diagnostic pop
    
    int mib[2] = { CTL_HW, HW_MODEL };
    size_t len = 0;
    sysctl(mib, 2, NULL, &len, NULL, 0);
    char *hw_model = malloc(len);
    sysctl(mib, 2, hw_model, &len, NULL, 0);
    deviceName = [NSString stringWithFormat:@"Macintosh %s", hw_model];
    free(hw_model);
    
    systemName = @"Mac OS X";
    systemVersion = [NSString stringWithFormat:@"%u.%u.%u", versionMajor, versionMinor, versionBugFix];
    
#endif /* TARGET_OS_IPHONE */
    
    NSString *locale = [[NSLocale currentLocale] localeIdentifier];
    defaultUserAgent = [NSString stringWithFormat:@"%@ %@ build %@ (%@; %@ %@; %@)", appName, shortVersion, bundleVersion, deviceName, systemName, systemVersion, locale];
  });
  
  return defaultUserAgent;
}

- (void)_invokeCompletedBlock
{
  @synchronized(self) {
    if (_completedBlock != NULL) {
      _completedBlock();
    }
  }
}

- (void)_invokeProgressBlockWithDownloadProgress:(double)downloadProgress
{
  @synchronized(self) {
    if (_progressBlock != NULL) {
      _progressBlock(downloadProgress);
    }
  }
}

- (void)_invokeDidReceiveResponseBlock
{
  @synchronized(self) {
    if (_didReceiveResponseBlock != NULL) {
      _didReceiveResponseBlock();
    }
  }
}

- (void)_invokeDidReceiveDataBlockWithData:(NSData *)data
{
  @synchronized(self) {
    if (_didReceiveDataBlock == NULL) {
      if (_responseData == nil) {
        _responseData = [NSMutableData data];
      }
      [_responseData appendData:data];
    }
    else {
      _didReceiveDataBlock(data);
    }
  }
}

- (void)_checkResponseContentLength
{
  if (_responseHeaders == nil) {
    return;
  }
  
  NSString *string = [_responseHeaders objectForKey:@"Content-Length"];
  if (string == nil) {
    return;
  }
  
  _responseContentLength = (NSUInteger)[string integerValue];
}

- (NSString *)responseString
{
  if (_responseData == nil) {
    return nil;
  }
  
  if (_responseString == nil) {
    _responseString = [[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding];
  }
  
  return _responseString;
}

- (void)_updateDownloadSpeed
{
  _downloadSpeed = _receivedLength / (CFAbsoluteTimeGetCurrent() - _startedTime);
}

@end
