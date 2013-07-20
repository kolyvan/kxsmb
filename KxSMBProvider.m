//
//  KxSambaProvider.m
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


#import "KxSMBProvider.h"
#import "libsmbclient.h"
#import "talloc_stack.h"

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

NSString * const KxSMBErrorDomain = @"ru.kolyvan.KxSMB";

static NSString * KxSMBErrorMessage (KxSMBError errorCode)
{
    switch (errorCode) {
        case KxSMBErrorUnknown:             return NSLocalizedString(@"SMB Error", nil);
        case KxSMBErrorInvalidArg:          return NSLocalizedString(@"SMB Invalid argument", nil);
        case KxSMBErrorInvalidProtocol:     return NSLocalizedString(@"SMB Invalid protocol", nil);
        case KxSMBErrorOutOfMemory:         return NSLocalizedString(@"SMB Out of memory", nil);
        case KxSMBErrorPermissionDenied:    return NSLocalizedString(@"SMB Permission denied", nil);
        case KxSMBErrorInvalidPath:         return NSLocalizedString(@"SMB No such file or directory", nil);
        case KxSMBErrorPathIsNotDir:        return NSLocalizedString(@"SMB Not a directory", nil);
        case KxSMBErrorPathIsDir:           return NSLocalizedString(@"SMB Is a directory", nil);
        case KxSMBErrorWorkgroupNotFound:   return NSLocalizedString(@"SMB Workgroup not found", nil);
        case KxSMBErrorShareDoesNotExist:   return NSLocalizedString(@"SMB Share does not exist", nil);
        case KxSMBErrorItemAlreadyExists:   return NSLocalizedString(@"SMB Item already exists", nil);
        case KxSMBErrorDirNotEmpty:         return NSLocalizedString(@"SMB Directory not empty", nil);
        case KxSMBErrorFileIO:              return NSLocalizedString(@"SMB File I/O failure", nil);

    }
}

static NSError * mkKxSMBError(KxSMBError error, NSString *format, ...)
{
    NSDictionary *userInfo = nil;
    NSString *reason = nil;
    
    if (format) {
        
        va_list args;
        va_start(args, format);
        reason = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
    }
    
    if (reason) {
        
        userInfo = @{
                     NSLocalizedDescriptionKey : KxSMBErrorMessage(error),
                     NSLocalizedFailureReasonErrorKey : reason
                     };
        
    } else {
        
        userInfo = @{ NSLocalizedDescriptionKey : KxSMBErrorMessage(error) };
    }
    
    return [NSError errorWithDomain:KxSMBErrorDomain
                               code:error
                           userInfo:userInfo];
}

static KxSMBError errnoToSMBErr(int err)
{
    switch (err) {
        case EINVAL:    return KxSMBErrorInvalidArg;
        case ENOMEM:    return KxSMBErrorOutOfMemory;
        case EACCES:    return KxSMBErrorPermissionDenied;
        case ENOENT:    return KxSMBErrorInvalidPath;
        case ENOTDIR:   return KxSMBErrorPathIsNotDir;
        case EISDIR:    return KxSMBErrorPathIsDir;
        case EPERM:     return KxSMBErrorWorkgroupNotFound;
        case ENODEV:    return KxSMBErrorShareDoesNotExist;
        case EEXIST:    return KxSMBErrorItemAlreadyExists;
        case ENOTEMPTY: return KxSMBErrorDirNotEmpty;
        default:        return KxSMBErrorUnknown;
    }    
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

@implementation KxSMBAuth

+ (id) smbAuthWorkgroup: (NSString *)workgroup
               username: (NSString *)username
               password: (NSString *)password
{
    KxSMBAuth *auth = [[KxSMBAuth alloc] init];
    auth.workgroup = workgroup;
    auth.username = username;
    auth.password = password;
    return auth;
}

@end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

@interface KxSMBItemStat ()
@property(readwrite, nonatomic, strong) NSDate *lastModified;
@property(readwrite, nonatomic, strong) NSDate *lastAccess;
@property(readwrite, nonatomic) long size;
@property(readwrite, nonatomic) long mode;
@end

@implementation KxSMBItemStat
@end

@implementation KxSMBItem

- (id) initWithType: (KxSMBItemType) type
               path: (NSString *) path
               stat: (KxSMBItemStat *)stat
{
    self = [super init];
    if (self) {
        _type = type;
        _path = path;
        _stat = stat;        
    }
    return self;
}

- (NSString *) description
{
    NSString *stype = @"";
    
    switch (_type) {
            
        case KxSMBItemTypeUnknown:   stype = @"?"; break;
        case KxSMBItemTypeWorkgroup: stype = @"group"; break;
        case KxSMBItemTypeServer:    stype = @"server"; break;
        case KxSMBItemTypeFileShare: stype = @"fileshare"; break;
        case KxSMBItemTypePrinter:   stype = @"printer"; break;
        case KxSMBItemTypeComms:     stype = @"comms"; break;
        case KxSMBItemTypeIPC:       stype = @"ipc"; break;
        case KxSMBItemTypeDir:       stype = @"dir"; break;
        case KxSMBItemTypeFile:      stype = @"file"; break;
        case KxSMBItemTypeLink:      stype = @"link"; break;
    }
    
    return [NSString stringWithFormat:@"<smb %@ '%@' %ld>",
            stype, _path, _stat.size];
}

@end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

static void my_smbc_get_auth_data_fn(const char *srv,
                                     const char *shr,
                                     char *workgroup, int wglen,
                                     char *username, int unlen,
                                     char *password, int pwlen);

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////


@interface KxSMBItemFile()
- (id) createFile:(BOOL)overwrite;
@end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

static KxSMBProvider *gSmbProvider;

@interface KxSMBProvider ()
@end

@implementation KxSMBProvider {
    
    dispatch_queue_t    _dispatchQueue;
}

+ (id) sharedSmbProvider
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSmbProvider = [[KxSMBProvider alloc] init];
    });
    return gSmbProvider;
}

