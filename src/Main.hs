module Main (main) where

import           CLI          (Input (..), Opts (..), parse)
import           Prelude
import           TSHM.Parser  (parseDeclaration)
import           TSHM.Printer (PrintConfig (PrintConfig), printDeclaration)

main :: IO ()
main = do
  opts <- parse
  code <- case input opts of
    Eval x     -> pure x
    FilePath x -> readFile x
  case parseDeclaration code of
    Left e  -> print e *> exitFailure
    Right x -> putStrLn . printDeclaration $ PrintConfig x (forall opts) (readonly opts)

