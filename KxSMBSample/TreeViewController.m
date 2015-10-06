//
//  TreeViewController.m
//  kxsmb project
//  https://github.com/kolyvan/kxsmb/
//
//  Created by Kolyvan on 27.03.13.
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

#import "TreeViewController.h"
#import "FileViewController.h"
#import "KxSMBProvider.h"

@interface TreeViewController () <UITableViewDataSource, UITableViewDelegate>
@end

@implementation TreeViewController {
    
    BOOL        _isHeadVC;
    NSArray     *_items;
    BOOL        _loading;
    BOOL        _needNewPath;
    UITextField *_newPathField;
}

- (void) setPath:(NSString *)path
{
    _path = path;
    [self reloadPath];
}

- (id)init
{
    self = [super init];
    if (self) {
        
        self.title = @"";
        _needNewPath = YES;
        _isHeadVC = NO;
    }
    return self;
}

- (id)initAsHeadViewController {
    if((self = [self init])) {
        _isHeadVC = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if(NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(reloadPath) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    if(_isHeadVC) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch
                                                                                              target:self
                                                                                              action:@selector(requestNewPath)];
    }
    
    self.navigationItem.rightBarButtonItems =
    @[
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                    target:self
                                                    action:@selector(actionMkDir:)],
      
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                    target:self
                                                    action:@selector(actionCopyFile:)],
      ];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    if (self.navigationController.childViewControllers.count == 1 && _needNewPath) {
        _needNewPath = NO;
        [self requestNewPath];
    }
}

- (void) reloadPath
{
    NSString *path;
    
    if (_path.length) {
        
        path = _path;
        self.title = path.lastPathComponent;
        
    } else {
        
        path = @"smb://";
        self.title = @"smb://";
    }
    
    _items = nil;
    [self.tableView reloadData];
    [self updateStatus:[NSString stringWithFormat: @"Fetching %@..", path]];
    
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider fetchAtPath:path
                    block:^(id result)
    {
        if ([result isKindOfClass:[NSError class]]) {
            
            [self updateStatus:result];
            
        } else {
        
            [self updateStatus:nil];
            
            if ([result isKindOfClass:[NSArray class]]) {
                
                _items = [result copy];
                
            } else if ([result isKindOfClass:[KxSMBItem class]]) {
                
                _items = @[result];
            }
            
            [self.tableView reloadData];
        }
    }];
}

- (void) requestNewPath
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connect to Host"
                                                    message:@"\n\n"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Go", nil];
    
    if(_newPathField == nil) {
        _newPathField = [[UITextField alloc] initWithFrame:CGRectMake(12, 45, 260, 30)];
        _newPathField.borderStyle = UITextBorderStyleRoundedRect;
        _newPathField.placeholder = @"smb://";
        _newPathField.keyboardType = UIKeyboardTypeURL;
        _newPathField.autocorrectionType = UITextAutocorrectionTypeNo;
        _newPathField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _newPathField.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"LastServer"];
    }
    
    [alert addSubview:_newPathField];
    
    [alert show];
    
    [_newPathField becomeFirstResponder];
}

- (void) updateStatus: (id) status
{
    UIFont *font = [UIFont boldSystemFontOfSize:16];
    
    if ([status isKindOfClass:[NSString class]]) {
    
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        
        CGSize sz = activityIndicator.frame.size;        
        const float H = font.lineHeight + sz.height + 10;
        const float W = self.tableView.frame.size.width;
        
        UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, W, font.lineHeight)];
        label.text = status;
        label.font = font;
        label.textColor = [UIColor grayColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.opaque = NO;
        label.backgroundColor = [UIColor clearColor];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        [v addSubview:label];
        
        if(![self.refreshControl isRefreshing])
            [self.refreshControl beginRefreshing];
        
        self.tableView.tableHeaderView = v;
        
    } else if ([status isKindOfClass:[NSError class]]) {
        
        const float W = self.tableView.frame.size.width;
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, W, font.lineHeight)];
        label.text = ((NSError *)status).localizedDescription;
        label.font = font;
        label.textColor = [UIColor redColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.opaque = NO;
        label.backgroundColor = [UIColor clearColor];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        self.tableView.tableHeaderView = label;
        
        [self.refreshControl endRefreshing];
        
    } else {
        
        self.tableView.tableHeaderView = nil;
        
        [self.refreshControl endRefreshing];
    }
}

- (void) actionCopyFile:(id)sender
{
    NSString *name = [NSString stringWithFormat:@"%u.tmp", (unsigned)[NSDate timeIntervalSinceReferenceDate]];
    NSString *path = [_path stringByAppendingSMBPathComponent:name];
    
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    [provider createFileAtPath:path overwrite:YES block:^(id result) {
        
        if ([result isKindOfClass:[KxSMBItemFile class]]) {
            
            NSData *data = [@"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." dataUsingEncoding:NSUTF8StringEncoding];
            
            KxSMBItemFile *itemFile = result;
            [itemFile writeData:data block:^(id result) {
                
                NSLog(@"completed:%@", result);
                if (![result isKindOfClass:[NSError class]]) {
                    [self reloadPath];
                }
            }];
            
        } else {
            
            NSLog(@"%@", result);
        }
    }];     
}

- (void) actionMkDir:(id)sender
{
    NSString *path = [_path stringByAppendingSMBPathComponent:@"NewFolder"];
    KxSMBProvider *provider = [KxSMBProvider sharedSmbProvider];
    id result = [provider createFolderAtPath:path];
    if ([result isKindOfClass:[KxSMBItemTree class]]) {
        
        NSMutableArray *ma = [_items mutableCopy];
        [ma addObject:result];
        _items = [ma copy];
        
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:_items.count-1 inSection:0]]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
        
    } else {
        
        NSLog(@"%@", result);
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:cellIdentifier];
    }
    
    KxSMBItem *item = _items[indexPath.row];
    cell.textLabel.text = item.path.lastPathComponent;
    
    if ([item isKindOfClass:[KxSMBItemTree class]]) {
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.detailTextLabel.text =  @"";
        
    } else {
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", item.stat.size];
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    KxSMBItem *item = _items[indexPath.row];
    if ([item isKindOfClass:[KxSMBItemTree class]]) {
        
        TreeViewController *vc = [[TreeViewController alloc] init];
        vc.path = item.path;
        [self.navigationController pushViewController:vc animated:YES];
        
    } else if ([item isKindOfClass:[KxSMBItemFile class]]) {
        
        FileViewController *vc = [[FileViewController alloc] init];
        vc.smbFile = (KxSMBItemFile *)item;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        KxSMBItem *item = _items[indexPath.row];
        [[KxSMBProvider sharedSmbProvider] removeAtPath:item.path block:^(id result) {
            
            NSLog(@"completed:%@", result);
            if (![result isKindOfClass:[NSError class]]) {
                [self reloadPath];
            }
        }];        
    }
}

#pragma mark - Alert view delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(buttonIndex == 1) {
        self.path = _newPathField.text;
        [[NSUserDefaults standardUserDefaults] setObject:_newPathField.text forKey:@"LastServer"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end
