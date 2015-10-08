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
    KxSMBErrorAccessDenied,
    KxSMBErrorInvalidPath,
    KxSMBErrorPathIsNotDir,
    KxSMBErrorPathIsDir,
    KxSMBErrorWorkgroupNotFound,
    KxSMBErrorShareDoesNotExist,
    KxSMBErrorItemAlreadyExists,
    KxSMBErrorDirNotEmpty,
    KxSMBErrorFileIO,
    KxSMBErrorConnRefused,
    KxSMBErrorOpNotPermited,

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

@class KxSMBItem;
@class KxSMBAuth;

typedef void (^KxSMBBlock)(id result);
typedef void (^KxSMBBlockProgress)(KxSMBItem *item, long transferred, BOOL *stop);

@interface KxSMBItemStat : NSObject
@property(readonly, nonatomic, strong) NSDate *lastModified;
@property(readonly, nonatomic, strong) NSDate *lastAccess;
@property(readonly, nonatomic, strong) NSDate *creationTime;
@property(readonly, nonatomic) SInt64 size;
@property(readonly, nonatomic) UInt16 mode;
@end

@interface KxSMBItem : NSObject
@property(readonly, nonatomic) KxSMBItemType type;
@property(readonly, nonatomic, strong) NSString *path;
@property(readonly, nonatomic, strong) KxSMBItemStat *stat;
@property(readonly, nonatomic, strong) KxSMBAuth *auth;
@end

@class KxSMBItemFile;

@interface KxSMBItemTree : KxSMBItem

- (void) fetchItems:(KxSMBBlock)block;

- (id) fetchItems;

- (void) createFileWithName:(NSString *)name
                  overwrite:(BOOL)overwrite
                      block:(KxSMBBlock)block;

- (id) createFileWithName:(NSString *)name
                overwrite:(BOOL)overwrite;

- (void) removeWithName:(NSString *)name
                  block:(KxSMBBlock)block;

- (id) removeWithName:(NSString *)name;

@end

@interface KxSMBItemFile : KxSMBItem

- (void) close;

- (void)readDataOfLength:(NSUInteger)length
                   block:(KxSMBBlock)block;

- (id)readDataOfLength:(NSUInteger)length;

- (void)readDataToEndOfFile:(KxSMBBlock)block;

- (id)readDataToEndOfFile;

- (void)seekToFileOffset:(off_t)offset
                  whence:(NSInteger)whence
                   block:(KxSMBBlock)block;

- (id)seekToFileOffset:(off_t)offset
                whence:(NSInteger)whence;

- (void)writeData:(NSData *)data
            block:(KxSMBBlock)block;

- (id)writeData:(NSData *)data;

@end

@interface KxSMBAuth : NSObject
@property (readwrite, nonatomic, strong) NSString *workgroup;
@property (readwrite, nonatomic, strong) NSString *username;
@property (readwrite, nonatomic, strong) NSString *password;

+ (instancetype) smbAuthWorkgroup:(NSString *)workgroup
                         username:(NSString *)username
                         password:(NSString *)password;

@end

@protocol KxSMBProviderDelegate <NSObject>

- (KxSMBAuth *) smbRequestAuthServer:(NSString *)server
                               share:(NSString *)share
                           workgroup:(NSString *)workgroup
                           username:(NSString *)username;
@end

// smbc_share_mode
typedef NS_ENUM(NSUInteger, KxSMBConfigShareMode) {
    
    KxSMBConfigShareModeDenyDOS     = 0,
    KxSMBConfigShareModeDenyAll     = 1,
    KxSMBConfigShareModeDenyWrite   = 2,
    KxSMBConfigShareModeDenyRead    = 3,
    KxSMBConfigShareModeDenyNone    = 4,
    KxSMBConfigShareModeDenyFCB     = 7,
};

// smbc_smb_encrypt_level
typedef NS_ENUM(NSUInteger, KxSMBConfigEncryptLevel) {
    
    KxSMBConfigEncryptLevelNone      = 0,
    KxSMBConfigEncryptLevelRequest   = 1,
    KxSMBConfigEncryptLevelRequire   = 2,
};

@interface KxSMBConfig : NSObject
@property (readwrite, nonatomic) NSUInteger timeout;
@property (readwrite, nonatomic) NSUInteger debugLevel;
@property (readwrite, nonatomic) BOOL debugToStderr;
@property (readwrite, nonatomic) BOOL fullTimeNames;
@property (readwrite, nonatomic) KxSMBConfigShareMode shareMode;
@property (readwrite, nonatomic) KxSMBConfigEncryptLevel encryptionLevel;
@property (readwrite, nonatomic) BOOL caseSensitive;
@property (readwrite, nonatomic) NSUInteger browseMaxLmbCount;
@property (readwrite, nonatomic) BOOL urlEncodeReaddirEntries;
@property (readwrite, nonatomic) BOOL oneSharePerServer;
@property (readwrite, nonatomic) BOOL useKerberos;
@property (readwrite, nonatomic) BOOL fallbackAfterKerberos;
@property (readwrite, nonatomic) BOOL noAutoAnonymousLogin;
@property (readwrite, nonatomic) BOOL useCCache;
@property (readwrite, nonatomic) BOOL useNTHash;
@property (readwrite, nonatomic, strong) NSString *netbiosName;
@property (readwrite, nonatomic, strong) NSString *workgroup;
@property (readwrite, nonatomic, strong) NSString *username;
@end

