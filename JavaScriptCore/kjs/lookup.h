// -*- c-basic-offset: 2 -*-
/*
 *  This file is part of the KDE libraries
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2003 Apple Computer, Inc.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Steet, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#ifndef _KJSLOOKUP_H_
#define _KJSLOOKUP_H_

#include "interpreter.h"
#include "identifier.h"
#include "object.h"
#include <stdio.h>

namespace KJS {

  /**
   * An entry in a hash table.
   */
  struct HashEntry {
    /**
     * s is the key (e.g. a property name)
     */
    const char *s;

    /**
     * value is the result value (usually an enum value)
     */
    int value;
    /**
     * attr is a set for flags (e.g. the property flags, see object.h)
     */
    short int attr;
    /**
     * params is another number. For property hashtables, it is used to
     * denote the number of argument of the function
     */
    short int params;
    /**
     * next is the pointer to the next entry for the same hash value
     */
    const HashEntry *next;
  };

  /**
   * A hash table
   * Usually the hashtable is generated by the create_hash_table script, from a .table file.
   *
   * The implementation uses an array of entries, "size" is the total size of that array.
   * The entries between 0 and hashSize-1 are the entry points
   * for each hash value, and the entries between hashSize and size-1
   * are the overflow entries for the hash values that need one.
   * The "next" pointer of the entry links entry points to overflow entries,
   * and links overflow entries between them.
   */
  struct HashTable {
    /**
     * type is a version number. Currently always 2
     */
    int type;
    /**
     * size is the total number of entries in the hashtable, including the null entries,
     * i.e. the size of the "entries" array.
     * Used to iterate over all entries in the table
     */
    int size;
    /**
     * pointer to the array of entries
     * Mind that some entries in the array are null (0,0,0,0).
     */
    const HashEntry *entries;
    /**
     * the maximum value for the hash. Always smaller than size.
     */
    int hashSize;
  };

  /**
   * @short Fast keyword lookup.
   */
  class Lookup {
  public:
    /**
     * Find an entry in the table, and return its value (i.e. the value field of HashEntry)
     */
    static int find(const struct HashTable *table, const Identifier &s);
    static int find(const struct HashTable *table,
		    const UChar *c, unsigned int len);


    /**
     * Find an entry in the table, and return the entry
     * This variant gives access to the other attributes of the entry,
     * especially the attr field.
     */
    static const HashEntry* findEntry(const struct HashTable *table,
                                      const Identifier &s);

  };

  class ExecState;
  class UString;
  /**
   * @internal
   * Helper for getStaticFunctionSlot and getStaticPropertySlot
   */
  template <class FuncImp>
  inline JSValue *staticFunctionGetter(ExecState *exec, JSObject *originalObject, const Identifier& propertyName, const PropertySlot& slot)
  {
      // Look for cached value in dynamic map of properties (in JSObject)
      JSObject *thisObj = slot.slotBase();
      JSValue *cachedVal = thisObj->getDirect(propertyName);
      if (cachedVal)
        return cachedVal;

      const HashEntry *entry = slot.staticEntry();
      JSValue *val = new FuncImp(exec, entry->value, entry->params);
      thisObj->putDirect(propertyName, val, entry->attr);
      return val;
  }

  /**
   * @internal
   * Helper for getStaticValueSlot and getStaticPropertySlot
   */
  template <class ThisImp>
  inline JSValue *staticValueGetter(ExecState *exec, JSObject *originalObject, const Identifier&, const PropertySlot& slot)
  {
      ThisImp *thisObj = static_cast<ThisImp *>(slot.slotBase());
      const HashEntry *entry = slot.staticEntry();
      return thisObj->getValueProperty(exec, entry->value);
  }

  /**
   * Helper method for property lookups
   *
   * This method does it all (looking in the hashtable, checking for function
   * overrides, creating the function or retrieving from cache, calling
   * getValueProperty in case of a non-function property, forwarding to parent if
   * unknown property).
   *
   * Template arguments:
   * @param FuncImp the class which implements this object's functions
   * @param ThisImp the class of "this". It must implement the getValueProperty(exec,token) method,
   * for non-function properties.
   * @param ParentImp the class of the parent, to propagate the lookup.
   *
   * Method arguments:
   * @param exec execution state, as usual
   * @param propertyName the property we're looking for
   * @param table the static hashtable for this class
   * @param thisObj "this"
   */
  template <class FuncImp, class ThisImp, class ParentImp>
  inline bool getStaticPropertySlot(ExecState *exec, const HashTable* table, 
                                    ThisImp* thisObj, const Identifier& propertyName, PropertySlot& slot)
  {
    const HashEntry* entry = Lookup::findEntry(table, propertyName);

    if (!entry) // not found, forward to parent
      return thisObj->ParentImp::getOwnPropertySlot(exec, propertyName, slot);

    if (entry->attr & Function)
      slot.setStaticEntry(thisObj, entry, staticFunctionGetter<FuncImp>);
    else 
      slot.setStaticEntry(thisObj, entry, staticValueGetter<ThisImp>);

    return true;
  }

  /**
   * Simplified version of getStaticPropertySlot in case there are only functions.
   * Using this instead of getStaticPropertySlot allows 'this' to avoid implementing 
   * a dummy getValueProperty.
   */
  template <class FuncImp, class ParentImp>
  inline bool getStaticFunctionSlot(ExecState *exec, const HashTable *table, 
                                    JSObject* thisObj, const Identifier& propertyName, PropertySlot& slot)
  {
    const HashEntry* entry = Lookup::findEntry(table, propertyName);

    if (!entry) // not found, forward to parent
      return static_cast<ParentImp *>(thisObj)->ParentImp::getOwnPropertySlot(exec, propertyName, slot);

    assert(entry->attr & Function);

    slot.setStaticEntry(thisObj, entry, staticFunctionGetter<FuncImp>);
    return true;
  }

  /**
   * Simplified version of getStaticPropertySlot in case there are no functions, only "values".
   * Using this instead of getStaticPropertySlot removes the need for a FuncImp class.
   */
  template <class ThisImp, class ParentImp>
  inline bool getStaticValueSlot(ExecState *exec, const HashTable* table, 
                                 ThisImp* thisObj, const Identifier &propertyName, PropertySlot& slot)
  {
    const HashEntry* entry = Lookup::findEntry(table, propertyName);

    if (!entry) // not found, forward to parent
      return thisObj->ParentImp::getOwnPropertySlot(exec, propertyName, slot);

    assert(!(entry->attr & Function));

    slot.setStaticEntry(thisObj, entry, staticValueGetter<ThisImp>);
    return true;
  }

  /**
   * This one is for "put".
   * Lookup hash entry for property to be set, and set the value.
   */
  template <class ThisImp, class ParentImp>
  inline void lookupPut(ExecState *exec, const Identifier &propertyName,
                        JSValue *value, int attr,
                        const HashTable* table, ThisImp* thisObj)
  {
    const HashEntry* entry = Lookup::findEntry(table, propertyName);

    if (!entry) // not found: forward to parent
      thisObj->ParentImp::put(exec, propertyName, value, attr);
    else if (entry->attr & Function) // function: put as override property
      thisObj->JSObject::put(exec, propertyName, value, attr);
    else if (entry->attr & ReadOnly) // readonly! Can't put!
#ifdef KJS_VERBOSE
      fprintf(stderr,"WARNING: Attempt to change value of readonly property '%s'\n",propertyName.ascii());
#else
      ; // do nothing
#endif
    else
      thisObj->putValueProperty(exec, entry->value, value, attr);
  }
  
  /**
   * This template method retrieves or create an object that is unique
   * (for a given interpreter) The first time this is called (for a given
   * property name), the Object will be constructed, and set as a property
   * of the interpreter's global object. Later calls will simply retrieve
   * that cached object. Note that the object constructor must take 1 argument, exec.
   */
  template <class ClassCtor>
  inline JSObject *cacheGlobalObject(ExecState *exec, const Identifier &propertyName)
  {
    JSObject *globalObject = static_cast<JSObject *>(exec->lexicalInterpreter()->globalObject());
    JSValue *obj = globalObject->getDirect(propertyName);
    if (obj) {
      assert(obj->isObject());
      return static_cast<JSObject *>(obj);
    }
    JSObject *newObject = new ClassCtor(exec);
    globalObject->put(exec, propertyName, newObject, Internal);
    return newObject;
  }

  /**
   * Helpers to define prototype objects (each of which simply implements
   * the functions for a type of objects).
   * Sorry for this not being very readable, but it actually saves much copy-n-paste.
   * ParentProto is not our base class, it's the object we use as fallback.
   * The reason for this is that there should only be ONE DOMNode.hasAttributes (e.g.),
   * not one in each derived class. So we link the (unique) prototypes between them.
   *
   * Using those macros is very simple: define the hashtable (e.g. "DOMNodeProtoTable"), then
   * KJS_DEFINE_PROTOTYPE(DOMNodeProto)
   * KJS_IMPLEMENT_PROTOFUNC(DOMNodeProtoFunc)
   * KJS_IMPLEMENT_PROTOTYPE("DOMNode", DOMNodeProto,DOMNodeProtoFunc)
   * and use DOMNodeProto::self(exec) as prototype in the DOMNode constructor.
   * If the prototype has a "parent prototype", e.g. DOMElementProto falls back on DOMNodeProto,
   * then the last line will use IMPLEMENT_PROTOTYPE_WITH_PARENT, with DOMNodeProto as last argument.
   */
