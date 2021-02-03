---
title: "Haskell's @ symbol - Type Application"
summary: Demystifying a powerful language extension that powers the IHP framework
keywords: haskell ihp @ type application language extension
date: 2021-02-03T10:22:06-05:00
---

[IHP](https://ihp.digitallyinduced.com) uses lots of [GHC language extensions](https://downloads.haskell.org/~ghc/latest/docs/html/users_guide/glasgow_exts.html) to  create the
"magic" that comes along with the framework. One the the first nonstandard language extensions
you'll come across while developing with IHP is the fancy "@" symbol.

```haskell
action UsersAction = do
    users <- query @User |> fetch
    render IndexView { .. }
```

`@User` appears like a normal parameter to the function, which can be highly misleading if you try and extrapolate this idea into other contexts.
When I first started working with IHP, I assumed this was the equivalent to
Swift's `self` property on types, which gives you a *value* representing the type that can be passed around:

```swift
let typeOfInt = Int.self
```

This is not the case however!

```haskell
let
  typeOfUser = @User
in
  -- parse error!
```

So what's actually happening here?

### What's the type?

Say we want to test the behavior of Haskell's `read` and `show` functions, which
each have a corresponding type class which defines which values can be passed to these functions.

```haskell
read :: (Read a) => String -> a
show :: (Show a) => a -> String
```

Given any value which has both `Read` and `Show` instances defined, we should be able to convert back and forth between it and its String representation.

Let's test for integers:

```haskell
let intString = "123"
read intString

*** Exception: Prelude.read: no parse
```

Huh? Of course `read` should know how to parse a simple integer, right?

If you think about the above code carefully, you might notice that Haskell
has no way of knowing what type `read intString` should be! Obviously to us it
represents an integer, but in Haskell's eyes it's given an arbitrary string
and has no way of knowing which instance of the type class `Read` it should produce.

### @ me bro

Type application to the rescue! The "@" symbol allows us to explicity pass
a type to the function:

```haskell
let intString = "123"
read @Int intString

123
```

Note, `@Int` is **not a regular parameter!**
The regular parameters we're used to working with are actually called
*value parameters*, and `read` only has one: a String.

Behind the scenes, Haskell also includes *type parameters* which specify
the types that satisfy a function's *constraints*, or the stuff before
the `=>` symbol in function declarations.

Normally Haskell can do this for us:
```
readFn :: String -> Int
readFn intString = read intString

readFn "123"

123
```

Since the function returns an Int, the type parameter can be inferred.
In the simple example earlier however, this was not the case.

## Type Application in IHP

Say we're writing a script that wants to print out the name of the newest user to signup for our application.

```haskell
run :: Script
run = do
    user <- query @User |> orderBy #createdAt |> fetchOne
    print (get #createdAt user)
```

To understand what `@User` is doing, we need to look at the definition of `query`:

```haskell
query :: forall model table. table ~ GetTableName model => DefaultScope table => QueryBuilder table
```

`query` doesn't take any value parameters! All the info that gets passed to the function is contained in its type constraints. So if we omitted `@User`, Haskell would have no way of knowing what the `model` type should be.

## Conclusion

Type application is extremely powerful and is used all over both the
IHP codebase and IHP applications. Understanding what's going on when you see
the `@` symbol is a good first step for uncovering some of the "magic" behind
the framework.

Does anything else in IHP confuse you? Let me know below and I will write about
it in a future article! Thanks for reading!
