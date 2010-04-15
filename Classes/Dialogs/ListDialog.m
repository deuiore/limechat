// Created by Satoshi Nakagawa.
// You can redistribute it and/or modify it under the Ruby's license or the GPL2.

#import "ListDialog.h"


@interface ListDialog (Private)
- (void)sortedInsert:(NSArray*)item;
- (void)reloadTable;
@end


@implementation ListDialog

@synthesize delegate;
@synthesize sortKey;
@synthesize sortOrder;

- (id)init
{
	if (self = [super init]) {
		[NSBundle loadNibNamed:@"ListDialog" owner:self];
		
		list = [NSMutableArray new];
		sortKey = 1;
		sortOrder = NSOrderedDescending;
	}
	return self;
}

- (void)dealloc
{
	[list release];
	[filteredList release];
	[super dealloc];
}

- (void)start
{
	[table setDoubleAction:@selector(onJoin:)];
	
	[self show];
}

- (void)show
{
	if (![self.window isVisible]) {
		[self.window center];
	}
	
	[self.window makeKeyAndOrderFront:nil];
}

- (void)close
{
	[self.window close];
}

- (void)clear
{
	[list removeAllObjects];
	[filteredList release];
	filteredList = nil;
	
	[self reloadTable];
}

- (void)addChannel:(NSString*)channel count:(int)count topic:(NSString*)topic
{
	NSArray* item = [NSArray arrayWithObjects:channel, [NSNumber numberWithInt:count], topic, nil];
	[self sortedInsert:item];
	[self reloadTable];
}

- (void)reloadTable
{
	[table reloadData];
}

static NSInteger compareItems(NSArray* self, NSArray* other, void* context)
{
	ListDialog* dialog = (ListDialog*)context;
	int key = dialog.sortKey;
	NSComparisonResult order = dialog.sortOrder;
	
	NSString* mine = [self objectAtIndex:key];
	NSString* others = [other objectAtIndex:key];
	
	NSComparisonResult result;
	if (key == 1) {
		result = [mine compare:others];
	}
	else {
		result = [mine caseInsensitiveCompare:others];
	}
	
	if (order == NSOrderedDescending) {
		return - result;
	}
	else {
		return result;
	}
}

- (void)sort
{
	[list sortUsingFunction:compareItems context:self];
}

- (void)sortedInsert:(NSArray*)item
{
	const int THRESHOLD = 5;
	int left = 0;
	int right = list.count;
	NSMutableArray* ary = list;
	
	while (right - left > THRESHOLD) {
		int pivot = (left + right) / 2;
		if (compareItems([ary objectAtIndex:pivot], item, self) == NSOrderedDescending) {
			right = pivot;
		}
		else {
			left = pivot;
		}
	}
	
	for (int i=left; i<right; ++i) {
		if (compareItems([ary objectAtIndex:i], item, self) == NSOrderedDescending) {
			[ary insertObject:item atIndex:i];
			return;
		}
	}
	
	[ary insertObject:item atIndex:right];
}

#pragma mark -
#pragma mark Actions

- (void)onClose:(id)sender
{
	[self.window close];
}

- (void)onUpdate:(id)sender
{
	if ([delegate respondsToSelector:@selector(listDialogOnUpdate:)]) {
		[delegate listDialogOnUpdate:self];
	}
}

- (void)onJoin:(id)sender
{
	NSIndexSet* set = [table selectedRowIndexes];
	NSUInteger i = [set firstIndex];
	while (i != NSNotFound) {
		NSArray* item = [list objectAtIndex:i];
		
		if ([delegate respondsToSelector:@selector(listDialogOnJoin:channel:)]) {
			[delegate listDialogOnJoin:self channel:[item objectAtIndex:0]];
		}
		
		i = [set indexGreaterThanIndex:i];
	}
}

- (void)onSearchFieldChange:(id)sender
{
	[filteredList release];
	filteredList = nil;

	NSString* filter = [filterText stringValue];
	if (filter.length) {
		NSMutableArray* ary = [NSMutableArray new];
		for (NSArray* item in list) {
			NSString* channel = [item objectAtIndex:0];
			NSString* topic = [item objectAtIndex:2];
			if ([channel rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound
				|| [topic rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound) {
				[ary addObject:item];
			}
		}
		filteredList = ary;
	}
	
	[self reloadTable];
}

#pragma mark -
#pragma mark NSTableView Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)sender
{
	if (filteredList) {
		return filteredList.count;
	}
	return list.count;
}

- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row
{
	NSArray* ary = filteredList ?: list;
	NSArray* item = [ary objectAtIndex:row];
	NSString* col = [column identifier];
	
	if ([col isEqualToString:@"chname"]) {
		return [item objectAtIndex:0];
	}
	else if ([col isEqualToString:@"count"]) {
		return [item objectAtIndex:1];
	}
	else {
		return [item objectAtIndex:2];
	}
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)column
{
	int i;
	NSString* col = [column identifier];
	if ([col isEqualToString:@"chname"]) {
		i = 0;
	}
	else if ([col isEqualToString:@"count"]) {
		i = 1;
	}
	else {
		i = 2;
	}
	
	if (sortKey == i) {
		sortOrder = - sortOrder;
	}
	else {
		sortKey = i;
		sortOrder = (sortKey == 1) ? NSOrderedDescending : NSOrderedAscending;
	}
	
	[self sort];
	
	if (filteredList) {
		[self onSearchFieldChange:nil];
	}
	
	[self reloadTable];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification*)note
{
	if ([delegate respondsToSelector:@selector(listDialogWillClose:)]) {
		[delegate listDialogWillClose:self];
	}
}

@end