- (id) init
{
    NSAssert(!gSmbProvider, @"singleton object");
    
    self = [super init];
    if (self) {
        
        _dispatchQueue  = dispatch_queue_create("KxSMBProvider", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void) dealloc
{    
    if (_dispatchQueue) {
        #if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
        dispatch_release(_dispatchQueue);
        #endif
        _dispatchQueue = NULL;
    }
}

#pragma mark - class methods

+ (SMBCCTX *) openSmbContext
{    
    SMBCCTX *smbContext = smbc_new_context();
	if (!smbContext)
		return NULL;
		
#ifdef DEBUG
    smbc_setDebug(smbContext, SAMBA_DEBUG_LEVEL);
#else
    smbc_setDebug(smbContext, 0);
#endif
    
	smbc_setTimeout(smbContext, 1000);
    smbc_setFunctionAuthData(smbContext, my_smbc_get_auth_data_fn);
        
	if (!smbc_init_context(smbContext)) {
		smbc_free_context(smbContext, NO);
		return NULL;
	}
    
    smbc_set_context(smbContext);
    return smbContext;
}

+ (void) closeSmbContext: (SMBCCTX *) smbContext
{
    if (smbContext) {
        
        // fixes warning: no talloc stackframe at libsmb/cliconnect.c:2637, leaking memory
        TALLOC_CTX *frame = talloc_stackframe();
        smbc_getFunctionPurgeCachedServers(smbContext)(smbContext);
        TALLOC_FREE(frame);
        
        smbc_free_context(smbContext, NO);
    }
}

+ (id) fetchTreeAtPath: (NSString *) path
{
    NSParameterAssert(path);    
    
    SMBCCTX *smbContext = [self openSmbContext];
    if (!smbContext) {
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable init SMB context (errno:%d)", nil), err);
    }
    
    id result = nil;
    
    SMBCFILE *smbFile = smbc_getFunctionOpendir(smbContext)(smbContext, path.UTF8String);
    if (smbFile) {
        
        NSMutableArray *ma = [NSMutableArray array];
        KxSMBItem *item;
        
        struct smbc_dirent *dirent;
        
        smbc_readdir_fn readdirFn = smbc_getFunctionReaddir(smbContext);
        
        while((dirent = readdirFn(smbContext, smbFile)) != NULL) {
            
            if (!dirent->name) continue;
            if (!strlen(dirent->name)) continue;
            if (dirent->name[0] == '.') continue;
            if (!strcmp(dirent->name, "IPC$")) continue;
            
            NSString *name = [NSString stringWithUTF8String:dirent->name];
            
            NSString *itemPath;
            if ([path characterAtIndex:path.length-1] == '/')
                itemPath = [path stringByAppendingString:name] ;
            else
                itemPath = [NSString stringWithFormat:@"%@/%@", path, name];
                        
            KxSMBItemStat *stat = nil;
            
            if (dirent->smbc_type != SMBC_WORKGROUP &&
                dirent->smbc_type != SMBC_SERVER) {
                
                id r = [self fetchStat:smbContext atPath:itemPath];
                if ([r isKindOfClass:[KxSMBItemStat class]]) {
                    stat = r;
                }
            }
            
            switch(dirent->smbc_type)
            {
                case SMBC_WORKGROUP:
                case SMBC_SERVER:
                    item = [[KxSMBItemTree alloc] initWithType:dirent->smbc_type
                                                          path:[NSString stringWithFormat:@"smb://%@", name]
                                                          stat:nil];
                    [ma addObject:item];
                    break;
                    
                case SMBC_FILE_SHARE:
                case SMBC_IPC_SHARE:                    
                case SMBC_DIR:                    
                    item = [[KxSMBItemTree alloc] initWithType:dirent->smbc_type
                                                          path:itemPath
                                                          stat:stat];
                    [ma addObject:item];
                    break;
                    
                case SMBC_FILE:
                    item = [[KxSMBItemFile alloc] initWithType:KxSMBItemTypeFile
                                                          path:itemPath
                                                          stat:stat];
                    [ma addObject:item];
                    break;
                
                    
                case SMBC_PRINTER_SHARE:
                case SMBC_COMMS_SHARE:
                case SMBC_LINK:                                       
                    item = [[KxSMBItem alloc] initWithType:dirent->smbc_type
                                                      path:itemPath
                                                      stat:stat];
                    [ma addObject:item];
                    break;
            }
        }
        
        smbc_getFunctionClose(smbContext)(smbContext, smbFile);        
        result = [ma copy];
        
    } else {
        
        const int err = errno;
        result = mkKxSMBError(errnoToSMBErr(err),
                              NSLocalizedString(@"Unable open dir:%@ (errno:%d)", nil), path, err);
    }
    
    [self closeSmbContext:smbContext];
    return result;
}

+ (id) fetchStat: (SMBCCTX *) smbContext
          atPath: (NSString *) path
{
    NSParameterAssert(smbContext);
    NSParameterAssert(path);
    
    struct stat st;
    int r = smbc_getFunctionStat(smbContext)(smbContext, path.UTF8String, &st);
    if (r < 0) {

        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable get stat:%@ (errno:%d)", nil), path, err);
    }
    
    KxSMBItemStat *stat = [[KxSMBItemStat alloc] init];
    stat.lastModified = [NSDate dateWithTimeIntervalSince1970: st.st_mtime];
    stat.lastAccess = [NSDate dateWithTimeIntervalSince1970: st.st_atime];
    stat.size = st.st_size;
    stat.mode = st.st_mode;    
    return stat;
    
}

+ (id) fetchAtPath: (NSString *) path
{
    NSParameterAssert(path);
    
    if (![path hasPrefix:@"smb://"]) {
        return mkKxSMBError(KxSMBErrorInvalidProtocol,
                            NSLocalizedString(@"Path:%@", nil), path);
    }

    NSString *sPath = [path substringFromIndex:@"smb://".length];
    
    if (!sPath.length)
        return [self fetchTreeAtPath:path];

    if ([sPath hasSuffix:@"/"])
        sPath = [sPath substringToIndex:sPath.length - 1];
    
    if (sPath.pathComponents.count == 1) {
 
        // smb:// or smb://server/ or smb://workgroup/
        return [self fetchTreeAtPath:path];
    }
    
    id result = nil;
    
    SMBCCTX *smbContext = [self openSmbContext];
    if (!smbContext) {
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable init SMB context (errno:%d)", nil), err);
    }
    
    result = [self fetchStat:smbContext atPath:path];
    
    if ([result isKindOfClass:[KxSMBItemStat class]]) {
        
        KxSMBItemStat *stat = result;
        
        if (S_ISDIR(stat.mode)) {
            
            result =  [self fetchTreeAtPath:path];
            
        } else if (S_ISREG(stat.mode)) {
            
            result = [[KxSMBItemFile alloc] initWithType:KxSMBItemTypeFile
                                                    path:path
                                                    stat:stat];
            
        } else {
            
            result = [[KxSMBItem alloc] initWithType:S_ISLNK(stat.mode) ? KxSMBItemTypeLink : KxSMBItemTypeUnknown
                                                path:path
                                                stat:stat];
        }
    }    
    
    [self closeSmbContext:smbContext];
    return result;
}

+ (id) removeAtPath: (NSString *) path
{
    NSParameterAssert(path);
    
    if (![path hasPrefix:@"smb://"]) {
        return mkKxSMBError(KxSMBErrorInvalidProtocol,
                            NSLocalizedString(@"Path:%@", nil), path);
    }
    
    SMBCCTX *smbContext = [self openSmbContext];
    if (!smbContext) {
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable init SMB context (errno:%d)", nil), err);
    }

    id result;    
    
    int r = smbc_getFunctionUnlink(smbContext)(smbContext, path.UTF8String);
    if (r < 0) {
        
        int err = errno;
        if (err == EISDIR) {
            
            r = smbc_getFunctionRmdir(smbContext)(smbContext, path.UTF8String);
            if (r < 0) {
                
                err = errno;
                result =  mkKxSMBError(errnoToSMBErr(err),
                                       NSLocalizedString(@"Unable rmdir file:%@ (errno:%d)", nil), path, err);
            }
            
        } else {
            
            result =  mkKxSMBError(errnoToSMBErr(err),
                                   NSLocalizedString(@"Unable unlink file:%@ (errno:%d)", nil), path, err);
            
        }
        
    }
    
    [self closeSmbContext:smbContext];
    return result;
}

+ (id) createFolderAtPath: (NSString *) path
{
    NSParameterAssert(path);
    
    if (![path hasPrefix:@"smb://"]) {
        return mkKxSMBError(KxSMBErrorInvalidProtocol,
                            NSLocalizedString(@"Path:%@", nil), path);
    }
    
    SMBCCTX *smbContext = [self openSmbContext];
    if (!smbContext) {
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable init SMB context (errno:%d)", nil), err);
    }
    
    id result;
    
    int r = smbc_getFunctionMkdir(smbContext)(smbContext, path.UTF8String, 0);
    if (r < 0) {
        
        const int err = errno;
        result =  mkKxSMBError(errnoToSMBErr(err),
                               NSLocalizedString(@"Unable mkdir:%@ (errno:%d)", nil), path, err);
        
    } else {
        
        id stat = [self fetchStat:smbContext atPath: path];
        if ([stat isKindOfClass:[KxSMBItemStat class]]) {
            
            result = [[KxSMBItemTree alloc] initWithType:KxSMBItemTypeDir
                                                    path:path
                                                    stat:stat];
            
        } else {
            
            result = stat;
        }
    }
    
    [self closeSmbContext:smbContext];
    return result;
}

+ (id) createFileAtPath:(NSString *) path overwrite:(BOOL)overwrite
{
    NSParameterAssert(path);
    
    if (![path hasPrefix:@"smb://"]) {
        return mkKxSMBError(KxSMBErrorInvalidProtocol,
                            NSLocalizedString(@"Path:%@", nil), path);
    }
    
    KxSMBItemFile *itemFile =  [[KxSMBItemFile alloc] initWithType:KxSMBItemTypeFile
                                                              path:path
                                                              stat:nil];
    id result = [itemFile createFile:overwrite];
    if ([result isKindOfClass:[NSError class]]) {
        return result;
    }
    return itemFile;
}

+ (NSError *) ensureLocalFolderExists:(NSString *)folderPath
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    BOOL isDir;
    if ([fm fileExistsAtPath:folderPath isDirectory:&isDir]) {
        
        if (!isDir) {
            
            return mkKxSMBError(KxSMBErrorFileIO,
                                NSLocalizedString(@"Cannot overwrite file %@", nil),
                                folderPath);
        }
        
    } else {
        
        NSError *error;
        if (![fm createDirectoryAtPath:folderPath
           withIntermediateDirectories:NO
                            attributes:nil
                                 error:&error]) {
            
            return error;
            
        }
    }
    return nil;
}

+ (NSFileHandle *) createLocalFile:(NSString *)path
                         overwrite:(BOOL) overwrite
                             error:(NSError **)outError
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    if ([fm fileExistsAtPath:path]) {
        
        if (overwrite) {
            
            if (![fm removeItemAtPath:path error:outError]) {
                return nil;
            }
            
        } else {
            
            return nil;
        }
    }
    
    NSString *folder = path.stringByDeletingLastPathComponent;
    
    if (![fm fileExistsAtPath:folder] &&
        ![fm createDirectoryAtPath:folder
       withIntermediateDirectories:YES
                        attributes:nil
                             error:outError]) {
            return nil;
        }
    
    if (![fm createFileAtPath:path
                     contents:nil
                   attributes:nil]) {
        
        if (outError) {
            *outError = mkKxSMBError(KxSMBErrorFileIO,
                                     NSLocalizedString(@"Unable create file", nil),
                                     path.lastPathComponent);
        }
        return nil;
    }
    
    return [NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:path]
                                             error:outError];
}

