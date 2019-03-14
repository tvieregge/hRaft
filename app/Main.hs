module Main where

import Lib
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import Control.Distributed.Process.Node (initRemoteTable, runProcess, newLocalNode)

main = do
    Right transport <- createTransport "localhost" "0" (\p -> ("","")) defaultTCPParameters
    backendNode <- newLocalNode transport initRemoteTable
    runProcess backendNode (spawnServers 3)
    putStrLn "newline to exit"
    getLine
