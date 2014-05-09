{-# LANGUAGE GADTs, DataKinds, KindSignatures, TypeOperators, TypeFamilies, 
             MultiParamTypeClasses, FlexibleInstances, UndecidableInstances, 
             ScopedTypeVariables, PolyKinds, FlexibleContexts, InstanceSigs #-}

module Control.IxMonad.Writer(Writer(..), Symbol, put, (:->), Set(..), union, Var(..), 
                              Union, Unionable) where

import Control.IxMonad 
import Control.IxMonad.Helpers.Mapping
import Control.IxMonad.Helpers.Set
import Data.Monoid
import Data.Proxy
import GHC.TypeLits
import Prelude hiding (Monad(..))

data Writer w a = Writer { runWriter :: (a, Set w) } 

{-- Writer effect-parameterised monad -}

instance IxMonad Writer where
    type Inv Writer s t = Unionable s t

    type Unit Writer = '[]
    type Plus Writer s t = Union s t

    return x = Writer (x, Empty)
    (Writer (a, w)) >>= k = let Writer (b, w') = k a
                            in  Writer (b, w `union` w')

put :: Var k -> v -> Writer '[k :-> v] ()
put k v = Writer ((), Ext (k :-> v) Empty)


{-- Define the operation for removing duplicates using mappend --}

instance (Monoid u, RemDuper ((k :-> u) ': s) s') => RemDuper ((k :-> u) ': (k :-> u) ': s) s' where
    remDup (Ext (_ :-> u) (Ext (k :-> v) s)) = remDup (Ext (k :-> (u `mappend` v)) s)

{-- Extend the bubble sort for the Set -}

type instance Min (j :-> u) (k :-> v) = (Select j k j k) :-> (Select j k u v)
type instance Max (j :-> u) (k :-> v) = (Select j k k j) :-> (Select j k v u)

type Select a b p q = Choose (CmpSymbol a b) p q

class Chooser (o :: Ordering) where
    type Choose (o :: Ordering) (p :: k) (q :: k) :: k
    choose :: (Proxy o) -> p -> q -> (Choose o p q)

instance Chooser LT where
    type Choose LT p q = p
    choose _ p q = p

instance Chooser EQ where
    type Choose EQ p q = p
    choose _ p q = p

instance Chooser GT where
    type Choose GT p q = q
    choose _ p q = q

instance (Chooser (CmpSymbol j k)) => OrdH (j :-> u) (k :-> v) where
    minH (j :-> u) (k :-> v) = Var :-> (select j k u v)
    maxH (j :-> u) (k :-> v) = Var :-> (select j k v u)

select :: forall j k a b . (Chooser (CmpSymbol j k)) => 
          Var j -> Var k -> a -> b -> Select j k a b
select _ _ x y = choose (Proxy::(Proxy (CmpSymbol j k))) x y 
