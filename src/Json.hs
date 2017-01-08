{-# LANGUAGE FlexibleInstances #-}

module Json where

import Text.JSON (decode, Result(Error,Ok), JSValue(JSNull, JSBool, JSRational, JSString, JSArray, JSObject), fromJSString, fromJSObject)
import qualified Data.Tree as DataTree

import Parsers

instance Tree JsonTree where
	getLabel (DataTree.Node l _) = l
	getChildren (DataTree.Node _ cs) = cs

type JsonTree = DataTree.Tree Label

decodeJSON :: String -> [JsonTree]
decodeJSON s = unmarshal $ decode s

unmarshal :: Result JSValue -> [JsonTree]
unmarshal (Error s) = error s
unmarshal (Ok v) = uValue v

uValue :: JSValue -> [JsonTree]
uValue JSNull = []
uValue (JSBool b) = [DataTree.Node (Bool b) []]
uValue (JSRational _ r) = [DataTree.Node (Number r) []]
uValue (JSString s) = [DataTree.Node (String (fromJSString s)) []]
uValue (JSArray vs) = uArray 0 vs
uValue (JSObject o) = uObject $ fromJSObject o

uArray :: Int -> [JSValue] -> [JsonTree]
uArray index [] = []
uArray index (v:vs) = (DataTree.Node (Number (toRational index)) (uValue v)):(uArray (index+1) vs)

uObject :: [(String, JSValue)] -> [JsonTree]
uObject keyValues = map uKeyValue keyValues

uKeyValue :: (String, JSValue) -> JsonTree
uKeyValue (name, value) = DataTree.Node (String name) (uValue value)




