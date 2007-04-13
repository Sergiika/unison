#import "ReconItem.h"
#include <caml/callback.h>
#include <caml/memory.h>

extern value Callback_checkexn(value,value);
extern value Callback2_checkexn(value,value,value);

@implementation ReconItem

-(void)dealloc
{
    ri = Val_unit;
    caml_remove_global_root(&ri);
    [super dealloc];
}

- (void)setRi:(value)v
{
    caml_register_global_root(&ri); // needed in case of ocaml garbage collection
    ri = v;
    resolved = NO;
    directionSortString = @"";
}

- (void)setIndex:(int)i
{
    index = i;
}

- (BOOL)selected
{
    return selected;
}

- (void)setSelected:(BOOL)x
{
    selected = x;
}

- init
{
    if ((self = [super init])) {
        resolved = NO;
        selected = NO; // NB only used/updated during sorts. Not a 
                       // reliable indicator of whether item is selected
    }

    return self;
}

+ (id)initWithRiAndIndex:(value)v index:(int)i
{
    ReconItem *r = [[ReconItem alloc] init];
    [r setRi:v];
    [r setIndex:i];
    return r;
}

- (NSString *)path
{
    if (path) return path;
    
    value *f = caml_named_value("unisonRiToPath");
    [path release];
    path = [NSString stringWithCString:String_val(Callback_checkexn(*f, ri))];
    [path retain];
    return path;
}

- (NSString *)left
{
    if (left) return left;
    
    value *f = caml_named_value("unisonRiToLeft");
    [left release];
    left = [NSString stringWithCString:String_val(Callback_checkexn(*f, ri))];
    [left retain];
    return left;
}

- (NSString *)right
{
    if (right) return right;
    
    value *f = caml_named_value("unisonRiToRight");
    [right release];
    right = [NSString stringWithCString:String_val(Callback_checkexn(*f, ri))];
    [right retain];
    return right;
}

- (NSImage *)direction
{
    if (direction) return direction;
    
    value *f = caml_named_value("unisonRiToDirection");
    value v = Callback_checkexn(*f, ri);
    char *s = String_val(v);
    [direction release];
    NSString * dirString = [NSString stringWithCString:s];

    BOOL changedFromDefault = [self changedFromDefault];
    
    if ([dirString isEqual:@"<-?->"]) {
        if (changedFromDefault | resolved) {
            direction = [NSImage imageNamed: @"table-skip.tif"];
	    directionSortString = @"3";
	}
        else {
            direction = [NSImage imageNamed: @"table-conflict.tif"];
	    directionSortString = @"2";
        }
    }
    
    else if ([dirString isEqual:@"---->"]) {
        if (changedFromDefault) {
            direction = [NSImage imageNamed: @"table-right-blue.tif"];
            directionSortString = @"6";
        }
	else {
            direction = [NSImage imageNamed: @"table-right-green.tif"];
            directionSortString = @"8";
        }
    }
    
    else if ([dirString isEqual:@"<----"]) {
        if (changedFromDefault) {
            direction = [NSImage imageNamed: @"table-left-blue.tif"];
            directionSortString = @"5";
        }
        else {
            direction = [NSImage imageNamed: @"table-left-green.tif"];
            directionSortString = @"7";
        }
    }

    else if ([dirString isEqual:@"<-M->"]) {
        direction = [NSImage imageNamed: @"table-merge.tif"];
        directionSortString = @"4";
    }

    else {
        direction = [NSImage imageNamed: @"table-error.tif"];
        directionSortString = @"1";
    }
    
    [direction retain];
    return direction;
}

- (void)setDirection:(char *)d
{
    [direction release];
    direction = nil;
    value *f = caml_named_value(d);
    Callback_checkexn(*f, ri);
}

