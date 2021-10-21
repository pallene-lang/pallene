# Pallene Language Reference

Welcome to the Pallene reference manual.
This is a work in progress, so if you have any questions or suggestions, or if some point wasn't clear, please feel free to ask questions through a Github issue.

## A brief overview of Pallene

Pallene is a statically-typed companion language to Lua.
Pallene functions can be called from Lua and Pallene can call Lua functions as well.

At a first glance, Pallene code looks similar to Lua, but with type annotations.
As a general principle, if a Pallene program runs without errors, then erasing the types and running it as Lua should produce the same result.
The exception are the times when Pallene produces an error, either a compile-time error or a run-time type error.

Here is an example Pallene subroutine for summing the elements in an array of floating-point numbers.
Note that type annotations are required for function argument and return types but for local variable declarations Pallene can often infer the types.

```
local m = {}
function m.sum_floats(xs: {float}): float
    local r = 0.0
    for i = 1, #xs do
        r = r + xs[i]
    end
    return r
end
return m
```

If we put this subroutine in a file named `sum.pln` and pass this file to the `pallenec` compiler, it will output a `sum.so` Lua extension module:

```
$ ./pallenec sum.pln
```

The `sum.so` file can be loaded from within Lua with `require`, as usual:

```
$ ./vm/src/lua
> sum = require "sum"
> print(sum.sum_floats({10.0, 20.0, 30.0})) --> 60.0
```

In this example, we invoke our bundled Lua interpreter because Pallene is only compatible with a specific release version of the interpreter.
The Lua installed in the system might be from an incompatible version.

## The Pallene Type System

Pallene's type system includes the usual Lua primitive types (`nil`, `boolean`, `float` and `integer`), as well as strings, arrays, tables, functions, and records.
There is also a catch-all type `any`, which can refer to any Lua or Pallene value.

### Primitive types

Pallene's primitive types are similar to Lua's:

- `nil`
- `boolean`
- `integer`
- `float`

### Integers and floats

In Pallene there are separate types for `integer` and `float` instead of a single `number` type.
There are no automatic coercions between the two types, meaning that code such as the following is a type error in Pallene:

```
local x: float = 0 -- Type error. Should use 0.0 instead.
```

That said, most arithmetic operators still work if one of the parameters is an integer and the other is a float.
If you just want to convert an integer to float, the recommended idiom is to multiply it by 1.0.

```
local i: integer = 10
local x: float = i + 3.4
local y: float = i * 1.0
```

### Strings

Pallene also has a `string` type, for Lua strings.
The syntax for string literals is the same as in Lua
You can use single quotes, double quotes, or `[[`.

The primitive operators that operate on strings are the concatenation operator `..`,  the length operator `#`, and the comparison operators (`==`, `~=`, `<`, `>`, `<=`, `>=`).

Pallene also implements some functions from the `string` library.
Currently we implement `string.char` and `string.sub`  but more may be implemented in the future.

### Arrays

Array types in Pallene are written `{ t }`, where `t` is any Pallene type. For example, `{ { integer } }` is the type for an array of arrays of integers.

Pallene arrays are implemented as Lua tables, and Pallene also uses the same syntax for array creation:

```
local xs: {integer} = {10, 20, 30}
```

Like Lua, reading from an "out of bounds" index produces `nil`, which results in a run-time type error unless the type of the array elements is `any`.
Notice that Pallene doesn't accept arrays of nil.

One important thing to know about array literals in Pallene is that they must be accompanied by a type annotation.
Pallene cannot infer their type otherwise because expressions like the empty list `{}` don't have an obvious best type.

```
-- This produces a compile-time error
-- "missing type hint for array or record initializer"
local xs = {1.0, 2.0, 3.0}
```

Nevertheless, Pallene is still able to infer then type of an array literal if they appear as an argument to a function, or in another position in the program that has a known expected type.

```
local result = sum_floats({1.0, 2.0, 3.0})
```

