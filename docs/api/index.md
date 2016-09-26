# API-INDEX


## MODULE: Parameters

---

## Methods [Exported]

[reconstruct{T}(pp::T)](Parameters.md#method__reconstruct.1)  Make a new instance of a type with the same values as

[type2dict(dt)](Parameters.md#method__type2dict.1)  Transforms a type-instance into a dictionary.

---

## Macros [Exported]

[@pack(args)](Parameters.md#macro___pack.1)  Packs variables into a composite type or a `Dict{Symbol}`

[@unpack(args)](Parameters.md#macro___unpack.1)  Unpacks fields/keys from a composite type or a `Dict{Symbol}` into variables

[@with_kw(typedef)](Parameters.md#macro___with_kw.1)  Macro which allows default values for field types and a few other features.

---

## Functions [Internal]

[Parameters.pack!](Parameters.md#function__pack.1)  This function is invoked to pack one entity into some DataType and has

[Parameters.unpack](Parameters.md#function__unpack.1)  This function is invoked to unpack one field/entry of some DataType

---

## Methods [Internal]

[with_kw(typedef)](Parameters.md#method__with_kw.1)  This function is called by the `@with_kw` macro and does the syntax

