/*
 * Copyright (C) 2003 Apple Computer, Inc.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#import "KWQKLocale.h"

#import "KWQExceptions.h"
#import "KWQLogging.h"
#import "KWQString.h"
#import "WebCoreViewFactory.h"

QString inputElementAltText()
{
    volatile NSString * volatile altText = @"";
    KWQ_BLOCK_NS_EXCEPTIONS;
    altText = [[WebCoreViewFactory sharedFactory] inputElementAltText];
    KWQ_UNBLOCK_NS_EXCEPTIONS;

    return QString::fromNSString((NSString *)altText);
}

QString resetButtonDefaultLabel()
{
    volatile NSString * volatile defaultLabel = @"";

    KWQ_BLOCK_NS_EXCEPTIONS;
    defaultLabel = [[WebCoreViewFactory sharedFactory] resetButtonDefaultLabel];
    KWQ_UNBLOCK_NS_EXCEPTIONS;

    return QString::fromNSString((NSString *)defaultLabel);
}

QString searchableIndexIntroduction()
{
    volatile NSString * volatile introduction = @"";

    KWQ_BLOCK_NS_EXCEPTIONS;
    introduction = [[WebCoreViewFactory sharedFactory] searchableIndexIntroduction];
    KWQ_UNBLOCK_NS_EXCEPTIONS;

    return QString::fromNSString((NSString *)introduction);
}

QString submitButtonDefaultLabel()
{
    volatile NSString * volatile defaultLabel = @"";

    KWQ_BLOCK_NS_EXCEPTIONS;
    defaultLabel = [[WebCoreViewFactory sharedFactory] submitButtonDefaultLabel];
    KWQ_UNBLOCK_NS_EXCEPTIONS;

    return QString::fromNSString((NSString *)defaultLabel);
}

QString KLocale::language()
{
    volatile NSString * volatile code = @"";

    KWQ_BLOCK_NS_EXCEPTIONS;
    code = [[WebCoreViewFactory sharedFactory] defaultLanguageCode];
    KWQ_UNBLOCK_NS_EXCEPTIONS;

    return QString::fromNSString((NSString *)code);
}