### Tables

Table types in Pallene are writen as `{ field: t [, field2: t2, ...] }`, where `field` is an identifier and `t` is any Pallene type.
For instance, `{ x: integer, y: integer }` is the type for a table with the fields `x` and `y` that are integers.

Like arrays, Pallene tables are implemented as Lua tables and Pallene uses the same Lua syntax for their creation:

```
typealias point = {x: integer, y: integer}
local p: point = {x = 10, y = 20}
```

Notice that all fields must be initialized in the Pallene initalizer list, even fields with the type `any` which could be `nil`.
Tables that come from Lua may have absent fields; like Lua, absent fields are considered to be nil.

It is possible to get and set fields in tables using the usual dot syntax:

```
p.x = 30
print(p.x) --> 30
```

In the current version of Pallene, the length of the field should be at max `LUAI_MAXSHORTLEN` characters.
In Lua 5.4, the default value for this constant is 40 characters.

### Functions

Function types in Pallene are created with the `->` type constructor.
For example, `(a, b) -> (c)` is the function type for a function that receives two arguments (the first of type `a` and the second of type `b`) and returns a single value of type `c`.
If the function receives a single input parameter, or returns a single value, the parenthesis can be omitted.
The following are more examples of valid function types:

```
int -> float
(int, int) -> float
(int, int) -> (float, float)
string -> ()
```

The arrow type constructor is right-associative.
That is, `a -> b -> c` means `a -> (b -> c)`.

A Pallene variable of function type may refer to either a statically-typed Pallene function or to a dynamically typed Lua function.
When calling a dynamically-typed Lua function from Pallene, Pallene will check whether the Lua function returned the correct types and number of arguments and it will raise a run-time error if it does not receive what it expected.

### Loops

Pallene supports the usual variety of loops seen in Lua.
Pallene's `for-in` loops carry some semantic importance that might be of relevance to certain users.
An example of such a loop might look like this:

```
local function sum_list(xs: {integer}) do
    local sum: integer = 0
    for _, x: integer in ipairs(xs) do
        sum = sum + x
    end
end
```

The variables on the left hand side of a loop (here `_` and`x`) may optionally
be type annotated.
If no annotation is found, their type is assumed to be `any`.

The right hand side of a for-in loop following "`in`" expects 3 values (or
a call returning 3 values, like `ipairs(xs)`).

The first is the iterator function which accepts 2 arguments, both of type `any`, and returns as many values of type `any` as found in the left hand side of the loop. In this case, the iterator function has type `(any, any) -> (any, any)`.

The second is the `state` variable of type `any` which is the table that the loop is iterating over.

The third and last value is the `control` variable of type `any`.
Under most contexts, it is the current index or slot of the table under inspection.

As an example, consider the same `sum_list` function from above written without `ipairs` using a hand written iterator function:

```
local function iter(arr: {any}, prev: integer): (any, any)
    local i = prev + 1
    local x = arr[i]
    if x == (nil as any) then
        return nil, nil
    end

    return i, x
end

typealias iterfn = (any, any) -> (any, any)
local function my_ipairs(xs: {any}): (iterfn, any, any)
    return iter, xs, 0
end

local function sum_list(xs: {integer}): integer
    local sum = 0
    for _, x: integer in my_ipairs(xs) do
        sum = sum + x
    end
end
```

### Records

Record types in Pallene are nominal and should be declared in the top level.
The following example declares a record `Point` with fields `x` and `y` which are floats.

```
record Point
    x: float
    y: float
end
```

These points are created and used with a similar syntax to Lua:

```
local p: Point = {x = 10.0, y = 20.0}
local r2 = p.x * p.x + p.y * p.y
```

Pallene records are implemented as userdata, and are *not* Lua tables.
You cannot create a Lua table with an `x` and `y` field and pass it to a Pallene function expecting a Point.
The fields of a Pallene record can be directly accessed by Pallene functions using dot notation but are *cannot* be accessed by Lua functions the same way.
From the point of view of Lua, Pallene records are opaque.
If you want to allow Lua to read or write to a field, you shold export appropriate getter and setter functions.

