/*
 * Copyright (C) 2004 Apple Computer, Inc.  All rights reserved.
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
#include <Foundation/Foundation.h>


#include <JavaScriptCore/internal.h>

#include <objc_instance.h>
#include <WebScriptObjectPrivate.h>

#include <runtime_array.h>
#include <runtime_object.h>


using namespace KJS;
using namespace KJS::Bindings;

// ---------------------- ObjcMethod ----------------------

ObjcMethod::ObjcMethod(ClassStructPtr aClass, const char *name)
{
    _objcClass = aClass;
    _selector = name;   // Assume ObjC runtime keeps these around forever.
}

const char *ObjcMethod::name() const
{
    return (const char *)_selector;
}

long ObjcMethod::numParameters() const
{
    return [getMethodSignature() numberOfArguments] - 2;
}


NSMethodSignature *ObjcMethod::getMethodSignature() const
{
    return [(id)_objcClass instanceMethodSignatureForSelector:(SEL)_selector];
}

// ---------------------- ObjcField ----------------------


ObjcField::ObjcField(Ivar ivar) 
{
    _ivar = ivar;    // Assume ObjectiveC runtime will keep this alive forever
}

const char *ObjcField::name() const 
{
    return _ivar->ivar_name;
}

RuntimeType ObjcField::type() const 
{
    return _ivar->ivar_type;
}

Value ObjcField::valueFromInstance(KJS::ExecState *exec, const Instance *instance) const
{
    Value aValue;
    char *ivarValuePtr = ((char *)(static_cast<const ObjcInstance*>(instance))->getObject() + _ivar->ivar_offset);

    ObjcValueType ctype = objcValueTypeForType(_ivar->ivar_type);
    switch (ctype){
        case ObjcVoidType: {
            aValue = Undefined();
        }
        break;
        
        case ObjcObjectType: {
            ObjectStructPtr obj = *(ObjectStructPtr *)(ivarValuePtr);
            if ([obj isKindOfClass:[WebScriptObject class]]) {
                WebScriptObject *jsobject = (WebScriptObject *)obj;
                aValue = Object([jsobject _imp]);
            }
            else {
                Instance *anInstance = Instance::createBindingForLanguageInstance (Instance::ObjectiveCLanguage, (void *)obj);
                aValue = Object(new RuntimeObjectImp(anInstance,true));
            }
        }
        break;
        
        case ObjcCharType: {
            char aChar = *(char *)(ivarValuePtr);
            aValue = Number(aChar);
        }
        break;
        
        case ObjcShortType: {
            short aShort = *(short *)(ivarValuePtr);
            aValue = Number(aShort);
        }
        break;
        
        case ObjcIntType: {
            int anInt = *(int *)(ivarValuePtr);
            aValue = Number(anInt);
        }
        break;
        
        case ObjcLongType: {
            long aLong = *(long *)(ivarValuePtr);
            aValue = Number(aLong);
        }
        break;
        
        case ObjcFloatType: {
            float aFloat = *(float *)(ivarValuePtr);
            aValue = Number(aFloat);
        }
        break;
        
        case ObjcDoubleType: {
            double aDouble = *(double *)(ivarValuePtr);
            aValue = Number(aDouble);
        }
        break;
        
        case ObjcInvalidType:
        default: {
            aValue = Error::create(exec, TypeError, "Invalid ObjectiveC type.");
            exec->setException(aValue);
        }
        break;
    }
    return aValue;
}

void ObjcField::setValueToInstance(KJS::ExecState *exec, const Instance *instance, const KJS::Value &aValue) const
{
    char *ivarValuePtr = ((char *)(static_cast<const ObjcInstance*>(instance))->getObject() + _ivar->ivar_offset);

    ObjcValueType ctype = objcValueTypeForType(_ivar->ivar_type);
    ObjcValue result = convertValueToObjcValue(exec, aValue, ctype);
    switch (ctype){
        case ObjcVoidType: {
        }
        break;
        
        case ObjcObjectType: {
            // First see if we have an ObjC instance.
            if (aValue.type() == KJS::ObjectType){
                ObjcValue result = convertValueToObjcValue(exec, aValue, objcValueTypeForType(_ivar->ivar_type));
                
                // Release the previous value.
                [*(ObjectStructPtr *)(ivarValuePtr) autorelease];
                
                // Retain the new value.
                *(ObjectStructPtr *)(ivarValuePtr) = [result.objectValue retain];
            }
            
            // FIXME.  Deal with numbers.
            
            // FIXME.  Deal with arrays.
            
            // FIXME.  Deal with strings.
        }
        break;
        
        case ObjcCharType: {
            *(char *)(ivarValuePtr) = result.charValue;
        }
        break;
        
        case ObjcShortType: {
            *(short *)(ivarValuePtr) = result.shortValue;
        }
        break;
        
        case ObjcIntType: {
            *(int *)(ivarValuePtr) = result.intValue;
        }
        break;
        
        case ObjcLongType: {
            *(long *)(ivarValuePtr) = result.longValue;
        }
        break;
        
        case ObjcFloatType: {
            *(float *)(ivarValuePtr) = result.floatValue;
        }
        break;
        
        case ObjcDoubleType: {
            *(double *)(ivarValuePtr) = result.doubleValue;
        }
        break;
        
        case ObjcInvalidType:
        default: {
            Object error = Error::create(exec, TypeError, "Invalid ObjectiveC type.");
            exec->setException(error);
        }
        break;
    }
}

// ---------------------- ObjcArray ----------------------

ObjcArray::ObjcArray (ObjectStructPtr a) 
{
    _array = [a retain];
};

ObjcArray::~ObjcArray () 
{
    [_array release];
}


ObjcArray::ObjcArray (const ObjcArray &other) : Array() 
{
    if (other._array != _array) {
        [_array release];
        _array = [other._array retain];
    }
};

ObjcArray &ObjcArray::operator=(const ObjcArray &other) {
    if (this == &other)
        return *this;
    
    ObjectStructPtr _oldArray = _array;
    _array = other._array;
    [_array retain];
    [_oldArray release];
    
    return *this;
};

void ObjcArray::setValueAt(KJS::ExecState *exec, unsigned int index, const KJS::Value &aValue) const
{
    if (![_array respondsToSelector:@selector(insertObject:atIndex:)]) {
        Object error = Error::create(exec, TypeError, "Array is not mutable.");
        exec->setException(error);
        return;
    }

    if (index > [_array count]) {
        Object error = Error::create(exec, RangeError, "Index exceeds array size.");
        exec->setException(error);
        return;
    }
    
    // Always try to convert the value to an ObjC object, so it can be placed in the
    // array.
    ObjcValue oValue = convertValueToObjcValue (exec, aValue, ObjcObjectType);

NS_DURING

    [_array insertObject:oValue.objectValue atIndex:index];

NS_HANDLER
    
    Object error = Error::create(exec, GeneralError, "ObjectiveC exception.");
    exec->setException(error);
    
NS_ENDHANDLER
}


KJS::Value ObjcArray::valueAt(KJS::ExecState *exec, unsigned int index) const
{
    ObjectStructPtr obj = 0;
    Object error;
    volatile bool haveError = false;
    
    if (index > [_array count]) {
        Object error = Error::create(exec, RangeError, "Index exceeds array size.");
        exec->setException(error);
        return error;
    }
    
NS_DURING

    obj = [_array objectAtIndex:index];
    
NS_HANDLER
    
    Object error = Error::create(exec, GeneralError, "ObjectiveC exception.");
    exec->setException(error);
    haveError = true;
    
NS_ENDHANDLER

    if (haveError)
        return error;
        
    return convertObjcValueToValue (exec, &obj, ObjcObjectType);
}

unsigned int ObjcArray::getLength() const
{
    return [_array count];
}
