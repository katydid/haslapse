-- |
-- This is an internal relapse module.
--
-- It contains multiple implementations of if expressions.

module IfExprs (
    IfExprs, IfExpr, newIfExpr,
    evalIfExprs, compileIfExprs,
    ZippedIfExprs, zipIfExprs, evalZippedIfExprs
) where

import Control.Monad.Except (Except)

import Patterns
import Expr
import Simplify
import Zip
import Parsers

newtype IfExpr = IfExpr (Expr Bool, Pattern, Pattern)

newIfExpr :: Expr Bool -> Pattern -> Pattern -> IfExpr
newIfExpr c t e = IfExpr (c, t, e)

data IfExprs
    = Cond {
        cond :: Expr Bool
        , thn :: IfExprs
        , els :: IfExprs
    }
    | Ret [Pattern]

compileIfExprs :: Refs -> [IfExpr] -> IfExprs
compileIfExprs _ [] = Ret []
compileIfExprs refs (e:es) = let (IfExpr ifExpr) = simplifyIf refs e
    in addIfExpr ifExpr (compileIfExprs refs es)

evalIfExprs :: IfExprs -> Label -> Except ValueErr [Pattern]
evalIfExprs (Ret ps) _ = return ps
evalIfExprs (Cond c t e) l = do {
    b <- eval c l;
    if b then evalIfExprs t l else evalIfExprs e l
}

simplifyIf :: Refs -> IfExpr -> IfExpr
simplifyIf refs (IfExpr (c, t, e)) =
    let scond = simplifyBoolExpr c
        sthn  = simplify refs t
        sels  = simplify refs e
    in if sthn == sels then IfExpr (BoolConst True, sthn, sels) else IfExpr (scond, sthn, sels)

addIfExpr :: (Expr Bool, Pattern, Pattern) -> IfExprs -> IfExprs
addIfExpr (c, t, e) (Ret ps) =
    Cond c (Ret (t:ps)) (Ret (e:ps))
addIfExpr (c, t, e) (Cond cs ts es)
    | c == cs = Cond cs (addRet t ts) (addRet e es)
    | BoolConst False == simplifyBoolExpr (AndFunc c cs) = Cond cs (addRet e ts) (addIfExpr (c, t, e) es)
    | BoolConst False == simplifyBoolExpr (AndFunc (NotFunc c) cs) = Cond cs (addIfExpr (c, t, e) ts) (addRet t es)
    | otherwise = Cond cs (addIfExpr (c, t, e) ts) (addIfExpr (c, t, e) es)

addRet :: Pattern -> IfExprs -> IfExprs
addRet p (Ret ps) = Ret (p:ps)
addRet p (Cond c t e) = Cond c (addRet p t) (addRet p e)

data ZippedIfExprs
    = ZippedCond {
        zcond :: Expr Bool
        , zthn :: ZippedIfExprs
        , zels :: ZippedIfExprs
    }
    | ZippedRet [Pattern] Zipper

zipIfExprs :: IfExprs -> ZippedIfExprs
zipIfExprs (Cond c t e) = ZippedCond c (zipIfExprs t) (zipIfExprs e)
zipIfExprs (Ret ps) = let (zps, zs) = zippy ps in ZippedRet zps zs

evalZippedIfExprs :: ZippedIfExprs -> Label -> Except ValueErr ([Pattern], Zipper)
evalZippedIfExprs (ZippedRet ps zs) _ = return (ps, zs)
evalZippedIfExprs (ZippedCond c t e) v = do {
    b <- eval c v;
    if b then evalZippedIfExprs t v else evalZippedIfExprs e v
}