+ (void) readSMBFile:(KxSMBItemFile *)smbFile
          fileHandle:(NSFileHandle *)fileHandle
               block:(KxSMBBlock)block
{
    [smbFile readDataOfLength:1024*1024
                        block:^(id result)
     {
         if ([result isKindOfClass:[NSData class]]) {
             
             NSData *data = result;
             if (data.length) {
                 
                 [fileHandle writeData:data];
                 [self readSMBFile:smbFile
                        fileHandle:fileHandle
                             block:block];
                 
             } else {
                 
                 [fileHandle closeFile];
                 block(@(YES)); // complete
             }
             
             return;
         }
         
         [fileHandle closeFile];
         block([result isKindOfClass:[NSError class]] ? result : nil);
     }];
    
}

+ (void) copySMBFile:(KxSMBItemFile *)smbFile
           localPath:(NSString *)localPath
           overwrite:(BOOL)overwrite
               block:(KxSMBBlock)block
{
    NSError *error = nil;
    NSFileHandle *fileHandle = [self createLocalFile:localPath overwrite:overwrite error:&error];
    if (fileHandle) {
        
        [self readSMBFile:smbFile fileHandle:fileHandle block:block];
        
    } else {
        
        if (!error) {
            
            error = mkKxSMBError(KxSMBErrorFileIO,
                                 NSLocalizedString(@"Cannot overwrite file %@", nil),
                                 localPath.lastPathComponent);
        }
        
        block(error);
    }
}