#define KJS_DEFINE_PROTOTYPE(ClassProto) \
  class ClassProto : public JSObject { \
    friend JSObject *cacheGlobalObject<ClassProto>(ExecState *exec, const Identifier &propertyName); \
  public: \
    static JSObject *ClassProto::self(ExecState *exec); \
    virtual const ClassInfo *classInfo() const { return &info; } \
    static const ClassInfo info; \
    bool getOwnPropertySlot(ExecState *, const Identifier&, PropertySlot&); \
  protected: \
    ClassProto( ExecState *exec ) \
      : JSObject( exec->lexicalInterpreter()->builtinObjectPrototype() ) {} \
    \
  };

#define KJS_IMPLEMENT_PROTOTYPE(ClassName, ClassProto,ClassFunc) \
    const ClassInfo ClassProto::info = { ClassName, 0, &ClassProto##Table, 0 }; \
    JSObject *ClassProto::self(ExecState *exec) \
    { \
      return cacheGlobalObject<ClassProto>(exec, "[[" ClassName ".prototype]]"); \
    } \
    bool ClassProto::getOwnPropertySlot(ExecState *exec, const Identifier& propertyName, PropertySlot& slot) \
    { \
      return getStaticFunctionSlot<ClassFunc,JSObject>(exec, &ClassProto##Table, this, propertyName, slot); \
    }

#define KJS_IMPLEMENT_PROTOTYPE_WITH_PARENT(ClassName, ClassProto,ClassFunc,ParentProto)  \
    const ClassInfo ClassProto::info = { ClassName, 0, &ClassProto##Table, 0 }; \
    JSObject *ClassProto::self(ExecState *exec) \
    { \
      return cacheGlobalObject<ClassProto>(exec, "[[" ClassName ".prototype]]"); \
    } \
    bool ClassProto::getOwnPropertySlot(ExecState *exec, const Identifier& propertyName, PropertySlot& slot) \
    { \
      if (getStaticFunctionSlot<ClassFunc,JSObject>(exec, &ClassProto##Table, this, propertyName, slot)) \
          return true; \
      return ParentProto::self(exec)->getOwnPropertySlot(exec, propertyName, slot); \
    }

#define KJS_IMPLEMENT_PROTOFUNC(ClassFunc) \
  class ClassFunc : public DOMFunction { \
  public: \
    ClassFunc(ExecState *exec, int i, int len) : id(i) \
    { \
       put(exec, lengthPropertyName, jsNumber(len), DontDelete|ReadOnly|DontEnum); \
    } \
    /* Macro user needs to implement the callAsFunction function. */ \
    virtual JSValue *callAsFunction(ExecState *exec, JSObject *thisObj, const List &args); \
  private: \
    int id; \
  };

  /*
   * List of things to do when porting an objectimp to the 'static hashtable' mechanism:
   * - write the hashtable source, between @begin and @end
   * - add a rule to build the .lut.h
   * - include the .lut.h
   * - mention the table in the classinfo (add a classinfo if necessary)
   * - write/update the class enum (for the tokens)
   * - turn get() into getValueProperty(), put() into putValueProperty(), using a switch and removing funcs
   * - write get() and/or put() using a template method
   * - cleanup old stuff (e.g. hasProperty)
   * - compile, test, commit ;)
   */
} // namespace

#endif
