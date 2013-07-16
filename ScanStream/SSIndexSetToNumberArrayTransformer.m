//
//  SSIndexSetToNumberArrayTransformer.m
//  ScanStream
//
//  Created by Jacob Bandes-Storch on 7/16/13.
//  Copyright (c) 2013 Counsyl. All rights reserved.
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
