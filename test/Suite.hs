-- |
-- Suite parses the testsuite folder and creates test cases
module Suite
  ( readTestCases
  , tests
  )
where

import qualified Test.Tasty                    as T
import qualified Test.Tasty.HUnit              as HUnit

import           System.Directory               ( getCurrentDirectory
                                                , listDirectory
                                                , doesDirectoryExist
                                                )
import           System.FilePath                ( FilePath
                                                , (</>)
                                                , takeExtension
                                                , takeBaseName
                                                , takeDirectory
                                                )
import           Text.XML.HXT.DOM.TypeDefs      ( XmlTree )

import           Data.Katydid.Parser.Parser     ( Tree )
import           Data.Katydid.Parser.Json       ( JsonTree
                                                , decodeJSON
                                                )
import           Data.Katydid.Parser.Xml        ( decodeXML )

import           Data.Katydid.Relapse.Smart     ( Grammar
                                                , Pattern
                                                , nullable
                                                , compile
                                                )
import qualified Data.Katydid.Relapse.Ast      as Ast
import           Data.Katydid.Relapse.Parser    ( parseGrammar )
import qualified Data.Katydid.Relapse.Derive   as Derive
import qualified Data.Katydid.Relapse.MemDerive
                                               as MemDerive
import qualified Data.Katydid.Relapse.VpaDerive
                                               as VpaDerive

tests :: [TestSuiteCase] -> T.TestTree
tests testSuiteCases
  = let
      nonRecursiveTestCases = filter
        (\(TestSuiteCase _ g _ _) -> not (either error id $ Ast.hasRecursion g))
        testSuiteCases
      derivTests = T.testGroup "derive"
        $ map (newTestCase AlgoDeriv) nonRecursiveTestCases
      zipTests =
        T.testGroup "zip" $ map (newTestCase AlgoZip) nonRecursiveTestCases
      mapTests =
        T.testGroup "map" $ map (newTestCase AlgoMap) nonRecursiveTestCases
      vpaTests =
        T.testGroup "vpa" $ map (newTestCase AlgoVpa) nonRecursiveTestCases
    in
      T.testGroup "Suite" [derivTests, zipTests, mapTests, vpaTests]

readTestCases :: IO [TestSuiteCase]
readTestCases = do
  path   <- testPath
  exists <- doesDirectoryExist path
  if exists
    then do
      jsondirs      <- ls $ path </> "json"
      xmldirs       <- ls $ path </> "xml"
      xmlTestCases  <- mapM readXMLTest xmldirs
      jsonTestCases <- mapM readJsonTest jsondirs
      return $ jsonTestCases ++ xmlTestCases
    else return []

data TestSuiteCase = TestSuiteCase {
    name        :: String
    , grammar   :: Ast.Grammar
    , input     :: EncodedData
    , valid     :: Bool
} deriving Show

data EncodedData
    = XMLData [XmlTree]
    | JsonData [JsonTree]
    deriving Show

data Algo = AlgoDeriv
    | AlgoZip
    | AlgoMap
    | AlgoVpa
    deriving Show

newTestCase :: Algo -> TestSuiteCase -> T.TestTree
newTestCase algo c@(TestSuiteCase name g (XMLData t) want) =
  HUnit.testCase (testName algo c) $ testDeriv algo name g t want
newTestCase algo c@(TestSuiteCase name g (JsonData t) want) =
  HUnit.testCase (testName algo c) $ testDeriv algo name g t want

testName :: Algo -> TestSuiteCase -> String
testName algo (TestSuiteCase name g t want) = name ++ "_" ++ show algo

testDeriv :: Tree t => Algo -> String -> Ast.Grammar -> [t] -> Bool -> IO ()
testDeriv AlgoDeriv name g ts want =
  let p = either
        error
        id
        (do
          compiled <- compile g
          Derive.derive compiled ts
        )
      got = nullable p
  in  HUnit.assertEqual
        (  "want "
        ++ show want
        ++ " got "
        ++ show got
        ++ "\nstarting grammar = "
        ++ show g
        ++ "\nresulting derivative = "
        ++ show p
        )
        want
        got
testDeriv AlgoZip name g ts want =
  let p = either
        error
        id
        (do
          compiled <- compile g
          Derive.zipderive compiled ts
        )
      got = nullable p
  in  HUnit.assertEqual
        (  "want "
        ++ show want
        ++ " got "
        ++ show got
        ++ "\nstarting grammar = "
        ++ show g
        ++ "\nresulting derivative = "
        ++ show p
        )
        want
        got
testDeriv AlgoMap name g ts want =
  let p = either
        error
        id
        (do
          compiled <- compile g
          MemDerive.derive compiled ts
        )
      got = nullable p
  in  HUnit.assertEqual
        (  "want "
        ++ show want
        ++ " got "
        ++ show got
        ++ "\nstarting grammar = "
        ++ show g
        ++ "\nresulting derivative = "
        ++ show p
        )
        want
        got
testDeriv AlgoVpa name g ts want =
  let p = either
        error
        id
        (do
          compiled <- compile g
          VpaDerive.derive compiled ts
        )
      got = nullable p
  in  HUnit.assertEqual
        (  "want "
        ++ show want
        ++ " got "
        ++ show got
        ++ "\nstarting grammar = "
        ++ show g
        ++ "\nresulting derivative = "
        ++ show p
        )
        want
        got

getRelapseJson :: [FilePath] -> FilePath
getRelapseJson paths = head $ filter
  (\fname -> takeExtension fname == ".json" && takeBaseName fname == "relapse")
  paths

getRelapse :: [FilePath] -> FilePath
getRelapse paths = head $ filter
  (\fname -> takeExtension fname == ".txt" && takeBaseName fname == "relapse")
  paths

isValidCase :: [FilePath] -> Bool
isValidCase paths =
  length (filter (\fname -> takeBaseName fname == "valid") paths) == 1

filepathWithExt :: [FilePath] -> String -> FilePath
filepathWithExt paths ext = head $ filter
  (\fname -> takeExtension fname == ext && takeBaseName fname /= "relapse")
  paths

fromGrammar :: String -> Ast.Grammar
fromGrammar s = case parseGrammar s of
  (Left err) ->
    error $ "given input: <" ++ s ++ "> got parse error: " ++ show err
  (Right g) -> g

readJsonTest :: FilePath -> IO TestSuiteCase
readJsonTest path = do
  files       <- ls path
  grammarData <- readFile $ getRelapse files
  jsonData    <- readFile $ filepathWithExt files ".json"
  let jValue = case decodeJSON jsonData of
        (Left  e) -> error e
        (Right r) -> r
  return $ TestSuiteCase (takeBaseName path)
                         (fromGrammar grammarData)
                         (JsonData jValue)
                         (isValidCase files)

readXMLTest :: FilePath -> IO TestSuiteCase
readXMLTest path = do
  files       <- ls path
  grammarData <- readFile $ getRelapse files
  xmlData     <- readFile $ filepathWithExt files ".xml"
  return $ TestSuiteCase (takeBaseName path)
                         (fromGrammar grammarData)
                         (XMLData $ decodeXML xmlData)
                         (isValidCase files)

ls :: FilePath -> IO [FilePath]
ls path = do
  dirs <- listDirectory path
  return $ map (path </>) dirs

testPath :: IO FilePath
testPath = do
  path <- getCurrentDirectory
  return $ takeDirectory path </> "testsuite" </> "relapse" </> "tests"
