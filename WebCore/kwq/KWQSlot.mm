/*
 * Copyright (C) 2002 Apple Computer, Inc.  All rights reserved.
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

#import "KWQSlot.h"

#import <KWQAssertions.h>

#import <dom_docimpl.h>
#import <khtml_part.h>
#import <render_form.h>

using DOM::DocumentImpl;
using khtml::RenderCheckBox;
using khtml::RenderFileButton;
using khtml::RenderFormElement;
using khtml::RenderLineEdit;
using khtml::RenderSelect;
using khtml::RenderTextArea;
using KIO::Job;

enum FunctionNumber {
    signalFinishedParsing,
    slotAutoScroll,
    slotChildCompleted,
    slotChildCompletedWithBool,
    slotChildStarted,
    slotClicked,
    slotFinishedParsing,
    slotParentCompleted,
    slotRedirect,
    slotReturnPressed,
    slotSelected,
    slotSelectionChanged,
    slotStateChanged,
    slotTextChanged,
    slotTextChangedWithString
};

KWQSlot::KWQSlot(QObject *object, const char *member) : m_object(0)
{
    if (KWQNamesMatch(member, SIGNAL(finishedParsing()))) {
        ASSERT(dynamic_cast<DocumentImpl *>(object));
        m_function = signalFinishedParsing;
    } else if (KWQNamesMatch(member, SLOT(slotAutoScroll()))) {
        ASSERT(dynamic_cast<KHTMLPart *>(object));
        m_function = slotAutoScroll;
    } else if (KWQNamesMatch(member, SLOT(slotClicked()))) {
        ASSERT(dynamic_cast<RenderFormElement *>(object));
        m_function = slotClicked;
    } else if (KWQNamesMatch(member, SLOT(slotChildCompleted()))) {
        ASSERT(dynamic_cast<KHTMLPart *>(object));
        m_function = slotChildCompleted;
    } else if (KWQNamesMatch(member, SLOT(slotChildCompleted(bool)))) {
        ASSERT(dynamic_cast<KHTMLPart *>(object));
        m_function = slotChildCompletedWithBool;
    } else if (KWQNamesMatch(member, SLOT(slotChildStarted(KIO::Job *)))) {
        ASSERT(dynamic_cast<KHTMLPart *>(object));
        m_function = slotChildStarted;
    } else if (KWQNamesMatch(member, SLOT(slotFinishedParsing()))) {
        ASSERT(dynamic_cast<KHTMLPart *>(object));
        m_function = slotFinishedParsing;
    } else if (KWQNamesMatch(member, SLOT(slotParentCompleted()))) {
        ASSERT(dynamic_cast<KHTMLPart *>(object));
        m_function = slotParentCompleted;
    } else if (KWQNamesMatch(member, SLOT(slotRedirect()))) {
        ASSERT(dynamic_cast<KHTMLPart *>(object));
        m_function = slotRedirect;
    } else if (KWQNamesMatch(member, SLOT(slotReturnPressed()))) {
        ASSERT(dynamic_cast<RenderLineEdit *>(object) || dynamic_cast<RenderFileButton *>(object));
        m_function = slotReturnPressed;
    } else if (KWQNamesMatch(member, SLOT(slotSelected(int)))) {
        ASSERT(dynamic_cast<RenderSelect *>(object));
        m_function = slotSelected;
    } else if (KWQNamesMatch(member, SLOT(slotSelectionChanged()))) {
        ASSERT(dynamic_cast<RenderSelect *>(object));
        m_function = slotSelectionChanged;
    } else if (KWQNamesMatch(member, SLOT(slotStateChanged(int)))) {
        ASSERT(dynamic_cast<RenderCheckBox *>(object));
        m_function = slotStateChanged;
    } else if (KWQNamesMatch(member, SLOT(slotTextChanged()))) {
        ASSERT(dynamic_cast<RenderTextArea *>(object));
        m_function = slotTextChanged;
    } else if (KWQNamesMatch(member, SLOT(slotTextChanged(const QString &)))) {
        ASSERT(dynamic_cast<RenderLineEdit *>(object) || dynamic_cast<RenderFileButton *>(object));
        m_function = slotTextChangedWithString;
    } else {
        ERROR("trying to create a slot for unknown member %s", member);
        return;
    }
    m_object = object;
}
    
void KWQSlot::call() const
{
    if (!m_object) {
        return;
    }
    
    #define CASE(member, type, function) \
        case member: { \
            type *o = dynamic_cast<type *>(m_object.pointer()); \
            if (o) { \
                o->function(); \
            } \
            return; \
        }
    
    switch (m_function) {
        CASE(signalFinishedParsing, DocumentImpl, m_finishedParsing.call)
        CASE(slotAutoScroll, KHTMLPart, slotAutoScroll)
        CASE(slotChildCompleted, KHTMLPart, slotChildCompleted)
        CASE(slotClicked, RenderFormElement, slotClicked)
        CASE(slotFinishedParsing, KHTMLPart, slotFinishedParsing)
        CASE(slotParentCompleted, KHTMLPart, slotParentCompleted)
        CASE(slotRedirect, KHTMLPart, slotRedirect)
        CASE(slotSelectionChanged, RenderSelect, slotSelectionChanged)
        CASE(slotTextChanged, RenderTextArea, slotTextChanged)
        
        case slotReturnPressed: {
            RenderLineEdit *edit = dynamic_cast<RenderLineEdit *>(m_object.pointer());
            if (edit) {
                edit->slotReturnPressed();
            }
            RenderFileButton *button = dynamic_cast<RenderFileButton *>(m_object.pointer());
            if (button) {
                edit->slotReturnPressed();
            }
            return;
        }
    }
    
    #undef CASE
}

void KWQSlot::call(bool b) const
{
    if (!m_object) {
        return;
    }
    
    #define CASE(member, type, function) \
        case member: { \
            type *o = dynamic_cast<type *>(m_object.pointer()); \
            if (o) { \
                o->function(b); \
            } \
            return; \
        }
    
    switch (m_function) {
        CASE(slotChildCompletedWithBool, KHTMLPart, slotChildCompleted)
    }
    
    #undef CASE
    
    call();
}

void KWQSlot::call(int i) const
{
    if (!m_object) {
        return;
    }
    
    switch (m_function) {
        case slotStateChanged: {
            RenderCheckBox *checkBox = dynamic_cast<RenderCheckBox *>(m_object.pointer());
            if (checkBox) {
                checkBox->slotStateChanged(i);
            }
            return;
        }
        case slotSelected: {
            RenderSelect *select = dynamic_cast<RenderSelect *>(m_object.pointer());
            if (select) {
                select->slotSelected(i);
            }
            return;
        }
    }
    
    call();
}

void KWQSlot::call(const QString &string) const
{
    if (!m_object) {
        return;
    }
    
    switch (m_function) {
        case slotTextChangedWithString: {
            RenderLineEdit *edit = dynamic_cast<RenderLineEdit *>(m_object.pointer());
            if (edit) {
                edit->slotTextChanged(string);
            }
            RenderFileButton *button = dynamic_cast<RenderFileButton *>(m_object.pointer());
            if (button) {
                edit->slotTextChanged(string);
            }
            return;
        }
    }
    
    call();
}

void KWQSlot::call(Job *job) const
{
    if (!m_object) {
        return;
    }
    
    switch (m_function) {
        case slotChildStarted: {
            KHTMLPart *part = dynamic_cast<KHTMLPart *>(m_object.pointer());
            if (part) {
                part->slotChildStarted(job);
            }
            return;
        }
    }
    
    call();
}

bool operator==(const KWQSlot &a, const KWQSlot &b)
{
    return a.m_object == b.m_object && (a.m_object == 0 || a.m_function == b.m_function);
}

bool KWQNamesMatch(const char *a, const char *b)
{
    char ca = *a;
    char cb = *b;
    
    for (;;) {
        while (ca == ' ') {
            ca = *++a;
        }
        while (cb == ' ') {
            cb = *++b;
        }
        
        if (ca != cb) {
            return false;
        }
        if (ca == 0) {
            return true;
        }
        
        ca = *++a;
        cb = *++b;
    }
}
