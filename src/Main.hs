module Main (main) where

import           Prelude
import           System.Environment (getArgs)
import           TSHM.Parser        (ParseOutput, parseSignature)
import           TSHM.Printer       (fSignature)

main :: IO ()
main = render . parseSignature =<< argGuard =<< getArgs
  where argGuard :: [String] -> IO String
        argGuard []  = putStrLn "No input provided." *> exitFailure
        argGuard [x] = pure x
        argGuard _   = putStrLn "Too many inputs provided." *> exitFailure

        render :: ParseOutput -> IO ()
        render (Left e)  = print e *> exitFailure
        render (Right x) = putStrLn . fSignature $ x