- (void)doAction:(unichar)action
{
    switch (action) {
    case '>':
        [self setDirection:"unisonRiSetRight"];
        break;
    case '<':
        [self setDirection:"unisonRiSetLeft"];
        break;
    case '/':
        [self setDirection:"unisonRiSetConflict"];
        resolved = YES;
        break;
    case '-':
        [self setDirection:"unisonRiForceOlder"];
        break;
    case '+':
        [self setDirection:"unisonRiForceNewer"];
        break;
    case 'm':
        [self setDirection:"unisonRiSetMerge"];
        break;
    case 'd':
        [self showDiffs];
        break;
    default:
        NSLog(@"ReconItem.doAction : unknown action");
        break;
    }
}

- (void)doIgnore:(unichar)action
{
    value *f;
    switch (action) {
    case 'I':
        f = caml_named_value("unisonIgnorePath");
        Callback_checkexn(*f, ri);
        break;
    case 'E':
        f = caml_named_value("unisonIgnoreExt");
        Callback_checkexn(*f, ri);
        break;
    case 'N':
        f = caml_named_value("unisonIgnoreName");
        Callback_checkexn(*f, ri);
        break;
    default:
        NSLog(@"ReconItem.doIgnore : unknown ignore");
        break;
    }
}

- (NSString *)progress
{
    if (progress) return progress;
    
    value *f = caml_named_value("unisonRiToProgress");
    progress = [NSString stringWithCString:String_val(Callback_checkexn(*f, ri))];
    [progress retain];
    if ([progress isEqual:@"FAILED"]) [self updateDetails];
    return progress;
}

- (void)resetProgress
{
    // Get rid of the memoized progress because we expect it to change
    [progress release];
    progress = nil;
}

- (NSString *)details
{
    if (details) return details;
    return [self updateDetails];
}

- (NSString *)updateDetails
{
    value *f = caml_named_value("unisonRiToDetails");
    details = [NSString stringWithCString:String_val(Callback_checkexn(*f, ri))];
    [details retain];
    return details;
}

- (BOOL)isConflict
{
    value *f = caml_named_value("unisonRiIsConflict");
    if (Callback_checkexn(*f, ri) == Val_true) return YES;
    else return NO;
}

- (BOOL)changedFromDefault
{
    value *f = caml_named_value("changedFromDefault");
    if (Callback_checkexn(*f, ri) == Val_true) return YES;
    else return NO;
}

- (void)revertDirection
{
    value *f = caml_named_value("unisonRiRevert");
    Callback_checkexn(*f, ri);
    [direction release];
    direction = nil;
    resolved = NO;
}

- (BOOL)canDiff
{
    value *f = caml_named_value("canDiff");
    if (Callback_checkexn(*f, ri) == Val_true) return YES;
    else return NO;
}

- (void)showDiffs
{
    value *f = caml_named_value("runShowDiffs");
    Callback2_checkexn(*f, ri, Val_int(index));
}

/* Sorting functions. These have names equal to
   column identifiers + "SortKey", and return NSStrings that
   can be automatically sorted with their compare method */

- (NSString *) leftSortKey
{
    return [self replicaSortKey:[self left]];
}

- (NSString *) rightSortKey
{
    return [self replicaSortKey:[self right]];
}

- (NSString *) replicaSortKey:(NSString *)sortString
{
    /* sort order for left and right replicas */

    if ([sortString isEqualToString:@"Created"]) return @"1";
    else if ([sortString isEqualToString:@"Deleted"]) return @"2";
    else if ([sortString isEqualToString:@"Modified"]) return @"3";
    else if ([sortString isEqualToString:@""]) return @"4";
    else return @"5";
}

- (NSString *) directionSortKey
{
    /* Since the direction indicators are unsortable images, use
       directionSortString instead */

    if ([directionSortString isEqual:@""])
        [self direction];
    return directionSortString;
}

- (NSString *) progressSortKey
{
    /* Percentages, "done" and "" are sorted OK without help,
       but "start " should be sorted after "" and before "0%" */

    NSString * progressString = [self progress];
    if ([progressString isEqualToString:@"start "]) progressString = @" ";
    return progressString;
}

- (NSString *) pathSortKey
{
    /* default alphanumeric sort is fine for paths */
    return [self path];
}

@end