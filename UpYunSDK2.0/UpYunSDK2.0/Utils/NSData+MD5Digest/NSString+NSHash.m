//
//  Copyright 2012 Christoph Jerolimov
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License
//

#import "NSString+NSHash.h"

#import <CommonCrypto/CommonDigest.h>

static const char encodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

@implementation NSString (NSHash_AdditionalHashingAlgorithms)

- (NSString*) MD5 {
    unsigned int outputLength = CC_MD5_DIGEST_LENGTH;
    unsigned char output[outputLength];

    CC_MD5(self.UTF8String, [self UTF8Length], output);
    return [self toHexString:output length:outputLength];;
}

- (NSString*) SHA1 {
    unsigned int outputLength = CC_SHA1_DIGEST_LENGTH;
    unsigned char output[outputLength];

    CC_SHA1(self.UTF8String, [self UTF8Length], output);
    return [self toHexString:output length:outputLength];;
}

- (NSString*) SHA256 {
    unsigned int outputLength = CC_SHA256_DIGEST_LENGTH;
    unsigned char output[outputLength];

    CC_SHA256(self.UTF8String, [self UTF8Length], output);
    return [self toHexString:output length:outputLength];;
}

- (unsigned int) UTF8Length {
    return (unsigned int) [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}

- (NSString*) toHexString:(unsigned char*) data length: (unsigned int) length {
    NSMutableString* hash = [NSMutableString stringWithCapacity:length * 2];
    for (unsigned int i = 0; i < length; i++) {
        [hash appendFormat:@"%02x", data[i]];
        data[i] = 0;
    }
    return hash;
}

- (NSString*)Base64encode
{
    if ([self length] == 0)
        return @"";
    
    const char *source = [self UTF8String];
    int strlength  = (int)strlen(source);
    
    char *characters = malloc(((strlength + 2) / 3) * 4);
    if (characters == NULL)
        return nil;
    
    NSUInteger length = 0;
    NSUInteger i = 0;
    
    while (i < strlength) {
        char buffer[3] = {0,0,0};
        short bufferLength = 0;
        while (bufferLength < 3 && i < strlength)
            buffer[bufferLength++] = source[i++];
        characters[length++] = encodingTable[(buffer[0] & 0xFC) >> 2];
        characters[length++] = encodingTable[((buffer[0] & 0x03) << 4) | ((buffer[1] & 0xF0) >> 4)];
        if (bufferLength > 1)
            characters[length++] = encodingTable[((buffer[1] & 0x0F) << 2) | ((buffer[2] & 0xC0) >> 6)];
        else characters[length++] = '=';
        if (bufferLength > 2)
            characters[length++] = encodingTable[buffer[2] & 0x3F];
        else characters[length++] = '=';
    }
    
    return [[NSString alloc] initWithBytesNoCopy:characters length:length encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

@end