+ (void) enumerateSMBFolders:(NSArray *)folders
                       items:(NSMutableArray *)items
                       block:(KxSMBBlock)block
{
    KxSMBItemTree *folder = folders[0];
    NSMutableArray *mfolders = [folders mutableCopy];
    [mfolders removeObjectAtIndex:0];
    
    [folder fetchItems:^(id result)
     {
         if ([result isKindOfClass:[NSArray class]]) {
             
             for (KxSMBItem *item in result ) {
                 
                 if ([item isKindOfClass:[KxSMBItemFile class]]) {
                     
                     [items addObject:item];
                     
                 } else if ([item isKindOfClass:[KxSMBItemTree class]] &&
                            (item.type == KxSMBItemTypeDir ||
                             item.type == KxSMBItemTypeFileShare ||
                             item.type == KxSMBItemTypeServer))
                 {
                     [mfolders addObject:item];
                     [items addObject:item];
                 }
             }
             
             if (mfolders.count) {
                 
                 [self enumerateSMBFolders:mfolders items:items block:block];
                 
             } else {
                 
                 block(items);
             }
             
         } else {
             
             block([result isKindOfClass:[NSError class]] ? result : nil);
         }
     }];
}

+ (void) copySMBItems:(NSArray *)smbItems
            smbFolder:(NSString *)smbFolder
          localFolder:(NSString *)localFolder
            overwrite:(BOOL)overwrite
                block:(KxSMBBlock)block
{
    KxSMBItem *item = smbItems[0];
    if (smbItems.count > 1) {
        smbItems = [smbItems subarrayWithRange:NSMakeRange(1, smbItems.count - 1)];
    } else {
        smbItems = nil;
    }
    
    if ([item isKindOfClass:[KxSMBItemFile class]]) {
        
        NSString *destPath = localFolder;
        NSString *itemFolder = item.path.stringByDeletingLastPathComponent;
        if (itemFolder.length > smbFolder.length) {
            NSString *relPath = [itemFolder substringFromIndex:smbFolder.length];
            destPath = [destPath stringByAppendingPathComponent:relPath];
        }
        destPath = [destPath stringByAppendingSMBPathComponent:item.path.lastPathComponent];
        
        [self copySMBFile:(KxSMBItemFile *)item
                 localPath:destPath
                overwrite:overwrite
                    block:^(id result)
         {
             if ([result isKindOfClass:[NSError class]]) {
                 
                 block(result);
                 
             } else {
                 
                 if (smbItems.count) {
                     
                     [self copySMBItems:smbItems
                              smbFolder:smbFolder
                            localFolder:localFolder
                              overwrite:overwrite
                                  block:block];
                     
                 } else {
                     
                     block(@(YES)); // complete
                 }
             }             
         }];
        
    } else if ([item isKindOfClass:[KxSMBItemTree class]]) {
        
        NSString *destPath = localFolder;
        NSString *itemFolder = item.path;
        if (itemFolder.length > smbFolder.length) {
            NSString *relPath = [itemFolder substringFromIndex:smbFolder.length];
            destPath = [destPath stringByAppendingPathComponent:relPath];
        }
        
        NSError *error = [self ensureLocalFolderExists:destPath];
        if (error) {
            block(error);
            return;
        }
        
        if (smbItems.count) {
            
            [self copySMBItems:smbItems
                     smbFolder:smbFolder
                   localFolder:localFolder
                     overwrite:overwrite
                         block:block];
            
        } else {
            
            block(@(YES)); // complete
        }
    }
}

///

+ (void) writeSMBFile:(KxSMBItemFile *)smbFile
           fileHandle:(NSFileHandle *)fileHandle
                block:(KxSMBBlock)block
{
    NSData *data;
    
    @try {
        
        data = [fileHandle readDataOfLength:1024*1024];
    }
    @catch (NSException *exception) {
        
        [fileHandle closeFile];
        block(mkKxSMBError(KxSMBErrorFileIO, [exception description]));
        return;
    }
    
    if (data.length) {
        
        [smbFile writeData:data block:^(id result) {
            
            if ([result isKindOfClass:[NSNumber class]]) {
                
                [self  writeSMBFile:smbFile
                         fileHandle:fileHandle
                              block:block];
                
                return;
            }
            
            block([result isKindOfClass:[NSError class]] ? result : nil);
        }];
        
    } else {
        
        [fileHandle closeFile];
        block(smbFile);
    }
}

+ (void) copyLocalFile:(NSString *)localPath
               smbPath:(NSString *)smbPath
             overwrite:(BOOL)overwrite
                 block:(KxSMBBlock)block
{
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    
    [provider createFileAtPath:smbPath
                     overwrite:overwrite
                         block:^(id result)
     {
         if ([result isKindOfClass:[KxSMBItemFile class]]) {
             
             NSError *error = nil;
             NSFileHandle *fileHandle;
             NSURL *url =[NSURL fileURLWithPath:localPath];
             fileHandle = [NSFileHandle fileHandleForReadingFromURL:url error:&error];
             
             if (fileHandle) {
                 
                 [self writeSMBFile:result fileHandle:fileHandle block:block];
                 
             } else {
                 
                 block(error);
             }
             
         } else {
             
             block([result isKindOfClass:[NSError class]] ? result : nil);
         }
     }];
}

