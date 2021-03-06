[![Build Status](https://travis-ci.org/esmolanka/sexp-grammar.svg?branch=master)](https://travis-ci.org/esmolanka/sexp-grammar)

sexp-grammar
============

Invertible syntax library for serializing and deserializing Haskell structures
into S-expressions. Just write a grammar once and get both parser and
pretty-printer, for free.

**WARNING: highly unstable and experimental software. Not intended for production**

The approach used in `sexp-grammar` is inspired by the paper
[Invertible syntax descriptions: Unifying parsing and pretty printing]
(http://www.informatik.uni-marburg.de/~rendel/unparse/) and a similar
implementation of invertible grammar approach for JSON, library by Martijn van
Steenbergen called [JsonGrammar2](https://github.com/MedeaMelana/JsonGrammar2).

Let's take a look at example:

```haskell
import Language.SexpGrammar
import Language.SexpGrammar.Generic

data Person = Person
  { pName    :: String
  , pAddress :: String
  , pAge     :: Maybe Int
  } deriving (Show, Generic)

personGrammar :: SexpG Person
personGrammar = with $                -- Person is isomorphic to:
  list (                              -- a list with
    el (sym "person") >>>             -- a symbol "person",
    el string'        >>>             -- a string, and
    props (                           -- a property-list with
      Kw "address" .:  string' >>>    -- a keyword :address and a string value, and
      Kw "age"     .:? int))          -- an optional keyword :age with int value.
```

So now we can use `personGrammar` to parse S-expressions to records of type
`Person` and pretty-print records of type `Person` back to S-expressions:

```haskell
ghci> import Language.SexpGrammar
ghci> import qualified Data.ByteString.Lazy.Char8 as B8
ghci> person <- either error id . decodeWith personGrammar . B8.pack <$> getLine
(person "John Doe" :address "42 Whatever str." :age 25)
ghci> person
Person {pName = "John Doe", pAddress = "42 Whatever str.", pAge = Just 25}
ghci> either print B8.putStrLn . encodeWith personGrammar $ person
(person "John Doe" :address "42 Whatever str." :age 25)
```

See more [examples](https://github.com/esmolanka/sexp-grammar/tree/master/examples) in the repository.

How it works
------------

The grammars are described in terms of isomorphisms and stack manipulation
operations. Primitive grammars provided by the core library match Sexp literals,
lists, and vectors to Haskell values and put them onto stack. Then isomorphisms
between values on the stack and more complex Haskell ADTs (like `Person` record
in the example above) take place. Such isomorphisms can be generated by
`TemplateHaskell` or GHC Generics.

The simplest primitive grammars are atom grammars, which match `Sexp` atoms with
Haskell counterparts:

```haskell
                             --               grammar type   | consumes     | produces
                             --    --------------------------+--------------+-----------------
bool    :: SexpG Bool        -- or :: Grammar SexpGrammar     (Sexp :- t)    (Bool       :- t)
integer :: SexpG Integer     -- or :: Grammar SexpGrammar     (Sexp :- t)    (Integer    :- t)
int     :: SexpG Int         -- or :: Grammar SexpGrammar     (Sexp :- t)    (Int        :- t)
real    :: SexpG Scientific  -- or :: Grammar SexpGrammar     (Sexp :- t)    (Scientific :- t)
double  :: SexpG Double      -- or :: Grammar SexpGrammar     (Sexp :- t)    (Double     :- t)
string  :: SexpG Text        -- or :: Grammar SexpGrammar     (Sexp :- t)    (Text       :- t)
string' :: SexpG String      -- or :: Grammar SexpGrammar     (Sexp :- t)    (String     :- t)
symbol  :: SexpG Text        -- or :: Grammar SexpGrammar     (Sexp :- t)    (Text       :- t)
symbol' :: SexpG String      -- or :: Grammar SexpGrammar     (Sexp :- t)    (String     :- t)
keyword :: SexpG Kw          -- or :: Grammar SexpGrammar     (Sexp :- t)    (Kw         :- t)
sym     :: Text -> SexpG_    -- or :: Grammar SexpGrammar     (Sexp :- t)    t
kw      :: Kw   -> SexpG_    -- or :: Grammar SexpGrammar     (Sexp :- t)    t
```

Grammars matching lists and vectors can be defined using an auxiliary grammar
type `SeqGrammar`. The following primitives embed `SeqGrammar`s into main
`SexpGrammar` context:

```haskell
list  :: Grammar SeqGrammar t t' -> Grammar SexpGrammar (Sexp :- t) t'
vect  :: Grammar SeqGrammar t t' -> Grammar SexpGrammar (Sexp :- t) t'
```

Grammar type `SeqGrammar` basically describes the sequence of elements in a
`Sexp` list (or vector). Single element grammar is defined with `el`, "match
rest of the sequence as list" grammar could be defined with `rest` combinator.
If the rest of the sequence is a property list, `props` combinator should be
used.

```haskell
el    :: Grammar SexpGrammar (Sexp :- a)  b       -> Grammar SeqGrammar a b
rest  :: Grammar SexpGrammar (Sexp :- a) (b :- a) -> Grammar SeqGrammar a ([b] :- a)
props :: Grammar PropGrammar a b                  -> Grammar SeqGrammar a b
```

`props` combinator embeds properties grammar `PropGrammar` into a `SeqGrammar`
context. `PropGrammar` describes what keys and values to match.

```haskell
(.:)  :: Kw
      -> Grammar SexpGrammar (Sexp :- t) (a :- t)
      -> Grammar PropGrammar t (a :- t)

(.:?) :: Kw
      -> Grammar SexpGrammar (Sexp :- t) (a :- t)
      -> Grammar PropGrammar t (Maybe a :- t)
```

Please refer to Haddock on [Hackage](http://hackage.haskell.org/package/sexp-grammar)
for API documentation.

Diagram of grammar contexts:

```

     --------------------------------------
     |              AtomGrammar           |
     --------------------------------------
         ^
         |  atomic grammar combinators
         v
 ------------------------------------------------------
 |                      SexpGrammar                   |
 ------------------------------------------------------
         | list, vect     ^              ^
         v                | el, rest     |
     ----------------------------------  |
     |           SeqGrammar           |  |
     ----------------------------------  | (.:)
              | props                    | (.:?)
              v                          |
          -------------------------------------
          |             PropGrammar           |
          -------------------------------------

```