### Any

Variables of type `any` can store any Lua or Pallene value.

```
local x: any = 10
x = "hello"
```

Similarly, arrays of `any` can store anys of varied types

```
local xs: {any} = {10, "hello", 3.14}
```

Upcasting a Pallene value to the `any` type always succeeds.
Pallene also allows you to downcast from `any` to other types.
This is checked at run-time, and may result in a run-time type error.

```
local v = (17 as any)
local s = (v as string)  -- run-time error: v is not a string
```

The `any` type allows for a limited form of dynamic typing.
The main difference compared to Lua is that Pallene does not allow you to perform any operations on a `any`.
You may pass a `any` to a functions and you may store it in an array but you cannot call it, index it, or use it in an arithmetic operation:

```
local function f(x: any, y: any): any
    return x + y -- compile-time type error: Cannot add two anys
end
```

You must first downcast the `any` to the appropriate type.
Sometimes the Pallene compiler can do this automatically for you but in other situations you may need to use an explicit type annotation.
The reason for this is that, for performance, Pallene must know at compile-time what version of the arithmetic operator to use.

```
local function f(x: any, y: any): integer
    return (x as integer) + (y as integer)
end
```

## Structure of a Pallene module

Lua allows many idiomatic ways of defining a module.
Pallene programs, however, must follow a stricter style.
A Pallene module must start with a local variable declaring the module name and it must finish with a return statement returning that variable.
The type annotation for the module variable is optional, but if present it should say "module".
The body of the module consists of a sequence of type declarations, module-local variables, and function definitions.

```
local m: module = {}
-- ...
return m
```

### Type aliases

Creates an alias for a previously-declared type with the following syntax:

```
typealias <name> = <type>
```

Type alias in Pallene currently cannot be used to declare recursive types, such as:

```
typealias T = {T}
```

### Record declarations

Record declarations consist solely of record declarations.

```
record <name>
    <name> : type
    ...
end
```

### Module-local variables

Module-local variables are declared with the following syntax:

```
local <name> [: type] {, <name> [: type]} = <exp> {, <exp>}
```

It is possible to declare multiple variables at once. The behaviour for expressions that are function calls is the same as in Lua.

### Functions

Functions are declared as follows:

```
[local] function <name>([<params>])[: <rettypes>]
    <body>
end
```

A `local` function is only visible inside the module it is defined.
To export a function, have it's name be a field of the module table, e.g. `function m.foo()`.

Functions that are created using a function statement are immutable in Pallene; you may not re-assign them to a different function.
It is a compile-time error to declare two exported functions with the same name.
The return types `<rettypes>` are optional; if not given it is assumed that the function does not return anything.
If the function returns more than one value, you must use parenthesis around the return types.

Parameters are a comma-separated list of `<name>: <type>`.
Two parameters cannot have the same name.

Pallene functions can be recursive.
Blocks of mutually-recursive functions are also allowed, as long as the mutually-recursive functions are declared next to each other, without any type or variable declarations between them.

```
function m.f()
    m.g() -- ok
end
function m.g()
    m.h() -- not allowed
end
local _ = 17
function m.h()
    m.f() -- ok
end
```

To define a block of mutually-recursive local functions you can use a forward declaration.
The forward declaration must be adjacent to the functions.
The functions must also use the function statement syntax, instead of assignment statements.

```
local odd, even
function odd(n:integer): boolean
    if n == 0 then return false else return even(n-1) end
end
function even(n:integer): boolean
    if n == 0 then return true else return odd(n-1) end
end
```

## Expressions and Statements

Pallene uses the same set of operators and control-flow statements as Lua.
The only difference is that the type system is more restrictive:

