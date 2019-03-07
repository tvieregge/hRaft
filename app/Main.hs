module Main where

import Lib
import System.Environment

-- TODO: properly parse
main :: IO ()
main = getArgs >>= (\args -> someFunc $ head args)
