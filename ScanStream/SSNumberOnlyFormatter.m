//
//  SSNumberOnlyFormatter.m
//  ScanStream
//
//  Created by Jacob Bandes-Storch on 6/12/13.
//  Copyright (c) 2013 Counsyl. All rights reserved.
//

#import "SSNumberOnlyFormatter.h"

@implementation SSNumberOnlyFormatter

- (NSString *)stringForObjectValue:(id)obj
{
    return obj;
}

- (BOOL)getObjectValue:(out __autoreleasing id *)obj
             forString:(NSString *)string
      errorDescription:(out NSString *__autoreleasing *)error
{
    *obj = string;
    return YES;
}

- (BOOL)isPartialStringValid:(NSString *__autoreleasing *)partialStringPtr
       proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString
       originalSelectedRange:(NSRange)origSelRange
            errorDescription:(NSString *__autoreleasing *)error
{
    return ([*partialStringPtr length] > 0 &&
            [*partialStringPtr rangeOfCharacterFromSet:
             [[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound);
}

@end
