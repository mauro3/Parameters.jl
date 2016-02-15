# API-INDEX


## MODULE: Parameters

---

## Methods [Exported]

[reconstruct{T}(pp::T)](Parameters.md#method__reconstruct.1)  Make a new instance of a type with the same values as

[type2dict(dt)](Parameters.md#method__type2dict.1)  Transforms a type-instance into a dictionary.

---

## Macros [Exported]

[@pack(arg)](Parameters.md#macro___pack.1)  Packs values into a datatype.  The variables need to have the same

[@unpack(arg)](Parameters.md#macro___unpack.1)  Unpacks fields from any datatype (no need to create it with @with_kw):

[@with_kw(typedef)](Parameters.md#macro___with_kw.1)  Macro which allows default values for field types and a few other features.

---

## Methods [Internal]

[with_kw(typedef)](Parameters.md#method__with_kw.1)  This function is called by the `@with_kw` macro and does the AST transformation from:

