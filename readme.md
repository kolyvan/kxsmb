KxSMB is objective-c wrapper for libsmbclient lib. 
===========================================

For now KxSMB supports a limited set of SMB operations.
It mostly was designed for browsing local net and retrieving files.

### Build instructions:

First you need download, configure and build [samba](http://www.samba.org).
For this open console and type in
	
	cd kxsmb	
	rake

### Usage

1. Drop files from kxsmb/libs folder in your project.
2. Add libs: libz.dylib, libresolv.dylib and liconv.dylib.

Fetching a folder content:

	NSArray *items = [[KxSMBProvider sharedSmbProvider] fetchAtPath: @"smb://server/share/"];

Reading a file:

	KxSMBItemFile *file = [[KxSMBProvider sharedSmbProvider] fetchAtPath: @"smb://server/share/file"];
	NSData *data = [file readDataToEndOfFile];

Look at kxSMBSample demo project as example of using.

### Requirements

at least iOS 5.0 and Xcode 4.5.0

### Feedback

Tweet me — [@kolyvan_ru](http://twitter.com/kolyvan_ru).