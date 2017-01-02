module Zip where

import qualified Data.Set as Set
import Data.List
import Patterns

type Zipper = [Int]

zippy :: [Pattern] -> ([Pattern], Zipper)
zippy ps = 
	let	s = Set.fromList ps
		s' = Set.delete ZAny s
		s'' = Set.delete (Not ZAny) s
		l = Set.toAscList s''
	in (l, map (indexOf l) ps)

indexOf :: [Pattern] -> Pattern -> Int
indexOf _ ZAny = -1
indexOf _ (Not ZAny) = -2
indexOf ps p = case elemIndex p ps of
	(Just i) -> i
	Nothing -> error $ "element <" ++ (show p) ++ "> not in list <" ++ (show ps) ++ ">"

unzippy :: Zipper -> [Pattern] -> [Pattern]
unzippy z ps = map (ofIndex ps) z

ofIndex :: [Pattern] -> Int -> Pattern
ofIndex _ (-1) = ZAny
ofIndex _ (-2) = (Not ZAny)
ofIndex ps i = ps !! i

unzipby :: Zipper -> [Bool] -> [Bool]
unzipby z bs = map (ofIndexb bs) z

ofIndexb :: [Bool] -> Int -> Bool
ofIndexb _ (-1) = True
ofIndexb _ (-2) = False
ofIndexb bs i = bs !! i