+ (void) copyLocalFiles:(NSDirectoryEnumerator *)enumerator
            localFolder:(NSString *)localFolder
              smbFolder:(KxSMBItemTree *)smbFolder
              overwrite:(BOOL)overwrite
                  block:(KxSMBBlock)block
{
    NSString *path = [enumerator nextObject];
    if (path) {
        
        if (path.length && [path characterAtIndex:0] != '.') {
            
            NSDictionary *attr = [enumerator fileAttributes];
            if ([[attr fileType] isEqualToString:NSFileTypeDirectory]) {
                
                KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
                [provider createFolderAtPath:[smbFolder.path stringByAppendingSMBPathComponent:path]
                                       block:^(id result)
                 {
                     if ([result isKindOfClass:[NSError class]]) {
                         
                         block(result);
                         
                     } else {
                         
                         [self copyLocalFiles:enumerator
                                  localFolder:localFolder
                                    smbFolder:smbFolder
                                    overwrite:overwrite
                                        block:block];
                     }
                 }];
                
                return;
                
            } else if ([[attr fileType] isEqualToString:NSFileTypeRegular]) {
                
                NSString *destFolder = smbFolder.path;
                NSString *fileFolder = path.stringByDeletingLastPathComponent;
                if (fileFolder.length)
                    destFolder = [destFolder stringByAppendingSMBPathComponent:fileFolder];
                
                [self copyLocalFile:[localFolder stringByAppendingPathComponent:path]
                            smbPath:[destFolder stringByAppendingSMBPathComponent:path.lastPathComponent]
                          overwrite:overwrite
                              block:^(id result)
                 {
                     if ([result isKindOfClass:[NSError class]]) {
                         
                         block(result);
                         
                     } else {
                         
                         [self copyLocalFiles:enumerator
                                  localFolder:localFolder
                                    smbFolder:smbFolder
                                    overwrite:overwrite
                                        block:block];
                     }
                 }];
                
                return;
            }
        }
        
        [self copyLocalFiles:enumerator
                 localFolder:localFolder
                   smbFolder:smbFolder
                   overwrite:overwrite
                       block:block];
        
    } else {
        
        block(smbFolder);
    }
}

///

+ (void) removeSMBItems:(NSArray *)smbItems
                  block:(KxSMBBlock)block
{
    KxSMBItem *item = smbItems[0];
    if (smbItems.count > 1) {
        smbItems = [smbItems subarrayWithRange:NSMakeRange(1, smbItems.count - 1)];
    } else {
        smbItems = nil;
    }
    
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider removeAtPath:item.path block:^(id result) {
      
        if ([result isKindOfClass:[NSError class]]) {
            
            block(result);
            
        } else if (smbItems.count) {
            
            [self removeSMBItems:smbItems block:block];
            
        } else {
            
            block(@(YES));
        }
    }];
}

+ (id) renameAtPath:(NSString *)oldPath
            newPath:(NSString *)newPath
{
    NSParameterAssert(oldPath);
    NSParameterAssert(newPath);    
    
    if (![oldPath hasPrefix:@"smb://"]) {
        return mkKxSMBError(KxSMBErrorInvalidProtocol,
                            NSLocalizedString(@"Path:%@", nil), oldPath);
    }
    
    if (![newPath hasPrefix:@"smb://"]) {
        return mkKxSMBError(KxSMBErrorInvalidProtocol,
                            NSLocalizedString(@"Path:%@", nil), newPath);
    }
    
    SMBCCTX *smbContext = [self openSmbContext];
    if (!smbContext) {
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable init SMB context (errno:%d)", nil), err);
    }
    
    id result;
    
    int r = smbc_getFunctionRename(smbContext)(smbContext, oldPath.UTF8String, smbContext, newPath.UTF8String);
    if (r < 0) {
        
        const int err = errno;
        result =  mkKxSMBError(errnoToSMBErr(err),
                               NSLocalizedString(@"Unable rename file:%@ (errno:%d)", nil), oldPath, err);
        
    } else {
        
        result = [self fetchStat:smbContext atPath: newPath];
        if ([result isKindOfClass:[KxSMBItemStat class]]) {
            
            KxSMBItemStat *stat = result;
            
            if (S_ISDIR(stat.mode)) {
                
                result = [[KxSMBItemTree alloc] initWithType:KxSMBItemTypeDir path:newPath stat:stat];
                
            } else if (S_ISREG(stat.mode)) {
                
                result = [[KxSMBItemFile alloc] initWithType:KxSMBItemTypeFile path:newPath stat:stat];
                
            } else {
                
                result = nil;
            }
        } 
    }
    
    [self closeSmbContext:smbContext];
    return result;
}

#pragma mark - internal methods

- (void) dispatchSync: (dispatch_block_t) block
{
    dispatch_sync(_dispatchQueue, block);
}

- (void) dispatchAsync: (dispatch_block_t) block
{
    dispatch_async(_dispatchQueue, block);
}

#pragma mark - public methods

- (void) fetchAtPath: (NSString *) path
               block: (KxSMBBlock) block
{
    NSParameterAssert(path);
    NSParameterAssert(block);
    
    dispatch_async(_dispatchQueue, ^{
                
        id result = [KxSMBProvider fetchAtPath: path.length ? path : @"smb://"];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    });
}

- (id) fetchAtPath: (NSString *) path
{
    NSParameterAssert(path);
    
    __block id result = nil;
    dispatch_sync(_dispatchQueue, ^{
        
        result = [KxSMBProvider fetchAtPath: path.length ? path : @"smb://"];
    });
    return result;
}

- (void) createFileAtPath:(NSString *) path overwrite:(BOOL)overwrite block:(KxSMBBlock) block
{
    NSParameterAssert(path);
    NSParameterAssert(block);
    
    dispatch_async(_dispatchQueue, ^{
        
        id result = [KxSMBProvider createFileAtPath:path overwrite:overwrite];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    });
}

- (id) createFileAtPath:(NSString *) path overwrite:(BOOL)overwrite
{
    NSParameterAssert(path);
    
    __block id result = nil;
    dispatch_sync(_dispatchQueue, ^{
        
        result = [KxSMBProvider createFileAtPath:path overwrite:overwrite];
    });
    return result;
}

