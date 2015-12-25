{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE KindSignatures        #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}

module Data.InvertibleGrammar
  ( Grammar (..)
  , InvertibleGrammar(..)
  , fromStackPrism
  , fromRevStackPrism
  ) where

import Prelude hiding ((.), id)
import Control.Category
import Control.Monad
import Control.Monad.Except
import Data.Semigroup

import Data.StackPrism

data Grammar g t t' where
  LiftPrism    :: StackPrism a b -> Grammar g a b
  -- | Prism parses from right to left (b to a, a is smaller than b), while
  -- grammar must always parse from left to right.
  LiftRevPrism :: StackPrism b a -> Grammar g a b
  Id     :: Grammar g t t
  (:.:)  :: Grammar g t' t'' -> Grammar g t t' -> Grammar g t t''
  -- Empty  :: Grammar g t t'
  (:<>:) :: Grammar g t t' -> Grammar g t t' -> Grammar g t t'
  -- Many   :: Gramar g (a :- t) (b :- t) -> Grammar g ([a] :- t) ([b] :- t)
  Many   :: Grammar g t t -> Grammar g t t
  Gram   :: g a b -> Grammar g a b

instance Category (Grammar c) where
  id = Id
  (.) Id y  = y
  (.) x  Id = x
  (.) x  y  = x :.: y

instance Semigroup (Grammar c t1 t2) where
  (<>) = (:<>:)

class InvertibleGrammar m g where
  parseWithGrammar :: g a b -> a -> m b

instance
  ( Monad m
  , MonadPlus m
  , MonadError String m
  , InvertibleGrammar m g
  ) => InvertibleGrammar m (Grammar g) where
  parseWithGrammar (LiftPrism prism)    = return . forward prism
  parseWithGrammar (LiftRevPrism prism) = maybe err return . backward prism
    where
      err = throwError "revesre prism failed"
  parseWithGrammar Id           = return
  parseWithGrammar (g :.: f)    = parseWithGrammar g <=< parseWithGrammar f
  parseWithGrammar (f :<>: g)   = \x -> parseWithGrammar f x `mplus` parseWithGrammar g x
  parseWithGrammar (Many g)     = go
    where
      go x = (parseWithGrammar g x >>= go) `mplus` return x
  parseWithGrammar (Gram g)     = parseWithGrammar g

fromStackPrism :: StackPrism a b -> Grammar g a b
fromStackPrism = LiftPrism

fromRevStackPrism :: StackPrism b a -> Grammar g a b
fromRevStackPrism = LiftRevPrism
