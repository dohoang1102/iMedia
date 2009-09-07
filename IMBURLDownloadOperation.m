/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
*/


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBURLDownloadOperation.h"
#import "NSFileManager+iMedia.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBURLDownloadOperation ()
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBURLDownloadOperation

@synthesize delegate = _delegate;
@synthesize remoteURL = _remoteURL;
@synthesize downloadFolderPath = _downloadFolderPath;
@synthesize localPath = _localPath;
@synthesize download = _download;
@synthesize error = _error;
@synthesize bytesTotal = _bytesTotal;
@synthesize bytesDone = _bytesDone;
@synthesize finished = _finished;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithURL:(NSURL*)inURL delegate:(id)inDelegate;
{
	if (self = [super init])
	{
		self.remoteURL = inURL;
		self.delegate = inDelegate;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_remoteURL);
	IMBRelease(_downloadFolderPath);
	IMBRelease(_localPath);
	IMBRelease(_download);
	IMBRelease(_error);
	
	[super dealloc];
} 


//----------------------------------------------------------------------------------------------------------------------


// Get the size (in bytes) of a remote file on the internet. This method is synchronous. This may be a problem
// if we are downloading a lot of files at once. TODO: investigate how we can make this asynchronous, without
// changing the ueser experience of the progress bar...

- (long long) getSize
{
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:self.remoteURL];
	[request setHTTPMethod:@"HEAD"];
	
	NSError* error = nil;
	NSURLResponse* response = nil;
	[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	_bytesTotal = 0;
	if (response != nil && error == nil) _bytesTotal = [response expectedContentLength];
	return _bytesTotal;
}


//----------------------------------------------------------------------------------------------------------------------


// Create a NSURLDownload, start it and spin the runloop until we are done. Since we are in a background thread
// we can block without problems...

- (void) main
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NSString* downloadFolderPath = self.downloadFolderPath;
	NSString* filename = [[self.remoteURL path] lastPathComponent];
	NSString* localFilePath = [downloadFolderPath stringByAppendingPathComponent:filename];

	NSURLRequest* request = [NSURLRequest requestWithURL:self.remoteURL];
	NSURLDownload* download = [[NSURLDownload alloc] initWithRequest:request delegate:self];
	[download setDestination:localFilePath allowOverwrite:NO];
	[download setDeletesFileUponFailure:YES];

	self.download = download;
	[download release];
	
	do 
	{
		CFRunLoopRunInMode(kCFRunLoopDefaultMode,1.0,false);
	}
	while (_finished == NO);
	
	[pool release];
}


- (void) cancel
{
	[self.download cancel];
	
	if (self.localPath)
	{
		NSError* error = nil;
		[[NSFileManager threadSafeManager] removeItemAtPath:self.localPath error:&error];
	}
	
	self.delegate = nil;
	self.download = nil;
	self.finished = YES;
}


//----------------------------------------------------------------------------------------------------------------------


// The file was created (possibly with a modified filename (to make it unique). Store the filename...

- (void) download:(NSURLDownload*)inDownload didCreateDestination:(NSString*)inPath
{
	NSLog(@"%s inPath=%@",__FUNCTION__,inPath);
	self.localPath = inPath;
}


// We received some data. Display the progress...

- (void) download:(NSURLDownload*)inDownload didReceiveDataOfLength:(NSUInteger)inLength
{	
	NSLog(@"%s inLength=%d",__FUNCTION__,(int)inLength);
	_bytesDone += (long long)inLength;
	[_delegate didReceiveData:self];
}


// We are done. Notify the delegate (IMBRemoteObjectPromise) so that it can hide the progress...

- (void) downloadDidFinish:(NSURLDownload*)inDownload
{
	self.error = nil;
	self.finished = YES;
	[_delegate didFinish:self];
	
	self.download = nil;
}


- (void) download:(NSURLDownload*)inDownload didFailWithError:(NSError*)inError
{
	self.error = inError;
	self.finished = YES;
	[_delegate didReceiveError:self];
	
	self.download = nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end