* The logic operators (`not`, `and`, `or`) only operate on expressions of type `boolean` or of type `any`
* The condition of `if`, `while` and `repeat` must be of type `boolean` or of type `any`
* Relational operators (`==`, `<`, etc) must receive two arguments of the same type.
* The arithmetic and concatenation operators don't automatically coerce between numbers and strings.

## Type annotations and type inference

Pallene is a statically-typed language, which means that every variable and expression has a known type, determined at compilation time.
Sometimes this may be the catch-all type `any`, but it is still known at compilation time.
Similarly to most other statically-typed languages, Pallene allows you to add type annotations to variables, functions, and expressions.
(This is one of the few syntactical differences between Lua and Pallene.)
Pallene type annotations for variables and functions are written using colons.
For expressions the colon is already used for method calls, so Pallene uses the `as` operator instead.

```
function foo(x : any) : integer
   local y: integer = (x as integer)
   return y + y
end
```

Unlike languages like C or Java, Pallene does not require type annotations on every variable.
It uses a bidirectional type-checking system that is able to infer the types of almost all variables and expressions.
Roughly speaking, you must include type annotations for the parameters and return types of top-level functions, and almost everything else can be inferred from that.
For example, notice how the `sum_floats` from the Brief Overview section does not include a type annotation for the `result` and `i` variables.

If a local variable declaration doesn't have an initializer, it must have a type annotation:
```
function contrived(): integer
    local x:integer
    x = 10
    return x
end
```

### Automatic type coercions

In some places in a Pallene program there is a natural "expected type".
For example, the type of a parameter being passed to a function is expected to be the type described by the corresponding function type.
Similarly, there is also an expected type for expressions surrounded by a type annotation, or values being assigned to a variable of known type.

If the expected type of an expression is `any` but the inferred type is something else, Pallene will automatically insert an upcast to `any`.
Similarly, if the inferred type is `any` but the expected type is something else, Pallene will insert a downcast from `any`.
For instance, one of the code examples from the Any section of this manual can be rewritten to use automatic coercions as follows:

```
local v: any  = 17
local s: string = v
```

In addition to allowing conversions to and from `any`, Pallene also makes implicit conversions to and from types that contain `any` in compatible ways.
For example, `{ any }` and `{ integer }` are considered to be compatible, and one may be used where the other is expected.
Similar, for function types `integer -> integer`, `any -> integer`, `integer -> any`, and `any -> any` are all compatible with each other.
These automatic coercions between array and function types never fail at run-time.

To illustrate this, consider the following function for inserting an element in a list.

```
function insert(xs: {any}, v:any)
    xs[#xs + 1] = v
end
```

Since the parameter to the insert function is an array of `any`, we can use it to add elements to lists of any type:

```
local ns: {integer} = {10, 20, 30}
insert(ns, 40)

local ss: {string} = {"hello"}
insert(ss, "world")
```

However, the insert function only guarantees that its first parameter is an array.
If the input is an homogeneous array, the insert function does not ensure that the value being inserted has the same type.
If a value of the "wrong" type is inserted, this will only be noticed when attempting to read from the array.

```
local ns: {integer} = {10, 20, 30}
insert(ns, "boom!")
local x1 : integer = ns[1]
local x2 : integer = ns[4] -- run-time error
```

## Pallene Builtins

### Math Library

The Pallene compiler has builtins for the following math library functions and constants:
 * math.abs(x)
 * math.ceil(x)
 * math.exp(x)
 * math.floor(x)
 * math.fmod(x, y)
 * math.huge
 * math.ln(x)
 * math.log(x, base)
 * math.maxinteger
 * math.mininteger
 * math.modf(x)
 * math.pi
 * math.pow(x, y)
 * math.sqrt(x)

All the functions currently require float arguments. The compiler will reject integer arguments.

At this time, math.log requires two parameters, and the compiler will reject one parameter calls.
So as a workaround, use math.ln in place of the one parameter math.log.

