//
//  KxSambaProvider.h
//  kxsmb project
//  https://github.com/kolyvan/kxsmb/
//
//  Created by Kolyvan on 28.03.13.
//

/*
 Copyright (c) 2013 Konstantin Bukreev All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Foundation/Foundation.h>

extern NSString * const KxSMBErrorDomain;

typedef enum {
    
    KxSMBErrorUnknown,
    KxSMBErrorInvalidArg,
    KxSMBErrorInvalidProtocol,
    KxSMBErrorOutOfMemory,
    KxSMBErrorPermissionDenied,    
    KxSMBErrorInvalidPath,
    KxSMBErrorPathIsNotDir,
    KxSMBErrorPathIsDir,
    KxSMBErrorWorkgroupNotFound,
    KxSMBErrorShareDoesNotExist,
    KxSMBErrorItemAlreadyExists,

} KxSMBError;

typedef enum {
    
    KxSMBItemTypeUnknown,
    KxSMBItemTypeWorkgroup,
    KxSMBItemTypeServer,
    KxSMBItemTypeFileShare,
    KxSMBItemTypePrinter,
    KxSMBItemTypeComms,
    KxSMBItemTypeIPC,
    KxSMBItemTypeDir,
    KxSMBItemTypeFile,
    KxSMBItemTypeLink,    
    
} KxSMBItemType;

typedef void (^KxSMBBlock)(id result);

@interface KxSMBItemStat : NSObject
@property(readonly, nonatomic, strong) NSDate *lastModified;
@property(readonly, nonatomic, strong) NSDate *lastAccess;
@property(readonly, nonatomic) long size;
@property(readonly, nonatomic) long mode;
@end

@interface KxSMBItem : NSObject
@property(readonly, nonatomic) KxSMBItemType type;
@property(readonly, nonatomic, strong) NSString *path;
@property(readonly, nonatomic, strong) KxSMBItemStat *stat;
@end

@class KxSMBItemFile;

@interface KxSMBItemTree : KxSMBItem
- (void) fetchItems: (KxSMBBlock) block;
- (id) fetchItems;
- (id) createFileWithName:(NSString *) name;
- (void) removeWithName: (NSString *) name block: (KxSMBBlock) block;
- (id) removeWithName: (NSString *) name;
@end

@interface KxSMBItemFile : KxSMBItem

- (void) close;

- (void)readDataOfLength:(NSUInteger)length block:(KxSMBBlock) block;
- (id)readDataOfLength:(NSUInteger)length;

- (void)readDataToEndOfFile:(KxSMBBlock) block;
- (id)readDataToEndOfFile;

- (void)seekToFileOffset:(off_t)offset whence:(NSInteger)whence block:(KxSMBBlock) block;
- (id)seekToFileOffset:(off_t)offset whence:(NSInteger)whence;

- (void)writeData:(NSData *)data block:(KxSMBBlock) block;
- (id)writeData:(NSData *)data;

@end

@interface KxSMBAuth : NSObject
@property (readwrite, nonatomic, strong) NSString *workgroup;
@property (readwrite, nonatomic, strong) NSString *username;
@property (readwrite, nonatomic, strong) NSString *password;

+ (id) smbAuthWorkgroup: (NSString *)workgroup
               username: (NSString *)username
               password: (NSString *)password;
@end

@protocol KxSMBProviderDelegate <NSObject>
- (KxSMBAuth *) smbAuthForServer: (NSString *) server
                       withShare: (NSString *) share;
@end

@interface KxSMBProvider : NSObject

@property (readwrite, nonatomic, weak) id<KxSMBProviderDelegate> delegate;

+ (id) sharedSmbProvider;

- (void) fetchAtPath: (NSString *) path block: (KxSMBBlock) block;
- (id) fetchAtPath: (NSString *) path;

- (id) createFileAtPath:(NSString *) path;

- (void) removeAtPath: (NSString *) path block: (KxSMBBlock) block;
- (id) removeAtPath: (NSString *) path;

@end