- (void) removeAtPath: (NSString *) path block: (KxSMBBlock) block
{
    NSParameterAssert(path);
    NSParameterAssert(block);
    
    dispatch_async(_dispatchQueue, ^{
        
        id result = [KxSMBProvider removeAtPath:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    });
}

- (id) removeAtPath: (NSString *) path
{
    NSParameterAssert(path);
    
    __block id result = nil;
    dispatch_sync(_dispatchQueue, ^{
        
        result = [KxSMBProvider removeAtPath:path];
    });
    return result;
}

- (void) createFolderAtPath:(NSString *) path block: (KxSMBBlock) block
{
    NSParameterAssert(path);
    NSParameterAssert(block);
    
    dispatch_async(_dispatchQueue, ^{
        
        id result = [KxSMBProvider createFolderAtPath:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    });
}

- (id) createFolderAtPath:(NSString *) path
{
    NSParameterAssert(path);
    
    __block id result = nil;
    dispatch_sync(_dispatchQueue, ^{
        
        result = [KxSMBProvider createFolderAtPath:path];
    });
    return result;
}

- (void) copySMBPath:(NSString *)smbPath
           localPath:(NSString *)localPath
           overwrite:(BOOL)overwrite
               block:(KxSMBBlock)block
{   
    [self fetchAtPath:smbPath block:^(id result) {
        
        if ([result isKindOfClass:[KxSMBItemFile class]]) {
            
            [KxSMBProvider copySMBFile:result
                             localPath:localPath
                             overwrite:overwrite
                                 block:block];            
            
        } else if ([result isKindOfClass:[NSArray class]]) {
            
            NSError *error = [KxSMBProvider ensureLocalFolderExists:localPath];
            if (error) {
                block(error);
                return;
            }
            
            NSMutableArray *folders = [NSMutableArray array];
            NSMutableArray *items = [NSMutableArray array];
            
            for (KxSMBItem *item in result ) {
                
                if ([item isKindOfClass:[KxSMBItemFile class]]) {
                    
                    [items addObject:item];
                    
                } else if ([item isKindOfClass:[KxSMBItemTree class]] &&
                           (item.type == KxSMBItemTypeDir ||
                            item.type == KxSMBItemTypeFileShare ||
                            item.type == KxSMBItemTypeServer))
                {
                    [items addObject:item];
                    [folders addObject:item];
                }
            }
            
            if (folders.count) {
                
                [KxSMBProvider enumerateSMBFolders:folders
                                             items:items
                                             block:^(id result)
                 {                     
                     if ([result isKindOfClass:[NSArray class]]) {
                         
                         NSArray *items = result;
                         if (items.count) {
                             
                             [KxSMBProvider copySMBItems:items
                                               smbFolder:smbPath
                                             localFolder:localPath
                                               overwrite:overwrite
                                                   block:block];
                             
                         } else {
                             
                             block(@(YES));
                         }
                         
                     } else {
                         
                         block(result);
                     }
                 }];
                
            } else if (items.count) {
                
                [KxSMBProvider copySMBItems:items
                                  smbFolder:smbPath
                                localFolder:localPath
                                  overwrite:overwrite
                                      block:block];                
                
            }  else {
                
                block(@(YES));
                return;
            }
            
        } else {
            
            block([result isKindOfClass:[NSError class]] ? result : nil);
        }
    }];
}


- (void) copyLocalPath:(NSString *)localPath
               smbPath:(NSString *)smbPath
             overwrite:(BOOL)overwrite
                 block:(KxSMBBlock)block
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    BOOL isDir;
    if (![fm fileExistsAtPath:localPath isDirectory:&isDir]) {
        
        block(mkKxSMBError(KxSMBErrorFileIO,
                           NSLocalizedString(@"File '%@' is not exist", nil),
                           localPath.lastPathComponent));
        return;
    }
    
    if (isDir) {
        
        [self createFolderAtPath:smbPath
                           block:^(id result)
         {
             if ([result isKindOfClass:[KxSMBItemTree class]]) {
                 
                 [KxSMBProvider copyLocalFiles:[fm enumeratorAtPath:localPath]
                                   localFolder:localPath
                                     smbFolder:result
                                     overwrite:overwrite
                                         block:block];
             } else {
                 
                 block([result isKindOfClass:[NSError class]] ? result : nil);
             }
         }];        
        
    } else {
        
        [KxSMBProvider copyLocalFile:localPath
                             smbPath:smbPath
                           overwrite:overwrite
                               block:block];
    }
}

- (void) removeFolderAtPath:(NSString *) path
                      block:(KxSMBBlock)block
{
    [self fetchAtPath:path
                block:^(id result)
    {
        if ([result isKindOfClass:[NSArray class]]) {
            
            NSMutableArray *folders = [NSMutableArray array];
            NSMutableArray *items = [NSMutableArray array];
            
            for (KxSMBItem *item in result) {
                
                if ([item isKindOfClass:[KxSMBItemFile class]]) {
                    
                    [items addObject:item];
                    
                } else if ([item isKindOfClass:[KxSMBItemTree class]] &&
                           (item.type == KxSMBItemTypeDir ||
                            item.type == KxSMBItemTypeFileShare ||
                            item.type == KxSMBItemTypeServer))
                {
                    [items addObject:item];
                    [folders addObject:item];
                }
            }
            
            if (folders.count) {
                
                [KxSMBProvider enumerateSMBFolders:folders
                                             items:items
                                             block:^(id result)
                 {
                     if ([result isKindOfClass:[NSArray class]]) {
                         
                         NSMutableArray *reversed = [NSMutableArray array];
                         for (id item in [result reverseObjectEnumerator]) {
                             [reversed addObject:item];
                         }
                         
                         [KxSMBProvider removeSMBItems:reversed block:^(id result) {
                             
                             if ([result isKindOfClass:[NSNumber class]]) {
                             
                                 [[KxSMBProvider sharedSmbProvider] removeAtPath:path block:block];
                                 
                             } else {
                                 
                                 block([result isKindOfClass:[NSError class]] ? result : nil);
                             }
                         }];
                         
                     } else {
                         
                         block([result isKindOfClass:[NSError class]] ? result : nil);
                     }
                 }];
                
            } else if (items.count) {
                
                [KxSMBProvider removeSMBItems:items block:^(id result) {
                    
                    if ([result isKindOfClass:[NSNumber class]]) {
                        
                        [[KxSMBProvider sharedSmbProvider] removeAtPath:path block:block];
                        
                    } else {
                        
                        block([result isKindOfClass:[NSError class]] ? result : nil);
                    }
                }];
                
            } else {
                
                [self removeAtPath:path block:block];
            }
            
        } else if ([result isKindOfClass:[KxSMBItemFile class]]) {
            
            block(mkKxSMBError(KxSMBErrorPathIsNotDir, path));
            
        } else {
            
            block([result isKindOfClass:[NSError class]] ? result : nil);
        }        
    }];
}

- (void) renameAtPath:(NSString *)oldPath
              newPath:(NSString *)newPath
                block:(KxSMBBlock)block
{
    NSParameterAssert(oldPath);
    NSParameterAssert(newPath);    
    NSParameterAssert(block);
    
    dispatch_async(_dispatchQueue, ^{
        
        id result = [KxSMBProvider renameAtPath:oldPath newPath:newPath];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    });
}


@end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

@implementation KxSMBItemTree

- (void) fetchItems: (KxSMBBlock) block
{
    NSParameterAssert(block);
    
    NSString *path = self.path;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchAsync: ^{
        
        id result = [KxSMBProvider fetchTreeAtPath:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    }];
}

- (id) fetchItems
{
    __block id result = nil;
    NSString *path = self.path;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchSync: ^{
        
        result = [KxSMBProvider fetchTreeAtPath:path];
    }];
    return result;
}