@interface KxSMBProvider : NSObject

@property (readwrite, nonatomic, weak) id<KxSMBProviderDelegate> delegate;
@property (readwrite, nonatomic, strong) KxSMBConfig *config;

+ (instancetype) sharedSmbProvider;

- (void) fetchAtPath:(NSString *)path
                auth:(KxSMBAuth *)auth
               block:(KxSMBBlock)block;

- (id) fetchAtPath:(NSString *)path
              auth:(KxSMBAuth *)auth;

- (void) createFileAtPath:(NSString *)path
                overwrite:(BOOL)overwrite
                     auth:(KxSMBAuth *)auth
                    block:(KxSMBBlock)block;

- (id) createFileAtPath:(NSString *)path
              overwrite:(BOOL)overwrite
                   auth:(KxSMBAuth *)auth;

- (void) createFolderAtPath:(NSString *)path
                       auth:(KxSMBAuth *)auth
                      block:(KxSMBBlock)block;

- (id) createFolderAtPath:(NSString *)path
                     auth:(KxSMBAuth *)auth;

- (void) removeAtPath:(NSString *)path
                 auth:(KxSMBAuth *)auth
                block:(KxSMBBlock)block;

- (id) removeAtPath:(NSString *)path
               auth:(KxSMBAuth *)auth;

- (void) copySMBPath:(NSString *)smbPath
           localPath:(NSString *)localPath
           overwrite:(BOOL)overwrite
                auth:(KxSMBAuth *)auth
               block:(KxSMBBlock)block;

- (void) copyLocalPath:(NSString *)localPath
               smbPath:(NSString *)smbPath
             overwrite:(BOOL)overwrite
                  auth:(KxSMBAuth *)auth
                 block:(KxSMBBlock)block;

- (void) copySMBPath:(NSString *)smbPath
           localPath:(NSString *)localPath
           overwrite:(BOOL)overwrite
                auth:(KxSMBAuth *)auth
            progress:(KxSMBBlockProgress)progress
               block:(KxSMBBlock)block;

- (void) copyLocalPath:(NSString *)localPath
               smbPath:(NSString *)smbPath
             overwrite:(BOOL)overwrite
                  auth:(KxSMBAuth *)auth
              progress:(KxSMBBlockProgress)progress
                 block:(KxSMBBlock)block;

- (void) removeFolderAtPath:(NSString *)path
                       auth:(KxSMBAuth *)auth
                      block:(KxSMBBlock)block;

- (void) renameAtPath:(NSString *)oldPath
              newPath:(NSString *)newPath
                 auth:(KxSMBAuth *)auth
                block:(KxSMBBlock)block;

// without auth (compatible)

- (void) fetchAtPath:(NSString *)path
               block:(KxSMBBlock)block;

- (id) fetchAtPath:(NSString *)path;

- (void) createFileAtPath:(NSString *)path
                overwrite:(BOOL)overwrite
                    block:(KxSMBBlock)block;

- (id) createFileAtPath:(NSString *)path
              overwrite:(BOOL)overwrite;

- (void) createFolderAtPath:(NSString *)path
                      block:(KxSMBBlock)block;

- (id) createFolderAtPath:(NSString *)path;

- (void) removeAtPath:(NSString *)path
                block:(KxSMBBlock)block;

- (id) removeAtPath:(NSString *)path;

- (void) copySMBPath:(NSString *)smbPath
           localPath:(NSString *)localPath
           overwrite:(BOOL)overwrite
               block:(KxSMBBlock)block;

- (void) copyLocalPath:(NSString *)localPath
               smbPath:(NSString *)smbPath
             overwrite:(BOOL)overwrite
                 block:(KxSMBBlock)block;

- (void) copySMBPath:(NSString *)smbPath
           localPath:(NSString *)localPath
           overwrite:(BOOL)overwrite
            progress:(KxSMBBlockProgress)progress
               block:(KxSMBBlock)block;

- (void) copyLocalPath:(NSString *)localPath
               smbPath:(NSString *)smbPath
             overwrite:(BOOL)overwrite
              progress:(KxSMBBlockProgress)progress
                 block:(KxSMBBlock)block;

- (void) removeFolderAtPath:(NSString *)path
                      block:(KxSMBBlock)block;

- (void) renameAtPath:(NSString *)oldPath
              newPath:(NSString *)newPath
                block:(KxSMBBlock)block;

@end

@interface NSString (KxSMB)

- (NSString *) stringByAppendingSMBPathComponent: (NSString *) aString;

@end