math.modf returns two values, an integer and a float. One minor difference from Lua is that Lua 
may return a float for the first value if some reason it cannot return an integer, such as if
the result is NaN (which only exists in floating point). In Pallene, the first value will always be
converted to an integer unless the conversion fails, in which case a runtime error is raised. 
This is also true of the return values for math.ceil and math.floor, where Pallene will always 
return an integer or raise a runtime error.

## Pallene to Lua translator

There are situations where removal of type annotations are useful.
 * The main premise of Pallene is that it is compatible with Lua.
   This compatibility is defined as removing type annotations from a Pallene program results in transforming it into a Lua program.
   A Pallene to Lua translator will allow us to check whether this property is still valid.
 * Provides greater portability, interoperability and integration with existing Lua codebase and tools.
 * The Pallene developers could check if the unit tests are obeying the "gradual guarantee".
 * In the benchmarks that do not use LuaJIT features, we could generate the Lua version of the code from the Pallene version.

With the help of the Pallene to Lua translator, users can remove Pallene type annotations to generate plain Lua.
You can run the compiler with the flag `--emit-lua` flag to cause the compiler to generate plain Lua instead of C.

Consider the following example written in Pallene.
```
function sum(values: { float }): float
    local s: float = 0.0
    for i = 1, #values do
        s = s + values[i]
    end
    return s
end
```

For the above example, the Pallene to Lua translator produces the following Lua program.
```lua
function sum(values)
    local s = 0.0
    for i = 1, #values do
        s = s + values[i]
    end
    return s
end
```

## The Complete Syntax of Pallene

Here is the complete syntax of Pallene in extended BNF.
As usual, {A} means 0 or more As, and \[A\] means an optional A.

    program ::= {toplevelrecord | topleveltypealias | toplevelvar | toplevelfunc | ';'}

    toplevelrecord ::= record Name {recordfield} end
    recordfield ::= NAME ':' type [';']

    topleveltypealias ::= typealias NAME = type

    toplevelvar ::= local|export NAME [':' type] {',' NAME [':' type]} '=' explist

    toplevelfunc ::= local|export function NAME '(' [paramlist] ')'  [':' typelist ] block end

    paramlist ::= NAME ':' type {',' NAME ':' type}

    type ::= nil | integer | float | boolean | string | any
             | NAME
             | '{' type '}'
             | '{' [tabletypefields] }'
             | typelist '->' typelist

    tabletypefields ::= NAME ':' type { ',' NAME ':' type}

    typelist ::= type | '(' [type, {',' type}] ')'

    block ::= {statement} [returnstat]

    statement ::=  ';' |
        varlist '=' explist |
        funccall |
        do block end |
        while exp do block end |
        repeat block until exp |
        break |
        if exp then block {elseif exp then block} [else block] end |
        forstat |
        local name [':' type] '=' exp

    forstat ::= for NAME [':' type] '=' exp ',' exp [',' exp] do block end |
        for NAME [':' type] {',' NAME [':' type]} in explist do block end

    returnstat ::= return exp [';']

    var ::=  NAME | exp '[' exp ']' | exp '.' Name

    exp ::= nil | false | true | NUMBER | STRING | initlist | exp as type
        | unop exp | exp binop exp | '(' exp ')'
        | NAME | exp '[' exp ']' | exp '.' NAME | funccall

    varlist ::= var {',' var}
    explist ::= exp {',' exp}

    funccall ::= exp funcargs

    funcargs ::= '(' [explist] ')' | initlist | STRING

    initlist ::= '{' fieldlist '}'
    fieldlist ::= [ field {fieldsep field} [fieldsep] ]
    field ::= exp | NAME '=' exp
    fieldsep ::= ',' | ';'

    unop ::= '-' | not | '#' | '~'

    binop ::=  '+' | '-' | '*' | '/' | '//' | '^' | '%' |
        '&' | '~' | '|' | '>>' | '<<' | '..' |
        '<' | '<=' | '>' | '>=' | '==' | '~=' |
        and | or