- (void) createFileWithName:(NSString *) name overwrite:(BOOL)overwrite block: (KxSMBBlock) block
{
    NSParameterAssert(name.length);
    
    if (self.type != KxSMBItemTypeDir ||
        self.type != KxSMBItemTypeFileShare )
    {
        block(mkKxSMBError(KxSMBErrorPathIsNotDir, nil));
        return;
    }
    
    [[KxSMBProvider sharedSmbProvider] createFileAtPath:[self.path stringByAppendingSMBPathComponent:name]
                                              overwrite:overwrite
                                                  block:block];

}

- (id) createFileWithName:(NSString *) name overwrite:(BOOL)overwrite
{
    NSParameterAssert(name.length);
    
    if (self.type != KxSMBItemTypeDir ||
        self.type != KxSMBItemTypeFileShare )
    {
        return mkKxSMBError(KxSMBErrorPathIsNotDir, nil);
    }
    
    return [[KxSMBProvider sharedSmbProvider] createFileAtPath:[self.path stringByAppendingSMBPathComponent:name]
                                                     overwrite:overwrite];
}

- (void) removeWithName: (NSString *) name block: (KxSMBBlock) block
{
    if (self.type != KxSMBItemTypeDir ||
        self.type != KxSMBItemTypeFileShare )
    {
        block(mkKxSMBError(KxSMBErrorPathIsNotDir, nil));
        return;
    }
    
    [[KxSMBProvider sharedSmbProvider] removeAtPath:[self.path stringByAppendingSMBPathComponent:name]
                                              block:block];
}

- (id) removeWithName: (NSString *) name
{
    if (self.type != KxSMBItemTypeDir ||
        self.type != KxSMBItemTypeFileShare )
    {
        return mkKxSMBError(KxSMBErrorPathIsNotDir, nil);
    }
    
    return [[KxSMBProvider sharedSmbProvider] removeAtPath:[self.path stringByAppendingSMBPathComponent:name]];
}

@end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

@interface KxSMBFileImpl : NSObject
@end

@implementation KxSMBFileImpl {
    
    SMBCCTX *_context;
    SMBCFILE *_file;
    NSString *_path;
}

- (id) initWithPath: (NSString *) path
{
    self = [super init];
    if (self) {
        _path = path;
    }
    return self;
}

- (NSError *) openFile
{
    _context = [KxSMBProvider openSmbContext];
    if (!_context) {
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable init SMB context (errno:%d)", nil), err);
    }
    
    _file = smbc_getFunctionOpen(_context)(_context,
                                           _path.UTF8String,
                                           O_RDONLY,
                                           0);
    
    if (!_file) {
        [KxSMBProvider closeSmbContext:_context];
        _context = NULL;
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable open file:%@ (errno:%d)", nil), _path, err);
    }
    
    return nil;
}

- (NSError *) createFile:(BOOL)overwrite
{
    _context = [KxSMBProvider openSmbContext];
    if (!_context) {
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable init SMB context (errno:%d)", nil), err);
    }
    
    _file = smbc_getFunctionCreat(_context)(_context,
                                           _path.UTF8String,
                                            O_WRONLY|O_CREAT|(overwrite ? O_TRUNC : O_EXCL));
    
    if (!_file) {
        [KxSMBProvider closeSmbContext:_context];
        _context = NULL;
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable open file:%@ (errno:%d)", nil), _path, err);
    }
    
    return nil;
}

- (void) closeFile
{
    if (_file) {
        smbc_getFunctionClose(_context)(_context, _file);
        _file = NULL;
    }
    if (_context) {
        [KxSMBProvider closeSmbContext:_context];
        _context = NULL;
    }
}

- (id)readDataOfLength:(NSUInteger)length
{
    if (!_file) {
        
        NSError *error = [self openFile];
        if (error) return error;        
    }
        
    Byte buffer[4096];
    
    smbc_read_fn readFn = smbc_getFunctionRead(_context);
    NSMutableData *md = [NSMutableData data];
    NSInteger bytesToRead = length;
    
    while (bytesToRead > 0) {
        
        int r = readFn(_context, _file, buffer, MIN(bytesToRead, sizeof(buffer)));
        
        if (r == 0)
            break;
        
        if (r < 0) {
                        
            const int err = errno;
            return mkKxSMBError(errnoToSMBErr(err),
                                NSLocalizedString(@"Unable read file:%@ (errno:%d)", nil), _path, err);
        }
        
        [md appendBytes:buffer length:r];
        bytesToRead -= r;
    }
        
    return md;
}

- (id)readDataToEndOfFile
{
    if (!_file) {
        
        NSError *error = [self openFile];
        if (error) return error;
    }
    
    Byte buffer[32768];
    
    smbc_read_fn readFn = smbc_getFunctionRead(_context);
    
    NSMutableData *md = [NSMutableData data];
    
    while (1) {
        
        int r = readFn(_context, _file, buffer, sizeof(buffer));
        
        if (r == 0)
            break;
        
        if (r < 0) {
            
            const int err = errno;
            return mkKxSMBError(errnoToSMBErr(err),
                                NSLocalizedString(@"Unable read file:%@ (errno:%d)", nil), _path, err);
        }
        
        [md appendBytes:buffer length:r];
    }
    
    return md;

}

