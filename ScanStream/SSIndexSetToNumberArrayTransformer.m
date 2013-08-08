//
//  SSIndexSetToNumberArrayTransformer.m
//  ScanStream
//
//  Copyright (c) 2013 Counsyl, Inc. Released under the MIT license.
//

#import "SSIndexSetToNumberArrayTransformer.h"

@implementation SSIndexSetToNumberArrayTransformer

+ (Class)transformedValueClass
{
    return [NSArray class];
}

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (NSArray *)transformedValue:(NSIndexSet *)value
{
    if (!value) return nil;
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[value count]];
    
    [value enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [array addObject:@(idx)];
    }];
    
    return array;
}

@end
