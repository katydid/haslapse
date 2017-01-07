module Values where

import Parsers

data BoolExpr
	= BoolConst Bool
	| BoolVariable

	| BoolEqualFunc BoolExpr BoolExpr
	| DoubleEqualFunc DoubleExpr DoubleExpr
	| IntEqualFunc IntExpr IntExpr
	| UintEqualFunc UintExpr UintExpr
	| StringEqualFunc StringExpr StringExpr
	| BytesEqualFunc BytesExpr BytesExpr

	| OrFunc BoolExpr BoolExpr
	| AndFunc BoolExpr BoolExpr
	| NotFunc BoolExpr

	| IntListContainsFunc IntExpr [IntExpr]
	| StringListContainsFunc StringExpr [StringExpr]
	| UintListContainsFunc UintExpr [UintExpr]
	| StringContainsFunc StringExpr StringExpr

	| BoolListElemFunc [BoolExpr] IntExpr

	| BytesGreaterOrEqualFunc BytesExpr BytesExpr
	| DoubleGreaterOrEqualFunc DoubleExpr DoubleExpr
	| IntGreaterOrEqualFunc IntExpr IntExpr
	| UintGreaterOrEqualFunc UintExpr UintExpr

	| BytesGreaterThanFunc BytesExpr BytesExpr
	| DoubleGreaterThanFunc DoubleExpr DoubleExpr
	| IntGreaterThanFunc IntExpr IntExpr
	| UintGreaterThanFunc UintExpr UintExpr

	| StringHasPrefixFunc StringExpr StringExpr
	| StringHasSuffixFunc StringExpr StringExpr

	| BytesLessOrEqualFunc BytesExpr BytesExpr
	| DoubleLessOrEqualFunc DoubleExpr DoubleExpr
	| IntLessOrEqualFunc IntExpr IntExpr
	| UintLessOrEqualFunc UintExpr UintExpr

	| BytesLessThanFunc BytesExpr BytesExpr
	| DoubleLessThanFunc DoubleExpr DoubleExpr
	| IntLessThanFunc IntExpr IntExpr
	| UintLessThanFunc UintExpr UintExpr

	| BytesNotEqualFunc BytesExpr BytesExpr
	| BoolNotEqualFunc BoolExpr BoolExpr
	| DoubleNotEqualFunc DoubleExpr DoubleExpr
	| IntNotEqualFunc IntExpr IntExpr
	| StringNotEqualFunc StringExpr StringExpr
	| UintNotEqualFunc UintExpr UintExpr

	| BytesTypeFunc BytesExpr
	| BoolTypeFunc BoolExpr
	| DoubleTypeFunc DoubleExpr
	| IntTypeFunc  IntExpr
	| UintTypeFunc UintExpr
	| StringTypeFunc StringExpr
	deriving (Eq, Ord, Show)

data DoubleExpr
	= DoubleConst Rational
	| DoubleVariable
	| DoubleListElemFunc [DoubleExpr] IntExpr
	deriving (Eq, Ord, Show)

data IntExpr
	= IntConst Int
	| IntVariable
	| IntListElemFunc [IntExpr] IntExpr

	| BytesListLengthFunc [BytesExpr]
	| BoolListLengthFunc [BoolExpr]
	| BytesLengthFunc BytesExpr
	| DoubleListLengthFunc [DoubleExpr]
	| IntListLengthFunc [IntExpr]
	| StringListLengthFunc [StringExpr]
	| UintListLengthFunc [UintExpr]
	| StringLengthFunc StringExpr
	deriving (Eq, Ord, Show)

data UintExpr
 	= UintConst Int
 	| UintVariable
 	| UintListElemFunc [UintExpr] IntExpr
 	deriving (Eq, Ord, Show)

data StringExpr
	= StringConst String
	| StringVariable
	| StringListElemFunc [StringExpr] IntExpr

	| StringToLowerFunc StringExpr
	| StringToUpperFunc StringExpr
	deriving (Eq, Ord, Show)

data BytesExpr
	= BytesConst String
	| BytesVariable
	| BytesListElemFunc [BytesExpr] IntExpr
	deriving (Eq, Ord, Show)

data Value a = Err String
	| Value a

-- instance Functor Value where
--   fmap = liftM
instance Functor Value where
	fmap f (Value v) = Value (f v)
	fmap f (Err s) = Err s

-- instance Applicative Value where
--   pure  = return
--   (<*>) = ap
instance Applicative Value where
	pure = Value
	(Value f) <*> (Value v) = Value $ f v
	(Value _) <*> (Err s) = (Err s)
	(Err s) <*> (Value _) = (Err s)
	(Err s1) <*> (Err s2) = (Err $ s1 ++ s2)

instance Monad Value where
    (Value v) >>= f = f v
    (Err s) >>= _ = Err s
    fail e = Err e
    return v = Value v

eval :: BoolExpr -> Label -> Bool
eval e l = case evalBool e l of
	(Value v) -> v
	(Err errStr) -> error errStr

evalBool :: BoolExpr -> Label -> Value Bool
evalBool (BoolConst b) _ = Value b
evalBool BoolVariable (Bool b) = Value b
evalBool BoolVariable _ = Err "not a bool"
evalBool (BoolEqualFunc e1 e2) v = do {
	b1 <- evalBool e1 v;
	b2 <- evalBool e2 v;
	return $ b1 == b2
}
evalBool (OrFunc e1 e2) v = do {
	b1 <- evalBool e1 v;
	b2 <- evalBool e2 v;
	return $ b1 || b2
}
evalBool (AndFunc e1 e2) v = do {
	b1 <- evalBool e1 v;
	b2 <- evalBool e2 v;
	return $ b1 && b2
}
evalBool (NotFunc e) v = do {
	b <- evalBool e v;
	return $ not b
}

simplifyBoolExpr :: BoolExpr -> BoolExpr
simplifyBoolExpr e@(BoolEqualFunc (BoolConst b1) (BoolConst b2)) = BoolConst $ b1 == b2
simplifyBoolExpr (OrFunc v1 v2) = simplifyOrFunc (simplifyBoolExpr v1) (simplifyBoolExpr v2)
simplifyBoolExpr (AndFunc v1 v2) = simplifyAndFunc (simplifyBoolExpr v1) (simplifyBoolExpr v2)
simplifyBoolExpr (NotFunc v) = simplifyNotFunc (simplifyBoolExpr v)
simplifyBoolExpr v@(BoolConst _) = v

simplifyOrFunc :: BoolExpr -> BoolExpr -> BoolExpr
simplifyOrFunc true@(BoolConst True) _ = true
simplifyOrFunc _ true@(BoolConst True) = true
simplifyOrFunc (BoolConst False) v = v
simplifyOrFunc v (BoolConst False) = v
simplifyOrFunc v1 v2
	| v1 == v2  = v1
	| otherwise = OrFunc v1 v2

simplifyAndFunc :: BoolExpr -> BoolExpr -> BoolExpr
simplifyAndFunc (BoolConst True) v = v
simplifyAndFunc v (BoolConst True) = v
simplifyAndFunc false@(BoolConst False) _ = false
simplifyAndFunc _ false@(BoolConst False) = false
simplifyAndFunc v1 v2
	| v1 == v2  = v1
	| otherwise = AndFunc v1 v2

simplifyNotFunc :: BoolExpr -> BoolExpr
simplifyNotFunc (NotFunc v) = v
simplifyNotFunc (BoolConst True) = (BoolConst False)
simplifyNotFunc (BoolConst False) = (BoolConst True)
simplifyNotFunc v = NotFunc v