- (id)seekToFileOffset:(off_t)offset
                whence:(NSInteger)whence
{
    if (!_file) {
        
        NSError *error = [self openFile];
        if (error) return error;
    }
    
    off_t r = smbc_getFunctionLseek(_context)(_context, _file, offset, whence);
    if (r < 0) {
        const int err = errno;
        return mkKxSMBError(errnoToSMBErr(err),
                            NSLocalizedString(@"Unable seek to file:%@ (errno:%d)", nil), _path, errno);
    }
    return @(r);
}

- (id)writeData:(NSData *)data
{
    if (!_file) {
        
        NSError *error = [self createFile:NO];
        if (error) return error;
    }

    smbc_write_fn writeFn = smbc_getFunctionWrite(_context);
    NSInteger bytesToWrite = data.length;
    const Byte *bytes = data.bytes;
    
    while (bytesToWrite > 0) {
        
        int r = writeFn(_context, _file, bytes, bytesToWrite);
        if (r == 0)
            break;
        
        if (r < 0) {
            
            const int err = errno;
            return mkKxSMBError(errnoToSMBErr(err),
                                NSLocalizedString(@"Unable write file:%@ (errno:%d)", nil), _path, err);
        }

        bytesToWrite -= r;
        bytes += r;
    }
    
    return @(data.length - bytesToWrite);
}

@end

@implementation KxSMBItemFile {
    
    KxSMBFileImpl *_impl;
}

- (void) dealloc
{
    [self close];
}

- (void) close
{
    if (_impl) {
        
        KxSMBFileImpl *p = _impl;
        _impl = nil;
        
        KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
        [provider dispatchAsync:^{ [p closeFile]; }];         
    }
}

- (void)readDataOfLength:(NSUInteger)length
                   block:(KxSMBBlock)block
{
    NSParameterAssert(block);
    
    if (!_impl)
        _impl = [[KxSMBFileImpl alloc] initWithPath:self.path];
    
    KxSMBFileImpl *p = _impl;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchAsync:^{
        
        id result = [p readDataOfLength:length];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    }];
}

- (id)readDataOfLength:(NSUInteger)length
{    
    __block id result = nil;
    
    if (!_impl)
        _impl = [[KxSMBFileImpl alloc] initWithPath:self.path];
    
    KxSMBFileImpl *p = _impl;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchSync:^{
        
        result = [p readDataOfLength:length];
    }];
    return result;
}

- (void)readDataToEndOfFile:(KxSMBBlock)block
{
    NSParameterAssert(block);
    
    if (!_impl)
        _impl = [[KxSMBFileImpl alloc] initWithPath:self.path];
    
    KxSMBFileImpl *p = _impl;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchAsync:^{
        
        id result = [p readDataToEndOfFile];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    }];
}

- (id)readDataToEndOfFile
{
    __block id result = nil;
    
    if (!_impl)
        _impl = [[KxSMBFileImpl alloc] initWithPath:self.path];
    
    KxSMBFileImpl *p = _impl;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchSync:^{
        
        result = [p readDataToEndOfFile];
    }];
    return result;
}

- (void)seekToFileOffset:(off_t)offset
                  whence:(NSInteger)whence
                   block:(KxSMBBlock) block
{
    NSParameterAssert(block);
    
    if (!_impl)
        _impl = [[KxSMBFileImpl alloc] initWithPath:self.path];
    
    KxSMBFileImpl *p = _impl;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchAsync:^{
        
        id result = [p seekToFileOffset:offset whence:whence];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    }];
}

- (id)seekToFileOffset:(off_t)offset
                whence:(NSInteger)whence
{
    __block id result = nil;
    
    if (!_impl)
        _impl = [[KxSMBFileImpl alloc] initWithPath:self.path];
    
    KxSMBFileImpl *p = _impl;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchSync:^{
        
        result = [p seekToFileOffset:offset whence:whence];
    }];
    return result;
}

- (void)writeData:(NSData *)data block:(KxSMBBlock) block
{
    NSParameterAssert(block);
    
    if (!_impl)
        _impl = [[KxSMBFileImpl alloc] initWithPath:self.path];
    
    KxSMBFileImpl *p = _impl;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchAsync:^{
        
        id result = [p writeData:data];
        dispatch_async(dispatch_get_main_queue(), ^{
            block(result);
        });
    }];
}

- (id)writeData:(NSData *)data
{
    __block id result = nil;
    
    if (!_impl)
        _impl = [[KxSMBFileImpl alloc] initWithPath:self.path];
    
    KxSMBFileImpl *p = _impl;
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider dispatchSync:^{
        
        result = [p writeData:data];
    }];
    return result;

}

#pragma mark - internal

- (id) createFile:(BOOL)overwrite
{
    if (!_impl)
        _impl = [[KxSMBFileImpl alloc] initWithPath:self.path];
    return [_impl createFile:overwrite];
}

@end

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

static void my_smbc_get_auth_data_fn(const char *srv,
                                     const char *shr,
                                     char *workgroup, int wglen,
                                     char *username, int unlen,
                                     char *password, int pwlen)
{
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    
    KxSMBAuth *auth = nil;
    __strong id<KxSMBProviderDelegate> delegate = provider.delegate;
    if (delegate) {
        auth = [delegate smbAuthForServer:[NSString stringWithUTF8String:srv]
                                withShare:[NSString stringWithUTF8String:shr]];
    }
        
    if (auth.username.length)
        strncpy(username, auth.username.UTF8String, unlen - 1);
    else
        strncpy(username, "guest", unlen - 1);
    
    if (auth.password.length)
        strncpy(password, auth.password.UTF8String, pwlen - 1);
    else
        password[0] = 0;
    
    if (auth.workgroup.length)
        strncpy(workgroup, auth.workgroup.UTF8String, wglen - 1);
    else
        workgroup[0] = 0;
    
    NSLog(@"smb get auth for %s/%s -> %s/%s:%s", srv, shr, workgroup, username, password);
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

@implementation NSString (KxSMB)

// unfortunately, [NSString stringByAppendingPathComponent] brokes smb:// pathes
// so need to use custom version

- (NSString *) stringByAppendingSMBPathComponent: (NSString *) aString
{
    NSString *path = self;
    if (![path hasSuffix:@"/"]) {
        path = [path stringByAppendingString:@"/"];
    }
    return [path stringByAppendingString:aString];
}

@end
