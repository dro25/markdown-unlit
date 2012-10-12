{-# LANGUAGE CPP #-}
module Text.Markdown.Unlit (
  run
, unlit
, Selector (..)
, parseSelector
, CodeBlock (..)
, parse
#ifdef TEST
, parseClasses
#endif
) where

import           Control.Applicative
import           Data.List
import           Data.Char
import           Data.String
import           System.IO
import           System.Exit
import           System.Environment

-- | Program entry point.
run :: [String] -> IO ()
run args = case args of
  -- GHC calls unlit like so:
  --
  -- > unlit -h label Foo.lhs /tmp/somefile
  --
  -- The label is meant to be used in line pragmas, like so:
  --
  -- #line 1 "label"
  --
  ["-h", _, infile, outfile] ->
    fmap (unlit $ Class "haskell" :&: Class "literate") (readFile infile) >>= writeFile outfile
  _ -> do
    name <- getProgName
    hPutStrLn stderr ("usage: " ++ name ++ " -h label infile outfile")
    exitFailure

unlit :: Selector -> String -> String
unlit selector = unlines . concatMap codeBlockContent . filter (toP selector . codeBlockClasses) . parse
  where
    toP :: Selector -> [String] -> Bool
    toP = go
      where
        go s = case s of
          Class c -> elem c
          a :&: b -> (&&) <$> go a <*> go b
          a :|: b -> (||) <$> go a <*> go b

infixr 3 :&:
infixr 2 :|:

data Selector
  = Class String
  | Selector :&: Selector
  | Selector :|: Selector
  deriving (Eq, Show)

parseSelector :: String -> Maybe Selector
parseSelector input = case words input of
  [] -> Nothing
  xs -> (Just . foldr1 (:|:) . map parseAnds) xs
  where
    parseAnds = foldr1 (:&:) . map Class . split (== '+')

    -- a copy from https://github.com/sol/string
    split :: (Char -> Bool) -> String -> [String]
    split p = go
      where
        go xs = case break p xs of
          (ys, [])   -> [ys]
          (ys, _:zs) -> ys : go zs

instance IsString Selector where
  fromString = Class

data CodeBlock = CodeBlock {
  codeBlockClasses :: [String]
, codeBlockContent :: [String]
} deriving (Eq, Show)

parse :: String -> [CodeBlock]
parse = go . lines
  where
    go :: [String] -> [CodeBlock]
    go xs = case break isFence xs of
      (_, [])   -> []
      (_, y:ys) -> case takeCB y ys of
        (cb, rest) -> cb : go rest

    takeCB :: String -> [String] -> (CodeBlock, [String])
    takeCB fence xs = case break isFence xs of
      (cb, rest) -> (CodeBlock (parseClasses fence) cb, drop 1 rest)

parseClasses :: String -> [String]
parseClasses xs = case dropWhile isSpace . dropWhile (== '~') $ xs of
  '{':ys -> words . replace '.' ' ' . takeWhile (/= '}') $ ys
  _      -> []

isFence :: String -> Bool
isFence = isPrefixOf "~~~"

replace :: Char -> Char -> String -> String
replace x sub = map f
  where
    f y | x == y    = sub
        | otherwise = y
